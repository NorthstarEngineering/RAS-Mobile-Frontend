from typing import Optional, Dict, Any
from fastapi import APIRouter, HTTPException, Request, status, Query
from ..schemas.supply_schemas import (
    ApiResponse,
    SupplyOrderCreate,
    ExecuteSupplyOrderRequest,
    ReceiveSupplyOrderRequest,
)
from ..services.supply_service import SupplyService

router = APIRouter(prefix="/supply", tags=["Supply"])


def _get_request_user(request: Request) -> Optional[Dict[str, Any]]:
    """Extract authenticated user session if token present."""
    auth_header = request.headers.get("authorization")
    token = None
    if auth_header and auth_header.lower().startswith("bearer "):
        token = auth_header[7:].strip()
    elif "x-auth-token" in request.headers:
        token = request.headers["x-auth-token"].strip()

    if not token:
        return None

    from ..services.auth_service import AuthService
    return AuthService.get_current_user_from_token(token)


def _require_authenticated_user(request: Request) -> Dict[str, Any]:
    """
    Extracts and authenticates user from Bearer token or x-auth-token header
    using existing AuthService. Missing/invalid/revoked token raises HTTP 401.
    """
    auth_header = request.headers.get("authorization")
    token = None
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
@router.get("/", response_model=ApiResponse)
def get_supply_orders(
    request: Request,
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by status ('pending', 'preparing', 'in_transit', 'received', 'draft', 'rejected' or Arabic labels)"),
    branch_id: Optional[str] = Query(None, alias="branchId", description="Filter by branch (destination or source)"),
    branch_id_alt: Optional[str] = Query(None, alias="branch_id"),
    destination_branch_id: Optional[str] = Query(None, alias="destinationBranchId"),
    destination_branch_id_alt: Optional[str] = Query(None, alias="destination_branch_id"),
    source_kitchen_id: Optional[str] = Query(None, alias="sourceKitchenId"),
    source_kitchen_id_alt: Optional[str] = Query(None, alias="source_kitchen_id"),
    search: Optional[str] = Query(None, description="Search query by order number or branch name"),
):
    """
    قائمة طلبات التوريد مع دعم التصفية حسب الحالة، الفرع، والبحث النصي مع التحقق من الهوية ونطاق الفرع.
    """
    user = _require_authenticated_user(request)

    try:
        req_branch = branch_id or branch_id_alt
        req_dest = destination_branch_id or destination_branch_id_alt
        req_kitchen = source_kitchen_id or source_kitchen_id_alt

        if user.get("role") not in ("ceo", "admin", "supply_manager"):
            user_branch = user.get("branch_id")
            if req_branch and req_branch != user_branch:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكنك استعراض طلبات توريد لفرع خارج نطاق صلاحياتك",
                )
            if req_dest and req_dest != user_branch:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكنك استعراض طلبات توريد متجهة لفرع آخر",
                )
            effective_branch = user_branch
        else:
            effective_branch = req_branch

        orders, meta = SupplyService.get_supply_orders(
            status=status_filter,
            branch_id=effective_branch,
            destination_branch_id=req_dest,
            source_kitchen_id=req_kitchen,
            search=search,
        )
        return ApiResponse(
            success=True,
            data=[o.model_dump() for o in orders],
            meta=meta,
            message=f"تم جلب {len(orders)} طلب توريد بنجاح",
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل جلب طلبات التوريد: {str(e)}",
        )


@router.post("", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
@router.post("/", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
@router.post("/create", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
def create_supply_order(
    payload: SupplyOrderCreate,
    request: Request,
):
    """
    إنشاء وحفظ طلب توريد جديد مع أصنافه في معاملة ذرية (ACID Transaction).
    يتطلب جلسة مصادقة سارية ويمنع انتحال الهوية وتجاوز نطاق الفرع.
    """
    user = _require_authenticated_user(request)
    allowed_roles = ("ceo", "branch_manager", "supply_manager", "kitchen_staff", "inventory_clerk", "admin")
    if user.get("role") not in allowed_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: إنشاء طلبات التوريد مقتصر على مسؤولي الفروع والتوريد والمطبخ المركزي",
        )
    if payload.created_by_user_id and payload.created_by_user_id != user["id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: محاولة انتحال هوية مستخدم آخر غير مسموح بها",
        )
    if user.get("role") != "ceo" and user.get("branch_id"):
        if payload.destination_branch_id != user["branch_id"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكنك إنشاء طلب توريد لفرع خارج نطاق صلاحياتك",
            )
    actor_id = user["id"]

    try:
        order = SupplyService.create_supply_order(payload, user_id=actor_id)
        return ApiResponse(
            success=True,
            data=order.model_dump(),
            message=f"تم إنشاء طلب التوريد رقم {order.orderNumber} بنجاح",
        )
    except ValueError as e:
        err_msg = str(e)
        if "غير موجود" in err_msg or "not found" in err_msg.lower():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=err_msg)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=err_msg)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل إنشاء طلب التوريد: {str(e)}",
        )


@router.get("/{order_id}", response_model=ApiResponse)
def get_supply_order_by_id(
    order_id: str,
    request: Request,
):
    """
    جلب تفاصيل طلب توريد محدد بكامل أصنافه وحركاته اللوجستية.
    مقيد بالفروع المرتبطة بالطلب أو الإدارة العامة لمنع BOLA.
    """
    user = _require_authenticated_user(request)

    try:
        order = SupplyService.get_supply_order_by_id(order_id)
        if user.get("role") not in ("ceo", "admin", "supply_manager"):
            user_branch = user.get("branch_id")
            if user_branch and user_branch not in (order.destinationBranchId, order.sourceKitchenId):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكنك الاطلاع على تفاصيل طلب توريد لا يخص فرعك",
                )
        return ApiResponse(
            success=True,
            data=order.model_dump(),
            message="تم جلب تفاصيل طلب التوريد بنجاح",
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
            detail=f"فشل جلب تفاصيل طلب التوريد: {str(e)}",
        )


@router.post("/{order_id}/execute", response_model=ApiResponse)
def execute_supply_order(
    order_id: str,
    request: Request,
    payload: Optional[ExecuteSupplyOrderRequest] = None,
):
    """
    تنفيذ وصرف شحنة طلب التوريد من المطبخ المركزي.
    يتم خصم الأرصدة وتسجيل حركات الصرف (Issue Movements) بنظام المعاملة الذرية.
    يتطلب جلسة مصادقة سارية ويمنع انتحال الهوية وتجاوز نطاق المطبخ.
    """
    user = _require_authenticated_user(request)
    allowed_roles = ("ceo", "branch_manager", "supply_manager", "kitchen_staff", "admin")
    if user.get("role") not in allowed_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: صرف وتنفيذ طلبات التوريد مقتصر على مسؤولي المطبخ المركزي والتوريد",
        )
    if payload and payload.executed_by_user_id and payload.executed_by_user_id != user["id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: محاولة انتحال هوية مستخدم آخر غير مسموح بها",
        )
    if user.get("role") != "ceo" and user.get("branch_id"):
        order = SupplyService.get_supply_order_by_id(order_id)
        if user["branch_id"] not in (order.sourceKitchenId, "br_04"):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكنك تنفيذ وصرف طلب توريد من مطبخ خارج نطاق صلاحياتك",
            )
    actor_id = user["id"]

    try:
        req_data = payload or ExecuteSupplyOrderRequest()
        order = SupplyService.execute_supply_order(order_id, req_data, user_id=actor_id)
        return ApiResponse(
            success=True,
            data=order.model_dump(),
            message=f"تم تنفيذ وصرف شحنة طلب التوريد رقم {order.orderNumber} بنجاح وتحديث أرصدة المطبخ",
        )
    except ValueError as e:
        err_msg = str(e)
        if "غير موجود" in err_msg:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=err_msg)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=err_msg)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل تنفيذ طلب التوريد: {str(e)}",
        )


@router.post("/{order_id}/receive", response_model=ApiResponse)
def receive_supply_order(
    order_id: str,
    request: Request,
    payload: Optional[ReceiveSupplyOrderRequest] = None,
):
    """
    تأكيد استلام شحنة طلب التوريد وإيداع الكميات في مخزن الفرع المستلم آلياً.
    يتم تحديث أرصدة الفرع وتسجيل حركات الإيداع (Receipt Movements) بنظام المعاملة الذرية.
    يتطلب جلسة مصادقة سارية ويمنع انتحال الهوية وتجاوز نطاق الفرع المستلم.
    """
    user = _require_authenticated_user(request)
    allowed_roles = ("ceo", "branch_manager", "supply_manager", "inventory_clerk", "admin")
    if user.get("role") not in allowed_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: استلام وتوريد الشحنات مقتصر على مديري الفروع ومسؤولي المخزون",
        )
    if payload and payload.received_by_user_id and payload.received_by_user_id != user["id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: محاولة انتحال هوية مستخدم آخر غير مسموح بها",
        )
    if user.get("role") != "ceo" and user.get("branch_id"):
        order = SupplyService.get_supply_order_by_id(order_id)
        if user["branch_id"] != order.destinationBranchId:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكنك استلام شحنة توريد متجهة لفرع آخر",
            )
    actor_id = user["id"]

    try:
        req_data = payload or ReceiveSupplyOrderRequest()
        order = SupplyService.receive_supply_order(order_id, req_data, user_id=actor_id)
        return ApiResponse(
            success=True,
            data=order.model_dump(),
            message=f"تم تأكيد استلام الشحنة وإيداع الأرصدة في مخزن الفرع بنجاح (طلب {order.orderNumber})",
        )
    except ValueError as e:
        err_msg = str(e)
        if "غير موجود" in err_msg:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=err_msg)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=err_msg)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل استلام طلب التوريد: {str(e)}",
        )


@router.post("/{order_id}/reject", response_model=ApiResponse)
def reject_supply_order(
    order_id: str,
    request: Request,
    reason: str = Query("رفض الطلب لعدم الجدوى أو عدم التوافر", description="سبب رفض الطلب"),
    user_id: Optional[str] = Query(None, description="معرف المستخدم الذي رفض الطلب"),
):
    """
    رفض طلب التوريد وتوثيق ذلك في سجل التدقيق.
    يتطلب جلسة مصادقة سارية ويمنع انتحال الهوية وتجاوز نطاق الفرع.
    """
    user = _require_authenticated_user(request)
    allowed_roles = ("ceo", "branch_manager", "supply_manager", "kitchen_staff", "admin")
    if user.get("role") not in allowed_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: رفض طلبات التوريد مقتصر على مسؤولي الفروع والمطبخ المركزي",
        )
    if user_id and user_id != user["id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: محاولة انتحال هوية مستخدم آخر غير مسموح بها",
        )
    if user.get("role") != "ceo" and user.get("branch_id"):
        order = SupplyService.get_supply_order_by_id(order_id)
        if user["branch_id"] not in (order.destinationBranchId, order.sourceKitchenId, "br_04"):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكنك رفض طلب توريد لا يخص فرعك أو مطبخك",
            )
    actor_id = user["id"]

    try:
        order = SupplyService.reject_supply_order(order_id, reason=reason, user_id=actor_id)
        return ApiResponse(
            success=True,
            data=order.model_dump(),
            message=f"تم رفض طلب التوريد رقم {order.orderNumber}",
        )
    except ValueError as e:
        err_msg = str(e)
        if "غير موجود" in err_msg:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=err_msg)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=err_msg)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل رفض طلب التوريد: {str(e)}",
        )
