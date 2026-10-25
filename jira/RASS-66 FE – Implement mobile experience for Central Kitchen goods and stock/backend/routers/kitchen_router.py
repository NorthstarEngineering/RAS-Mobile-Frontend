from typing import Optional, List, Dict, Any
from fastapi import APIRouter, HTTPException, Query, status as http_status, Depends
from ..services.central_kitchen_service import CentralKitchenService
from ..schemas.central_kitchen_schemas import (
    KitchenItemResponse,
    KitchenItemCreate,
    KitchenItemUpdate,
    KitchenMovementResponse,
    ApiResponse,
)
from .auth_router import get_current_user
from ..database.connection import get_db

router = APIRouter(prefix="/kitchen", tags=["Central Kitchen"])


@router.get("/dashboard", response_model=ApiResponse)
def get_kitchen_dashboard(
    branch_id: Optional[str] = Query(None),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    استعراض مؤشرات أداء لوحة تحكم المطبخ المركزي:
    قيمة المخزون الكلية، عدد الأصناف، النواقص الحرجة، وآخر الحركات.
    يتطلب جلسة مصادقة سارية، ويمنع أمين الصندوق، ويقصر الاطلاع على الإدارة التنفيذية والمشرفين.
    """
    role = current_user.get("role")
    if role == "cashier":
        raise HTTPException(
            status_code=http_status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: لا يملك أمين الصندوق صلاحية الاطلاع على لوحة المطبخ المركزي",
        )
    allowed_roles = ("ceo", "branch_manager", "shift_lead", "kitchen_manager")
    if role not in allowed_roles:
        raise HTTPException(
            status_code=http_status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: ليس لديك صلاحية الاطلاع على لوحة المطبخ المركزي",
        )

    try:
        data = CentralKitchenService.get_kitchen_dashboard(branch_id=branch_id)
        return ApiResponse(success=True, data=data)
    except Exception as e:
        raise HTTPException(
            status_code=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to load kitchen dashboard: {str(e)}",
        )


@router.get("/items", response_model=ApiResponse)
def get_kitchen_items(
    category: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    q: Optional[str] = Query(None),
    query: Optional[str] = Query(None),
    branch_id: Optional[str] = Query(None),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    استعراض قائمة المواد الخام والمخزون بالمطبخ المركزي مع الفلترة والبحث.
    يتطلب جلسة مصادقة سارية، ويمنع أمين الصندوق لحماية تكاليف الخامات والوصفات.
    """
    role = current_user.get("role")
    if role == "cashier":
        raise HTTPException(
            status_code=http_status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: لا يملك أمين الصندوق صلاحية الاطلاع على خامات المطبخ المركزي",
        )
    allowed_roles = ("ceo", "branch_manager", "shift_lead", "kitchen_manager")
    if role not in allowed_roles:
        raise HTTPException(
            status_code=http_status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: ليس لديك صلاحية الاطلاع على خامات المطبخ المركزي",
        )

    try:
        search_term = q or query
        items, meta = CentralKitchenService.get_kitchen_items(
            category=category,
            status=status,
            search=search_term,
            branch_id=branch_id,
        )
        return ApiResponse(
            success=True,
            data=[item.model_dump(by_alias=True) for item in items],
            meta=meta,
        )
    except Exception as e:
        raise HTTPException(
            status_code=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch kitchen items: {str(e)}",
        )


@router.post("/items", response_model=ApiResponse, status_code=http_status.HTTP_201_CREATED)
def create_kitchen_item(
    payload: KitchenItemCreate,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    إضافة صنف خام جديد في مستودع المطبخ المركزي مع إنشاء رصيد افتتاحي وسجل تدقيق.
    يتطلب جلسة مصادقة سارية، ويمنع أمين الصندوق، ويقصر الإدارة على مسؤولي المطبخ المركزي أو المدير التنفيذي.
    """
    role = current_user.get("role")
    if role == "cashier":
        raise HTTPException(
            status_code=http_status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: لا يملك أمين الصندوق صلاحية إضافة أصناف بالمطبخ المركزي",
        )
    if role not in ("ceo", "branch_manager", "shift_lead"):
        raise HTTPException(
            status_code=http_status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: ليس لديك صلاحية إضافة أصناف بالمطبخ المركزي",
        )

    with get_db() as conn:
        kitchen_branch_id = CentralKitchenService.get_kitchen_branch_id(conn)

    if role != "ceo":
        user_branch = current_user.get("branch_id")
        if not user_branch or user_branch != kitchen_branch_id:
            raise HTTPException(
                status_code=http_status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: إدارة أصناف المطبخ المركزي مقتصرة على مسؤولي المطبخ المركزي",
            )
        if payload.branch_id and payload.branch_id != kitchen_branch_id:
            raise HTTPException(
                status_code=http_status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكن تحديد فرع للمطبخ المركزي خارج النطاق",
            )

    payload.branch_id = kitchen_branch_id
    actor_user_id = current_user.get("id")

    try:
        created = CentralKitchenService.create_kitchen_item(payload, actor_user_id=actor_user_id)
        return ApiResponse(
            success=True,
            data=created.model_dump(by_alias=True),
            message="تم حفظ واعتماد الصنف المخزني بالمطبخ المركزي بنجاح",
        )
    except ValueError as e:
        raise HTTPException(status_code=http_status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create kitchen item: {str(e)}",
        )


@router.get("/items/{id}", response_model=ApiResponse)
def get_kitchen_item_by_id(
    id: str,
    branch_id: Optional[str] = Query(None),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    استعراض تفاصيل صنف خام محدد بالمعرف أو كود SKU.
    يتطلب جلسة مصادقة سارية، ويمنع أمين الصندوق.
    """
    role = current_user.get("role")
    if role == "cashier":
        raise HTTPException(
            status_code=http_status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: لا يملك أمين الصندوق صلاحية الاطلاع على تفاصيل خامات المطبخ المركزي",
        )
    allowed_roles = ("ceo", "branch_manager", "shift_lead", "kitchen_manager")
    if role not in allowed_roles:
        raise HTTPException(
            status_code=http_status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: ليس لديك صلاحية الاطلاع على تفاصيل خامات المطبخ المركزي",
        )

    item = CentralKitchenService.get_kitchen_item_by_id(item_id=id, branch_id=branch_id)
    if not item:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail=f"الصنف المخزني '{id}' غير موجود بالمستودع المركزي",
        )
    return ApiResponse(success=True, data=item.model_dump(by_alias=True))


@router.put("/items/{id}", response_model=ApiResponse)
def update_kitchen_item(
    id: str,
    payload: KitchenItemUpdate,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    تحديث بيانات صنف خام بالمطبخ المركزي (الأسعار، الحدود، الكميات).
    يتطلب جلسة مصادقة سارية، ويمنع أمين الصندوق، ويتحقق من وجود الصنف ونطاق الفرع.
    """
    role = current_user.get("role")
    if role == "cashier":
        raise HTTPException(
            status_code=http_status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: لا يملك أمين الصندوق صلاحية تعديل أصناف بالمطبخ المركزي",
        )
    if role not in ("ceo", "branch_manager", "shift_lead"):
        raise HTTPException(
            status_code=http_status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: ليس لديك صلاحية تعديل أصناف بالمطبخ المركزي",
        )

    with get_db() as conn:
        kitchen_branch_id = CentralKitchenService.get_kitchen_branch_id(conn)
        target_branch = payload.branch_id or kitchen_branch_id
        cursor = conn.execute(
            """
            SELECT * FROM stock_items
            WHERE (branch_id = ? OR branch_id IN (SELECT id FROM branches WHERE type = 'kitchen'))
              AND (
                  id = ?
                  OR UPPER(sku) = UPPER(?)
                  OR id = 'ck-' || ?
                  OR id = 'ck_' || ?
                  OR REPLACE(id, 'ck-', '') = ?
                  OR REPLACE(id, 'ck_', '') = ?
              )
            LIMIT 1
            """,
            (target_branch, id, id, id, id, id, id),
        )
        item_row = cursor.fetchone()
        if not item_row:
            cursor = conn.execute(
                "SELECT * FROM stock_items WHERE id = ? OR UPPER(sku) = UPPER(?) LIMIT 1",
                (id, id),
            )
            item_row = cursor.fetchone()

    if not item_row:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail=f"الصنف المخزني '{id}' غير موجود بالمستودع المركزي",
        )

    actual_branch = item_row["branch_id"]

    if role != "ceo":
        user_branch = current_user.get("branch_id")
        if not user_branch or (user_branch != actual_branch and user_branch != kitchen_branch_id):
            raise HTTPException(
                status_code=http_status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: تعديل أصناف المطبخ المركزي مقتصر على مسؤولي المطبخ المركزي",
            )
        if payload.branch_id and payload.branch_id != actual_branch and payload.branch_id != kitchen_branch_id:
            raise HTTPException(
                status_code=http_status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكن تحديد فرع للمطبخ المركزي خارج النطاق",
            )

    actor_user_id = current_user.get("id")

    try:
        updated = CentralKitchenService.update_kitchen_item(
            item_id=id, payload=payload, actor_user_id=actor_user_id
        )
        if not updated:
            raise HTTPException(
                status_code=http_status.HTTP_404_NOT_FOUND,
                detail=f"الصنف المخزني '{id}' غير موجود بالمستودع المركزي",
            )
        return ApiResponse(
            success=True,
            data=updated.model_dump(by_alias=True),
            message="تم تحديث بيانات الصنف المخزني بنجاح",
        )
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=http_status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update kitchen item: {str(e)}",
        )


@router.get("/movements", response_model=ApiResponse)
def get_kitchen_movements(
    type: Optional[str] = Query(None),
    filter: Optional[str] = Query(None),
    q: Optional[str] = Query(None),
    query: Optional[str] = Query(None),
    item_id: Optional[str] = Query(None),
    branch_id: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=500),
    offset: int = Query(0, ge=0),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    استعراض سجل حركات المخزون للمطبخ المركزي (صرف، توريد، تحويل، تسوية).
    يتطلب جلسة مصادقة سارية، ويمنع أمين الصندوق.
    """
    role = current_user.get("role")
    if role == "cashier":
        raise HTTPException(
            status_code=http_status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: لا يملك أمين الصندوق صلاحية الاطلاع على سجل حركات المطبخ المركزي",
        )
    allowed_roles = ("ceo", "branch_manager", "shift_lead", "kitchen_manager")
    if role not in allowed_roles:
        raise HTTPException(
            status_code=http_status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: ليس لديك صلاحية الاطلاع على سجل حركات المطبخ المركزي",
        )

    try:
        m_type = type or filter
        search_term = q or query
        movements, meta = CentralKitchenService.get_kitchen_movements(
            movement_type=m_type,
            search=search_term,
            item_id=item_id,
            branch_id=branch_id,
            limit=limit,
            offset=offset,
        )
        return ApiResponse(
            success=True,
            data=[m.model_dump(by_alias=True) for m in movements],
            meta=meta,
        )
    except Exception as e:
        raise HTTPException(
            status_code=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch kitchen movements: {str(e)}",
        )
