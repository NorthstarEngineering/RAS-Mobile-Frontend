from typing import Any, Dict, Optional
from fastapi import APIRouter, HTTPException, Request, status
from ..database.connection import get_db
from ..schemas.overtime_schemas import (
    ApiResponse,
    OvertimeRecordCreate,
    OvertimeRecordReview,
    OvertimeRecordApprove,
    OvertimeRecordResponse,
)
from ..services.overtime_service import OvertimeService

router = APIRouter(prefix="/overtime", tags=["Overtime"])

CORPORATE_ROLES = {"ceo", "admin", "system_admin", "general_manager"}


def _require_authenticated_user(request: Request) -> Dict[str, Any]:
    """Extract and strictly validate Bearer token or x-auth-token using server-side AuthService."""
    token = None
    auth_header = request.headers.get("authorization")
    if auth_header and auth_header.lower().startswith("bearer "):
        token = auth_header[7:].strip()
    elif "x-auth-token" in request.headers:
        token = request.headers.get("x-auth-token", "").strip()

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="رمز المصادقة مطلوب (Bearer token required)",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        from ..services.auth_service import AuthService
        return AuthService.get_current_user_from_token(token)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"رمز المصادقة غير صالح: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


@router.get("", response_model=ApiResponse)
def get_overtime_records(
    status_filter: Optional[str] = None,
    employee_id: Optional[str] = None,
    branch_id: Optional[str] = None,
):
    """قائمة طلبات وسجلات الساعات الإضافية مع دعم الفلترة."""
    records = OvertimeService.get_overtime_list(
        status=status_filter,
        employee_id=employee_id,
        branch_id=branch_id,
    )
    return ApiResponse(
        success=True,
        data=[r.model_dump() for r in records],
        message=f"تم جلب {len(records)} سجل ساعات إضافية بنجاح",
        meta={"total_records": len(records)},
    )


@router.get("/{record_id}", response_model=ApiResponse)
def get_overtime_by_id(record_id: str):
    """تفاصيل سجل ساعات إضافية محدد عبر المعرف."""
    record = OvertimeService.get_overtime_by_id(record_id)
    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"سجل الساعات الإضافية '{record_id}' غير موجود",
        )
    return ApiResponse(
        success=True,
        data=record.model_dump(),
        message="تم جلب تفاصيل الساعات الإضافية بنجاح",
    )


@router.post("", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
def create_overtime_record(payload: OvertimeRecordCreate, request: Request):
    """تسجيل طلب ساعات إضافية جديدة وحفظه في SQLite وسجل التدقيق."""
    user = _require_authenticated_user(request)
    if user.get("role") not in ("ceo", "branch_manager", "supervisor", "admin", "system_admin", "general_manager"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: تسجيل طلبات الساعات الإضافية مقتصر على الإدارة والمشرفين",
        )
    user_branch = user.get("branch_id")
    # Derive employee actual branch from SQL database, not payload branch
    with get_db() as conn:
        emp_cur = conn.execute(
            "SELECT id, branch_id FROM employees WHERE id = ? OR national_id = ?",
            (payload.employee_id, payload.employee_id),
        )
        emp_row = emp_cur.fetchone()
        if not emp_row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Employee with ID '{payload.employee_id}' not found",
            )
        emp_actual_branch = (emp_row["branch_id"] if hasattr(emp_row, "keys") else emp_row[1])

    if user.get("role") not in CORPORATE_ROLES and user_branch:
        if emp_actual_branch and emp_actual_branch != user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكن تسجيل ساعات إضافية لموظف في فرع آخر خارج نطاق صلاحياتك",
            )
        if payload.branch_id and payload.branch_id != user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكن تسجيل ساعات إضافية لفرع آخر خارج نطاق صلاحياتك",
            )
    if emp_actual_branch:
        payload.branch_id = emp_actual_branch

    current_user_id = user.get("id")

    try:
        record = OvertimeService.create_overtime_record(payload, current_user_id=current_user_id)
        return ApiResponse(
            success=True,
            data=record.model_dump(),
            message="تم تسجيل طلب الساعات الإضافية بنجاح",
        )
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"فشل تسجيل طلب الساعات الإضافية: {str(e)}",
        )


@router.patch("/{record_id}/review", response_model=ApiResponse)
@router.post("/{record_id}/review", response_model=ApiResponse)
def review_overtime_record(record_id: str, payload: OvertimeRecordReview, request: Request):
    """مراجعة طلب الساعات الإضافية وتحديث الملاحظات وسجل التدقيق."""
    user = _require_authenticated_user(request)
    if user.get("role") not in ("ceo", "branch_manager", "admin", "system_admin", "general_manager"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: مراجعة الساعات الإضافية مقتصرة على مديري الفروع والمدير التنفيذي",
        )
    user_branch = user.get("branch_id")
    if user.get("role") not in CORPORATE_ROLES and user_branch:
        existing = OvertimeService.get_overtime_by_id(record_id)
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"سجل الساعات الإضافية '{record_id}' غير موجود",
            )
        rec_branch = getattr(existing, "branchId", None) or getattr(existing, "branch_id", None)
        if rec_branch and rec_branch != user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكن مراجعة ساعات إضافية لفرع آخر خارج نطاق صلاحياتك",
            )
    current_user_id = user.get("id")

    try:
        record = OvertimeService.review_overtime_record(
            record_id, payload, current_user_id=current_user_id
        )
        return ApiResponse(
            success=True,
            data=record.model_dump(),
            message="تم مراجعة وتحديث طلب الساعات الإضافية بنجاح",
        )
    except HTTPException:
        raise
    except ValueError as e:
        status_code = status.HTTP_404_NOT_FOUND if "غير موجود" in str(e) else status.HTTP_400_BAD_REQUEST
        raise HTTPException(
            status_code=status_code,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"فشل مراجعة طلب الساعات الإضافية: {str(e)}",
        )


@router.patch("/{record_id}/approve", response_model=ApiResponse)
@router.post("/{record_id}/approve", response_model=ApiResponse)
def approve_overtime_record(record_id: str, payload: OvertimeRecordApprove, request: Request):
    """اعتماد أو رفض طلب الساعات الإضافية وحساب الأثر المالي في SQLite وسجل التدقيق."""
    user = _require_authenticated_user(request)
    if user.get("role") not in ("ceo", "branch_manager", "admin", "system_admin", "general_manager"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: اعتماد أو رفض الساعات الإضافية مقتصر على المدير التنفيذي ومديري الفروع",
        )
    user_branch = user.get("branch_id")
    if user.get("role") not in CORPORATE_ROLES and user_branch:
        existing = OvertimeService.get_overtime_by_id(record_id)
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"سجل الساعات الإضافية '{record_id}' غير موجود",
            )
        rec_branch = getattr(existing, "branchId", None) or getattr(existing, "branch_id", None)
        if rec_branch and rec_branch != user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكن اعتماد ساعات إضافية لفرع آخر خارج نطاق صلاحياتك",
            )
    current_user_id = user.get("id")

    try:
        record, financial_impact = OvertimeService.approve_overtime_record(
            record_id, payload, current_user_id=current_user_id
        )
        meta_info = {}
        if financial_impact:
            meta_info["financial_impact"] = financial_impact.model_dump()

        action_word = "اعتماد" if record.status == "approved" else "رفض"
        return ApiResponse(
            success=True,
            data=record.model_dump(),
            message=f"تم {action_word} طلب الساعات الإضافية وحساب الأثر المالي بنجاح",
            meta=meta_info,
        )
    except HTTPException:
        raise
    except ValueError as e:
        status_code = status.HTTP_404_NOT_FOUND if "غير موجود" in str(e) else status.HTTP_400_BAD_REQUEST
        raise HTTPException(
            status_code=status_code,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"فشل اعتماد/رفض طلب الساعات الإضافية: {str(e)}",
        )
