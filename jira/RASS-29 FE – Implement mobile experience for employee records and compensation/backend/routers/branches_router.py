from typing import Optional, Dict, Any
from fastapi import APIRouter, HTTPException, status, Request
from ..schemas.branches_schemas import (
    ApiResponse,
    BranchCreate,
    BranchUpdate,
)
from ..services.branches_service import BranchesService

router = APIRouter(prefix="/branches", tags=["Branches"])


def _require_authenticated_user(request: Request) -> Dict[str, Any]:
    """Extract and strictly validate Bearer token or x-auth-token using server-side AuthService.
    Enforces authentication for all mutation endpoints. Rejects missing, invalid, or revoked tokens.
    """
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
def get_branches(
    search: Optional[str] = None,
    type: Optional[str] = None,
    is_active: Optional[bool] = None,
):
    """
    استعراض قائمة الفروع والمطبخ المركزي مع دعم التصفية حسب النوع وحالة النشاط والبحث بالاسم أو الكود.
    """
    branches = BranchesService.get_branches(
        search=search,
        type=type,
        is_active=is_active,
    )
    return ApiResponse(
        success=True,
        data=[b.model_dump() for b in branches],
        meta={"total": len(branches)},
    )


@router.post("", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
def create_branch(payload: BranchCreate, request: Request):
    """
    إنشاء فرع جديد وإدراجه في جدول branches مع توثيق العملية في سجل التدقيق audit_logs.
    يتطلب جلسة مصادقة سارية ومحققة بصلاحيات المدير التنفيذي (CEO).
    """
    user = _require_authenticated_user(request)
    if user.get("role") != "ceo":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="هذه العملية تتطلب صلاحيات المدير التنفيذي (CEO)",
        )
    user_id = user["id"]

    try:
        created = BranchesService.create_branch(payload, user_id=user_id)
        return ApiResponse(
            success=True,
            data=created.model_dump(),
            message="تم إنشاء الفرع بنجاح وإدراجه في شبكة الفروع",
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"حدث خطأ أثناء إنشاء الفرع: {str(e)}",
        )


@router.get("/central-kitchen/summary", response_model=ApiResponse)
def get_central_kitchen_summary():
    """
    جلب ملخص مؤشرات أداء المطبخ والمستودع المركزي وسعة التخزين وتنبيهات المخزون الحرج.
    """
    summary = BranchesService.get_central_kitchen_summary()
    return ApiResponse(
        success=True,
        data=summary.model_dump(),
    )


@router.get("/kitchen", response_model=ApiResponse)
def get_kitchen_alias():
    """
    مسار بديل لملخص المطبخ المركزي لدعم التوافق مع المسار الموثق في الخطة المعمارية.
    """
    return get_central_kitchen_summary()


@router.get("/{branch_id}", response_model=ApiResponse)
def get_branch_by_id(branch_id: str):
    """
    جلب تفاصيل فرع محدد بواسطة المعرف ID أو كود الفرع Code.
    """
    branch = BranchesService.get_branch_by_id(branch_id)
    if not branch:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"الفرع ذو المعرف أو الكود '{branch_id}' غير موجود",
        )
    return ApiResponse(
        success=True,
        data=branch.model_dump(),
    )


@router.put("/{branch_id}", response_model=ApiResponse)
def update_branch(branch_id: str, payload: BranchUpdate, request: Request):
    """
    تحديث بيانات الفرع في قاعدة بيانات SQLite وتسجيل التغييرات في audit_logs.
    يتطلب جلسة مصادقة سارية ومحققة بصلاحيات المدير التنفيذي (CEO).
    """
    user = _require_authenticated_user(request)
    if user.get("role") != "ceo":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="هذه العملية تتطلب صلاحيات المدير التنفيذي (CEO)",
        )
    user_id = user["id"]

    try:
        updated = BranchesService.update_branch(branch_id, payload, user_id=user_id)
        if not updated:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"الفرع ذو المعرف '{branch_id}' غير موجود للتحديث",
            )
        return ApiResponse(
            success=True,
            data=updated.model_dump(),
            message="تم حفظ وتحديث بيانات الفرع بنجاح",
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"حدث خطأ أثناء تحديث بيانات الفرع: {str(e)}",
        )


@router.delete("/{branch_id}", response_model=ApiResponse)
def delete_branch(branch_id: str, request: Request):
    """
    حذف الفرع أو تعطيله مع تسجيل الإجراء في سجل التدقيق audit_logs.
    يتطلب جلسة مصادقة سارية ومحققة بصلاحيات المدير التنفيذي (CEO).
    """
    user = _require_authenticated_user(request)
    if user.get("role") not in ("ceo", "branch_manager"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="هذه العملية تتطلب صلاحيات المدير التنفيذي (CEO) أو مدير الفرع",
        )
    user_id = user["id"]

    try:
        deleted = BranchesService.delete_branch(branch_id, user_id=user_id)
        if not deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"الفرع ذو المعرف '{branch_id}' غير موجود للحذف",
            )
        return ApiResponse(
            success=True,
            message="تم حذف الفرع وتوثيق العملية في سجل التدقيق",
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"حدث خطأ أثناء حذف الفرع: {str(e)}",
        )
