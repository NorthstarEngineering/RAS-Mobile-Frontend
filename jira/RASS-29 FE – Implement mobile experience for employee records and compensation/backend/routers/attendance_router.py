from typing import Optional, Dict, Any
from fastapi import APIRouter, HTTPException, status, Request
from ..database.connection import get_db
from ..schemas.attendance_schemas import (
    ApiResponse,
    CheckInRequest,
    CheckOutRequest,
    AdjustDeductionRequest,
)
from ..services.attendance_service import AttendanceService

router = APIRouter(prefix="/attendance", tags=["Attendance"])

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
def get_attendance(
    date: Optional[str] = None,
    branch_id: Optional[str] = None,
    status: Optional[str] = None,
    employee_id: Optional[str] = None,
):
    """قائمة سجلات الحضور والانصراف مع دعم التصفية."""
    records = AttendanceService.get_attendance_list(
        date=date.strip() if date else None,
        branch_id=branch_id.strip() if branch_id else None,
        status=status.strip() if status else None,
        employee_id=employee_id.strip() if employee_id else None,
    )
    return ApiResponse(
        success=True,
        data=[r.model_dump() for r in records],
        message=f"تم جلب {len(records)} سجل حضور بنجاح",
    )


@router.post("/check-in", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
def check_in(payload: CheckInRequest, request: Request):
    """تسجيل حضور الموظف وحساب التأخير وحالة الدوام."""
    user = _require_authenticated_user(request)
    if user.get("role") not in ("cashier", "branch_manager", "admin", "system_admin", "ceo", "general_manager", "supervisor", "shift_lead"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: تسجيل الحضور مقتصر على الكاشير والإشراف وإدارة الفرع",
        )
    user_branch = user.get("branch_id")
    # Derive employee's actual branch from SQL database, not payload branch
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
                detail="غير مصرح: لا يمكن تسجيل حضور لموظف في فرع آخر خارج نطاق صلاحياتك",
            )
        if payload.branch_id and payload.branch_id != user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكن تسجيل حضور لفرع آخر خارج نطاق صلاحياتك",
            )

    effective_branch = emp_actual_branch or payload.branch_id or user_branch
    try:
        record = AttendanceService.check_in(
            employee_id=payload.employee_id,
            branch_id=effective_branch,
            date=payload.date,
            check_in_time=payload.check_in_time,
            shift_name=payload.shift_name,
            late_minutes=payload.late_minutes or 0,
        )
        return ApiResponse(
            success=True,
            data=record.model_dump(),
            message="تم تسجيل حضور الموظف بنجاح",
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"فشل تسجيل الحضور: {str(e)}",
        )


@router.post("/check-out", response_model=ApiResponse)
def check_out(payload: CheckOutRequest, request: Request):
    """تسجيل انصراف الموظف وتحديث وقت الخروج."""
    user = _require_authenticated_user(request)
    if user.get("role") not in ("cashier", "branch_manager", "admin", "system_admin", "ceo", "general_manager", "supervisor", "shift_lead"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: تسجيل الانصراف مقتصر على الكاشير والإشراف وإدارة الفرع",
        )
    user_branch = user.get("branch_id")
    if user.get("role") not in CORPORATE_ROLES and user_branch:
        with get_db() as conn:
            if payload.attendance_id:
                att_cur = conn.execute("SELECT branch_id FROM attendance_records WHERE id = ?", (payload.attendance_id,))
                att_row = att_cur.fetchone()
                if att_row:
                    att_branch = att_row["branch_id"] if hasattr(att_row, "keys") else att_row[0]
                    if att_branch and att_branch != user_branch:
                        raise HTTPException(
                            status_code=status.HTTP_403_FORBIDDEN,
                            detail="غير مصرح: لا يمكن تسجيل انصراف لفرع آخر خارج نطاق صلاحياتك",
                        )
            if payload.employee_id:
                emp_cur = conn.execute("SELECT branch_id FROM employees WHERE id = ? OR national_id = ?", (payload.employee_id, payload.employee_id))
                emp_row = emp_cur.fetchone()
                if emp_row:
                    emp_branch = emp_row["branch_id"] if hasattr(emp_row, "keys") else emp_row[0]
                    if emp_branch and emp_branch != user_branch:
                        raise HTTPException(
                            status_code=status.HTTP_403_FORBIDDEN,
                            detail="غير مصرح: لا يمكن تسجيل انصراف لموظف في فرع آخر خارج نطاق صلاحياتك",
                        )
    try:
        record = AttendanceService.check_out(
            attendance_id=payload.attendance_id,
            employee_id=payload.employee_id,
            date=payload.date,
            check_out_time=payload.check_out_time,
        )
        return ApiResponse(
            success=True,
            data=record.model_dump(),
            message="تم تسجيل انصراف الموظف بنجاح",
        )
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST if "already checked out" in str(e) else status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"فشل تسجيل الانصراف: {str(e)}",
        )


@router.post("/adjust-deduction", response_model=ApiResponse)
def adjust_deduction(payload: AdjustDeductionRequest, request: Request):
    """تسوية الخصم الإداري للموظف وحفظه في جدول attendance_adjustments."""
    user = _require_authenticated_user(request)
    if user.get("role") not in ("branch_manager", "admin", "system_admin", "ceo", "general_manager"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: تسوية الخصومات الإدارية مقتصرة على الإدارة ومديري الفروع",
        )
    user_branch = user.get("branch_id")
    if user.get("role") not in CORPORATE_ROLES and user_branch and payload.attendance_id:
        existing = AttendanceService.get_attendance_by_id(payload.attendance_id)
        if existing and existing.branchId and existing.branchId != user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكن تسوية خصم لفرع آخر خارج نطاق صلاحياتك",
            )
    try:
        adj, updated_record = AttendanceService.adjust_deduction(
            attendance_id=payload.attendance_id,
            adjusted_by_user_id=user["id"],
            waived_minutes=payload.waived_minutes or 0,
            deduction_amount=payload.deduction_amount,
            reason=payload.reason,
            original_late_minutes=payload.original_late_minutes,
        )
        return ApiResponse(
            success=True,
            data={
                "adjustment": adj.model_dump(),
                "record": updated_record.model_dump(),
            },
            message="تم اعتماد تسوية الخصم الإداري وحفظها بنجاح",
        )
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"فشل اعتماد تسوية الخصم: {str(e)}",
        )


@router.post("/{attendance_id}/adjust", response_model=ApiResponse)
def adjust_deduction_by_path(attendance_id: str, payload: AdjustDeductionRequest, request: Request):
    """مسار RESTful بديل لتسوية الخصم عبر المعرف المباشر."""
    user = _require_authenticated_user(request)
    if user.get("role") not in ("branch_manager", "admin", "system_admin", "ceo", "general_manager"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: تسوية الخصومات الإدارية مقتصرة على الإدارة ومديري الفروع",
        )
    user_branch = user.get("branch_id")
    if user.get("role") not in CORPORATE_ROLES and user_branch:
        existing = AttendanceService.get_attendance_by_id(attendance_id)
        if existing and existing.branchId and existing.branchId != user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكن تسوية خصم لفرع آخر خارج نطاق صلاحياتك",
            )
    try:
        adj, updated_record = AttendanceService.adjust_deduction(
            attendance_id=attendance_id,
            adjusted_by_user_id=user["id"],
            waived_minutes=payload.waived_minutes or 0,
            deduction_amount=payload.deduction_amount,
            reason=payload.reason,
            original_late_minutes=payload.original_late_minutes,
        )
        return ApiResponse(
            success=True,
            data={
                "adjustment": adj.model_dump(),
                "record": updated_record.model_dump(),
            },
            message="تم اعتماد تسوية الخصم الإداري وحفظها بنجاح",
        )
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"فشل اعتماد تسوية الخصم: {str(e)}",
        )


@router.get("/history/{employee_id}", response_model=ApiResponse)
def get_employee_history(
    employee_id: str,
    month: Optional[int] = None,
    year: Optional[int] = None,
):
    """سجل الحضور التاريخي للموظف مع إحصائيات الشهر."""
    try:
        history = AttendanceService.get_employee_history(
            employee_id=employee_id,
            month=month,
            year=year,
        )
        return ApiResponse(
            success=True,
            data=history.model_dump(),
            message=f"تم جلب السجل التاريخي للموظف ({history.employeeName}) بنجاح",
        )
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"فشل جلب سجل الحضور التاريخي: {str(e)}",
        )


@router.get("/{attendance_id}", response_model=ApiResponse)
def get_attendance_details(attendance_id: str):
    """تفاصيل سجل حضور محدد."""
    record = AttendanceService.get_attendance_by_id(attendance_id)
    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"سجل الحضور '{attendance_id}' غير موجود",
        )
    return ApiResponse(
        success=True,
        data=record.model_dump(),
        message="تم جلب تفاصيل السجل بنجاح",
    )


@router.post("/sync-devices", response_model=ApiResponse)
def sync_biometric_devices(request: Request):
    """مزامنة بيانات أجهزة البصمة البيومترية."""
    user = _require_authenticated_user(request)
    if user.get("role") not in ("ceo", "branch_manager", "admin", "system_admin", "general_manager", "hr_manager"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: مزامنة أجهزة البصمة مقتصرة على الإدارة",
        )
    import os
    biometric_url = os.environ.get("RMS_BIOMETRIC_SYNC_URL") or os.environ.get("RMS_BIOMETRIC_CONFIG")
    if not biometric_url:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="خدمة أجهزة البصمة البيومترية غير مهيأة: لم يتم ربط أجهزة بيومترية بالنظام بعد (Biometric sync unconfigured)",
        )
    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="أجهزة البصمة البيومترية غير متاحة حالياً (Biometric devices unavailable)",
    )
