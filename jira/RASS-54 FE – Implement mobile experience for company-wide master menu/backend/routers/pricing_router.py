from typing import Optional, List, Dict, Any
from fastapi import APIRouter, HTTPException, Depends, status
from ..schemas.pricing_schemas import (
    ApiResponse,
    PriceChangeRequestCreate,
    PriceChangeRequestApprove,
    PriceChangeRequestReject,
    PriceChangeRequestResponse,
    PriceHistoryResponse,
)
from ..services.pricing_service import PricingService
from .auth_router import get_current_user, get_current_ceo

router = APIRouter(prefix="/pricing", tags=["Pricing"])

@router.get("/requests", response_model=ApiResponse)
def get_price_requests(
    status: Optional[str] = None,
    item_id: Optional[str] = None,
    branch_id: Optional[str] = None,
):
    """قائمة طلبات تغيير الأسعار مع دعم التصفية حسب الحالة، الصنف، أو الفرع."""
    requests = PricingService.get_requests(
        status=status,
        item_id=item_id,
        branch_id=branch_id,
    )
    return ApiResponse(
        success=True,
        data=[r.model_dump() for r in requests],
        message=f"تم جلب {len(requests)} طلب بنجاح",
        meta={"total_records": len(requests)},
    )

@router.get("/requests/{id}", response_model=ApiResponse)
def get_price_request_by_id(id: str):
    """جلب تفاصيل طلب تغيير السعر بالمعرف."""
    req = PricingService.get_request_by_id(id)
    return ApiResponse(
        success=True,
        data=req.model_dump(),
        message="تم جلب تفاصيل الطلب بنجاح",
    )

@router.post("/requests", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
def create_price_request(
    payload: PriceChangeRequestCreate,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """تقديم طلب جديد لتعديل سعر صنف."""
    role = current_user.get("role")
    if role not in ("ceo", "branch_manager"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: تقديم طلبات تغيير الأسعار مقتصر على مديري الفروع والمدير التنفيذي",
        )
    user_id = current_user.get("id")
    actor_branch = current_user.get("branch_id")
    req_branch = payload.branchId or payload.branch_id

    # Cross-branch tenant isolation: Non-CEO users can only request pricing for their assigned branch
    if role != "ceo":
        if not actor_branch or (req_branch and req_branch != actor_branch):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكن تقديم طلب تعديل سعر لفرع غير الفرع المعين لك (Cross-Branch Spoof Rejected)",
            )
        payload.branchId = actor_branch
        payload.branch_id = actor_branch

    # Enforce actual signed actor (prevent payload faking)
    payload.requestedByUserId = user_id

    created = PricingService.create_request(payload, user_id=user_id)
    return ApiResponse(
        success=True,
        data=created.model_dump(),
        message="تم تقديم طلب تعديل السعر بنجاح",
    )

@router.post("/requests/{id}/approve", response_model=ApiResponse)
def approve_price_request(
    id: str,
    payload: Optional[PriceChangeRequestApprove] = None,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    """
    اعتماد التعديل (ACID Transaction):
    - تحديث حالة الطلب إلى approved
    - تحديث السعر الجديد ونسبة الهامش في menu_items
    - إدراج سجل تاريخي جديد في price_history
    - تسجيل حركة التدقيق في audit_logs
    """
    user_id = current_user.get("id")
    if payload:
        payload.approvedByUserId = user_id

    approved = PricingService.approve_request(id, payload, user_id=user_id)
    return ApiResponse(
        success=True,
        data=approved.model_dump(),
        message="تم اعتماد تعديل السعر وتحديث الصنف وإدراج السجل التاريخي بنجاح",
    )

@router.post("/requests/{id}/reject", response_model=ApiResponse)
def reject_price_request(
    id: str,
    payload: Optional[PriceChangeRequestReject] = None,
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    """رفض طلب تعديل السعر وتسجيل سبب الرفض وملاحظات الإدارة."""
    user_id = current_user.get("id")
    if payload:
        payload.reviewedByUserId = user_id

    rejected = PricingService.reject_request(id, payload, user_id=user_id)
    return ApiResponse(
        success=True,
        data=rejected.model_dump(),
        message="تم رفض طلب تعديل السعر بنجاح",
    )

@router.post("/activate-due", response_model=ApiResponse)
def activate_due_prices(
    current_user: Dict[str, Any] = Depends(get_current_ceo),
):
    """تفعيل فوري لكافة طلبات الأسعار المعتمدة المستحقة (تجاوزت أو بلغت تاريخ السريان)."""
    activated = PricingService.activate_due_prices()
    return ApiResponse(
        success=True,
        data=activated,
        message=f"تم تفعيل {len(activated)} صنف بنجاح",
        meta={"activated_count": len(activated)},
    )

@router.get("/menu-items", response_model=ApiResponse)
def get_active_menu_items():
    """جلب قائمة الأصناف النشطة لاستخدامها في نماذج طلبات التسعير."""
    items = PricingService.get_active_menu_items()
    return ApiResponse(
        success=True,
        data=items,
        message=f"تم جلب {len(items)} صنف نشط بنجاح",
        meta={"total": len(items)},
    )

@router.get("/summary/{item_id}", response_model=ApiResponse)
def get_item_pricing_summary(item_id: str):
    """جلب ملخص تسعير الصنف (الاسم، الكود، الفئة، السعر الحالي، السعر القادم)."""
    summary = PricingService.get_item_pricing_summary(item_id)
    return ApiResponse(
        success=True,
        data=summary.model_dump(),
        message="تم جلب ملخص تسعير الصنف بنجاح",
    )

@router.get("/history/{item_id}", response_model=ApiResponse)
def get_price_history(item_id: str):
    """جلب السجل التاريخي المالي لأسعار بيع الصنف."""
    history = PricingService.get_price_history(item_id)
    summary_data = None
    try:
        summary_obj = PricingService.get_item_pricing_summary(item_id)
        summary_data = summary_obj.model_dump()
    except HTTPException:
        summary_data = None

    return ApiResponse(
        success=True,
        data=[h.model_dump() for h in history],
        message=f"تم جلب {len(history)} سجل تاريخي بنجاح",
        meta={
            "item_id": item_id,
            "total_entries": len(history),
            "summary": summary_data,
        },
    )
