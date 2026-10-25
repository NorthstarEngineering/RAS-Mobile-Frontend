from typing import Optional, Dict, Any
from fastapi import APIRouter, HTTPException, Query, status, Depends, Request
from ..schemas.inventory_schemas import (
    ApiResponse,
    StockAdjustmentRequest,
)
from ..services.inventory_service import InventoryService
from .auth_router import get_current_user
from ..database.connection import get_db

router = APIRouter(prefix="/inventory", tags=["Inventory & Stock Control"])


@router.get("", response_model=ApiResponse)
def get_inventory(
    branch_id: Optional[str] = Query(None, description="معرف الفرع"),
    category: Optional[str] = Query(None, description="تصفية حسب الفئة"),
    stock_level: Optional[str] = Query(None, alias="status", description="تصفية حسب حالة المخزون"),
    search: Optional[str] = Query(None, alias="q", description="البحث بالاسم أو SKU"),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    جرد المخزون حسب الفرع مع دعم الفلاتر والبحث.
    يتطلب جلسة مصادقة سارية، ويسمح لأمين الصندوق بالاطلاع على الكتالوج التشغيلي لفرعه فقط،
    ويطبق العزل النطاقي الصارم للفروع (BOLA Guard).
    """
    role = current_user.get("role")
    allowed_roles = ("ceo", "branch_manager", "shift_lead", "cashier", "inventory_clerk")
    if role not in allowed_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: ليس لديك صلاحية الاطلاع على قائمة المخزون",
        )

    user_branch = current_user.get("branch_id")
    if role != "ceo":
        if not user_branch:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="المستخدم الحالي غير مرتبط بفرع محدد",
            )
        if branch_id and branch_id.strip() and branch_id.strip() != user_branch and branch_id.strip() != "all":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكنك الاطلاع على مخزون فرع آخر",
            )
        target_branch = user_branch
    else:
        target_branch = branch_id.strip() if (branch_id and branch_id.strip() and branch_id.strip() != "all") else None

    try:
        items = InventoryService.get_inventory_list(
            branch_id=target_branch,
            category=category.strip() if category else None,
            stock_level=stock_level.strip() if stock_level else None,
            search=search.strip() if search else None,
        )
        return ApiResponse(
            success=True,
            data=[item.model_dump(by_alias=True) for item in items],
            message=f"تم جلب بيانات جرد المخزون بنجاح ({len(items)} صنف)",
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"حدث خطأ أثناء جلب جرد المخزون: {str(e)}",
        )


@router.get("/movements", response_model=ApiResponse)
def get_stock_movements(
    branch_id: Optional[str] = Query(None, description="معرف الفرع"),
    stock_item_id: Optional[str] = Query(None, description="معرف الصنف المخصص"),
    movement_type: Optional[str] = Query(None, alias="type", description="نوع الحركة المخزنية"),
    limit: int = Query(50, ge=1, le=200, description="الحد الأقصى للنتائج"),
    offset: int = Query(0, ge=0, description="إزاحة النتائج"),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    استعراض سجل الحركات المخزنية للفرع (وارد، صرف، تسويات، تحويلات).
    يتطلب جلسة مصادقة سارية، ويمنع أمين الصندوق، ويطبق العزل النطاقي للفرع.
    """
    role = current_user.get("role")
    if role == "cashier":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: لا يملك أمين الصندوق صلاحية الاطلاع على سجل الحركات المخزنية",
        )
    if role not in ("ceo", "branch_manager", "shift_lead", "inventory_clerk"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: ليس لديك صلاحية الاطلاع على الحركات المخزنية",
        )

    user_branch = current_user.get("branch_id")
    if role != "ceo":
        if not user_branch:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="المستخدم الحالي غير مرتبط بفرع محدد",
            )
        if branch_id and branch_id.strip() and branch_id.strip() != user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكنك الاطلاع على حركات فرع آخر",
            )
        target_branch = user_branch
    else:
        target_branch = branch_id.strip() if branch_id else "br_01"

    try:
        movements = InventoryService.get_movements(
            branch_id=target_branch,
            stock_item_id=stock_item_id,
            movement_type=movement_type,
            limit=limit,
            offset=offset,
        )
        return ApiResponse(
            success=True,
            data=[m.model_dump(by_alias=True) for m in movements],
            message=f"تم جلب سجل الحركات المخزنية بنجاح ({len(movements)} حركة)",
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"حدث خطأ أثناء جلب الحركات المخزنية: {str(e)}",
        )


@router.get("/valuation", response_model=ApiResponse)
@router.get("/value", response_model=ApiResponse)
def get_inventory_valuation(
    branch_id: Optional[str] = Query(None, description="معرف الفرع"),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    تقرير القيمة المالية الإجمالية للمخزون وتحليل الفئات والأصناف الأعلى قيمة.
    يتطلب جلسة مصادقة سارية ويمنع وصول أمين الصندوق، ويطبق العزل النطاقي للفرع.
    """
    role = current_user.get("role")
    if role == "cashier":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: لا يملك أمين الصندوق صلاحية الاطلاع على التقييم المالي للمخزون",
        )
    if role not in ("ceo", "branch_manager", "shift_lead"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: ليس لديك صلاحية الاطلاع على التقييم المالي للمخزون",
        )

    user_branch = current_user.get("branch_id")
    if role != "ceo":
        if not user_branch:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="المستخدم الحالي غير مرتبط بفرع محدد",
            )
        if branch_id and branch_id != user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكنك الاطلاع على التقييم المالي لفرع آخر",
            )
        target_branch = user_branch
    else:
        target_branch = branch_id or user_branch or "br_01"

    try:
        val = InventoryService.get_valuation(branch_id=target_branch)
        return ApiResponse(
            success=True,
            data=val.model_dump(by_alias=True),
            message="تم حساب التقييم المالي للمخزون بنجاح",
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"حدث خطأ أثناء حساب تقييم المخزون: {str(e)}",
        )


@router.post("/adjust", response_model=ApiResponse, status_code=status.HTTP_200_OK)
def adjust_stock(
    payload: StockAdjustmentRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    تسوية هالك/عجز/فائض مع خصم فوري من الرصيد وقيد في stock_movements بمعاملة ذرية ACID.
    يتطلب جلسة مصادقة سارية، ويمنع أمين الصندوق، ويتحقق من الفرع الفعلي للصنف من SQLite لمنع تزوير الفرع.
    """
    role = current_user.get("role")
    if role == "cashier":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: لا يملك أمين الصندوق صلاحية إجراء تسويات مخزنية",
        )
    if role not in ("ceo", "branch_manager", "shift_lead"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: ليس لديك صلاحية إجراء تسويات مخزنية",
        )

    if not payload.item_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="معرف الصنف مطلوب للتسوية المخزنية",
        )

    # 1. Fetch item actual branch from SQL
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT id, branch_id FROM stock_items WHERE id = ?", (payload.item_id,))
        item_row = cursor.fetchone()

    if not item_row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"صنف المخزون بالمعرف '{payload.item_id}' غير موجود",
        )

    actual_branch = str(item_row["branch_id"])

    # 2. Branch isolation from actual SQL branch, reject body branch spoof
    if role != "ceo":
        user_branch = current_user.get("branch_id")
        if not user_branch or actual_branch != user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكنك تعديل صنف تابع لفرع آخر",
            )
        if payload.branch_id and payload.branch_id != user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكنك تنفيذ تسوية على فرع غير مصرح لك به",
            )
    else:
        if payload.branch_id and payload.branch_id != actual_branch:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"معرف الفرع في الطلب '{payload.branch_id}' لا يتطابق مع فرع الصنف الفعلي '{actual_branch}'",
            )

    payload.branch_id = actual_branch
    actor_user_id = current_user.get("id")

    try:
        result = InventoryService.adjust_stock(payload, actor_user_id=actor_user_id)
        return ApiResponse(
            success=True,
            data=result.model_dump(by_alias=True),
            message="تم اعتماد التسوية المخزنية وتحديث رصيد الصنف وقيد الحركة بنجاح",
        )
    except ValueError as e:
        error_msg = str(e)
        if "غير موجود" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=error_msg,
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error_msg,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل تنفيذ التسوية المخزنية: {str(e)}",
        )


@router.post("/{id}/adjust", response_model=ApiResponse, status_code=status.HTTP_200_OK)
def adjust_stock_by_path(
    id: str,
    payload: StockAdjustmentRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    مسار بديل لتسوية صنف مخزني محدد عبر المعرف في المسار.
    """
    payload.item_id = id
    return adjust_stock(payload, current_user=current_user)


@router.get("/{id}", response_model=ApiResponse)
def get_inventory_item(
    id: str,
    branch_id: Optional[str] = Query(None, description="معرف الفرع (اختياري)"),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    جلب تفاصيل صنف مخزون محدد مع التحقق من الهوية ونطاق الفرع.
    يتيح لأمين الصندوق استعراض الأصناف في فرعه فقط، ويمنع الوصول للأصناف خارج النطاق.
    """
    role = current_user.get("role")
    allowed_roles = ("ceo", "branch_manager", "shift_lead", "cashier", "inventory_clerk")
    if role not in allowed_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: ليس لديك صلاحية الاطلاع على تفاصيل صنف المخزون",
        )

    user_branch = current_user.get("branch_id")
    if role != "ceo":
        if not user_branch:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="المستخدم الحالي غير مرتبط بفرع محدد",
            )
        if branch_id and branch_id.strip() and branch_id.strip() != user_branch and branch_id.strip() != "all":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكنك الاطلاع على صنف تابع لفرع آخر",
            )
        target_branch = user_branch
    else:
        target_branch = branch_id.strip() if (branch_id and branch_id.strip() and branch_id.strip() != "all") else None

    try:
        item = InventoryService.get_inventory_item(item_id=id, branch_id=target_branch)
        if role != "ceo":
            item_branch = getattr(item, "branch_id", None) or getattr(item, "branchId", None)
            if item_branch and item_branch != user_branch:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: صنف المخزون يتبع لفرع آخر خارج نطاق صلاحياتك",
                )
        return ApiResponse(
            success=True,
            data=item.model_dump(by_alias=True),
            message="تم جلب تفاصيل صنف المخزون بنجاح",
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
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"حدث خطأ أثناء جلب تفاصيل الصنف: {str(e)}",
        )
