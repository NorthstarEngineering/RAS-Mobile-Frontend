from typing import Optional, Dict, Any
from fastapi import APIRouter, HTTPException, status, Query, Request
from ..database.connection import get_db
from ..schemas.employees_schemas import (
    EmployeeCreate,
    EmployeeUpdate,
    ApiResponse,
)
from ..services.employees_service import EmployeesService

router = APIRouter(prefix="/employees", tags=["Employees"])

CORPORATE_ROLES = {"ceo"}


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
def get_employees(
    request: Request,
    branch_id: Optional[str] = Query(None, alias="branchId"),
    status_filter: Optional[str] = Query(None, alias="status"),
    wage_type: Optional[str] = Query(None, alias="wageType"),
    search: Optional[str] = None,
):
    """
    List employees with strict RBAC and branch BOLA scoping:
    - Requires active authenticated session.
    - Restricted to managerial roles: ceo, branch_manager, shift_lead.
    - Cross-branch requests by branch-scoped user rejected with 403 Forbidden.
    - Missing branchId auto-scoped to caller's assigned branch.
    """
    user = _require_authenticated_user(request)
    role = user.get("role", "")
    if role not in ("ceo", "branch_manager", "shift_lead"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: ليس لديك صلاحية الاطلاع على بيانات الموظفين",
        )

    req_branch = branch_id or request.query_params.get("branchId") or request.query_params.get("branch_id")
    if role not in CORPORATE_ROLES:
        user_branch = user.get("branch_id")
        if not user_branch:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="المستخدم الحالي غير مرتبط بفرع محدد",
            )
        if req_branch and req_branch != user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكن الاطلاع على موظفي فرع آخر دون صلاحيات إدارية (Cross-Branch Scope Rejected)",
            )
        target_branch = user_branch
    else:
        target_branch = req_branch

    with get_db() as conn:
        employees = EmployeesService.list_employees(
            conn,
            branch_id=target_branch,
            status_filter=status_filter,
            wage_type=wage_type,
            search=search,
        )
        return ApiResponse(
            success=True,
            data=[emp.model_dump() for emp in employees],
            meta={"total_records": len(employees)},
        )


@router.post("", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
def create_employee(payload: EmployeeCreate, request: Request):
    user = _require_authenticated_user(request)
    if user.get("role") not in ("ceo", "branch_manager"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: إنشاء ملف موظف مقتصر على الإدارة ومديري الفروع",
        )
    user_branch = user.get("branch_id")
    payload_branch = getattr(payload, "branchId", None) or getattr(payload, "branch_id", None)
    if user.get("role") not in CORPORATE_ROLES and user_branch and payload_branch:
        if payload_branch != user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكن إضافة موظف لفرع آخر خارج نطاق صلاحياتك",
            )
    with get_db() as conn:
        created = EmployeesService.create_employee(conn, payload)
        return ApiResponse(
            success=True,
            data=created.model_dump(),
        )


@router.get("/{emp_id}", response_model=ApiResponse)
def get_employee_by_id(emp_id: str, request: Request):
    """
    Retrieve single employee details with branch BOLA protection.
    """
    user = _require_authenticated_user(request)
    role = user.get("role", "")
    if role not in ("ceo", "branch_manager", "shift_lead"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: ليس لديك صلاحية الاطلاع على بيانات الموظف",
        )

    with get_db() as conn:
        employee = EmployeesService.get_employee_by_id(conn, emp_id)
        if not employee:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Employee with ID '{emp_id}' not found",
            )
        if role not in CORPORATE_ROLES:
            user_branch = user.get("branch_id")
            if employee.branchId and user_branch and employee.branchId != user_branch:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكن الاطلاع على بيانات موظف تابع لفرع آخر",
                )
        return ApiResponse(
            success=True,
            data=employee.model_dump(),
        )


@router.put("/{emp_id}", response_model=ApiResponse)
def update_employee(emp_id: str, payload: EmployeeUpdate, request: Request):
    user = _require_authenticated_user(request)
    if user.get("role") not in ("ceo", "branch_manager"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: تعديل بيانات موظف مقتصر على الإدارة ومديري الفروع",
        )
    user_branch = user.get("branch_id")
    with get_db() as conn:
        existing = EmployeesService.get_employee_by_id(conn, emp_id)
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Employee with ID '{emp_id}' not found",
            )
        if user.get("role") not in CORPORATE_ROLES and user_branch:
            if existing.branchId and existing.branchId != user_branch:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكن تعديل موظف تابع لفرع آخر",
                )
            payload_branch = getattr(payload, "branchId", None) or getattr(payload, "branch_id", None)
            if payload_branch and payload_branch != user_branch:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكن نقل موظف لفرع آخر",
                )
        updated = EmployeesService.update_employee(conn, emp_id, payload)
        return ApiResponse(
            success=True,
            data=updated.model_dump(),
        )


@router.get("/{emp_id}/compensation", response_model=ApiResponse)
def get_employee_compensation(emp_id: str, request: Request):
    user = _require_authenticated_user(request)
    if user.get("role") not in ("ceo", "branch_manager"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: الاطلاع على بيانات الأجور والرواتب مقتصر على الإدارة ومديري الفروع",
        )
    user_branch = user.get("branch_id")
    with get_db() as conn:
        existing = EmployeesService.get_employee_by_id(conn, emp_id)
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Employee with ID '{emp_id}' not found",
            )
        if user.get("role") not in CORPORATE_ROLES and user_branch:
            if existing.branchId and existing.branchId != user_branch:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكن الاطلاع على رواتب موظف في فرع آخر",
                )
        comp = EmployeesService.get_employee_compensation(conn, emp_id)
        return ApiResponse(
            success=True,
            data=comp.model_dump(),
        )


@router.get("/{emp_id}/pay-history", response_model=ApiResponse)
def get_employee_pay_history(emp_id: str, request: Request):
    user = _require_authenticated_user(request)
    if user.get("role") not in ("ceo", "branch_manager"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: الاطلاع على سجل الرواتب مقتصر على الإدارة ومديري الفروع",
        )
    user_branch = user.get("branch_id")
    with get_db() as conn:
        existing = EmployeesService.get_employee_by_id(conn, emp_id)
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Employee with ID '{emp_id}' not found",
            )
        if user.get("role") not in CORPORATE_ROLES and user_branch:
            if existing.branchId and existing.branchId != user_branch:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكن الاطلاع على سجل رواتب موظف في فرع آخر",
                )
        history = EmployeesService.get_employee_pay_history(conn, emp_id)
        return ApiResponse(
            success=True,
            data=[r.model_dump() for r in history],
            meta={"total_records": len(history)},
        )


@router.delete("/{emp_id}", response_model=ApiResponse)
def delete_employee(emp_id: str, request: Request):
    """
    حذف الموظف أو أرشفته مع توثيق العملية في سجل التدقيق audit_logs.
    يتطلب صلاحيات المدير التنفيذي (CEO) أو مدير الفرع التابع له الموظف.
    """
    user = _require_authenticated_user(request)
    role = user.get("role", "")
    if role not in ("ceo", "branch_manager"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: حذف الموظف مقتصر على الإدارة ومديري الفروع",
        )

    user_branch = user.get("branch_id")
    user_id = user.get("id")

    with get_db() as conn:
        existing = EmployeesService.get_employee_by_id(conn, emp_id)
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"الموظف ذو المعرف '{emp_id}' غير موجود للحذف",
            )

        if role not in CORPORATE_ROLES and user_branch:
            if existing.branchId and existing.branchId != user_branch:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكن لمدير الفرع حذف موظف تابع لفرع آخر",
                )

        deleted = EmployeesService.delete_employee(conn, emp_id, user_id=user_id)
        if not deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"تعذر حذف الموظف ذو المعرف '{emp_id}'",
            )

        return ApiResponse(
            success=True,
            message="تم حذف الموظف بنجاح وتوثيق العملية في سجل التدقيق",
        )

