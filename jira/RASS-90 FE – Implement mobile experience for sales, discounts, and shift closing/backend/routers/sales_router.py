"""
Sales Router - Endpoints for RMS Sales Dashboard, Shift Management,
Sales Channels (Restaurant & Delivery), and Discounts.
Enforces authenticated RBAC via existing AuthService helper, rejects spoof actors,
guarantees zero-data precision, and eliminates fake success.
"""

import math
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, HTTPException, status, Query, Path, Request, Depends
from ..database.connection import get_db
from ..schemas.sales_schemas import (
    ApiResponse,
    OpenShiftRequest,
    ShiftEntryRequest,
    CloseShiftRequest,
    DiscountCreateRequest,
    DiscountCancelRequest,
    SalesDashboardResponse,
    RestaurantSalesResponse,
    DeliverySalesResponse,
    ShiftResponse,
    DiscountResponse,
)
from ..services.sales_service import SalesService

router = APIRouter(prefix="/sales", tags=["Sales & Shifts"])


CORPORATE_ROLES = {"ceo"}


def _get_authenticated_user(request: Request) -> Dict[str, Any]:
    """
    Extracts Bearer token or x-auth-token, validates session and active user in DB.
    Raises 401 UNAUTHORIZED if token is missing, invalid, or session is revoked.
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
            detail="رمز المصادقة مطلوب للوصول إلى بيانات المبيعات (Bearer token required)",
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
            detail=f"رمز المصادقة غير صالح أو منتهي الصلاحية: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


def _enforce_role_branch_scope(
    request: Request,
    branch_id: Optional[str] = None,
) -> Optional[str]:
    """
    Enforces cross-branch tenant isolation for read-only GET queries:
    - Strictly requires an active, verified authenticated session (401 if missing/revoked).
    - If authenticated as CEO (global privilege): allows querying any branch or aggregate.
    - If authenticated as branch-scoped user (e.g. branch_manager, shift_lead, cashier):
      * If explicit branch_id / branchId is requested and differs from assigned branch: raises 403 Forbidden.
      * If no branch_id is specified: restricts query to the user's assigned branch from session/DB.
    """
    current_user = _get_authenticated_user(request)
    role = current_user.get("role", "")
    user_branch = current_user.get("branch_id")

    req_branch = branch_id or request.query_params.get("branchId") or request.query_params.get("branch_id")

    if role in CORPORATE_ROLES:
        return req_branch

    if not user_branch:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="المستخدم الحالي غير مرتبط بفرع محدد",
        )

    if req_branch and req_branch != user_branch:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: لا يمكن استعراض مبيعات وبيانات فرع آخر دون صلاحيات إدارية (Cross-Branch Scope Rejected)",
        )

    return user_branch


# ---------------------------------------------------------------------------
# Dashboard Endpoints (Idempotent, Read-Only, No Mutation)
# ---------------------------------------------------------------------------

@router.get("/dashboard", response_model=ApiResponse)
def get_sales_dashboard(
    request: Request,
    branch_id: Optional[str] = Query(None, alias="branchId", description="Branch ID filter"),
    shift_id: Optional[str] = Query(None, alias="shiftId", description="Shift ID filter"),
):
    """
    GET /api/v1/sales/dashboard
    ملخص مبيعات الصالة والتوصيل ومؤشرات الأداء والقنوات والوردية النشطة.
    خالٍ من التعديل الجانبي، ويعيد 0.0 بدقة ودون اختلاق عند انعدام المبيعات.
    """
    scoped_branch_id = _enforce_role_branch_scope(request, branch_id)
    try:
        data = SalesService.get_dashboard(branch_id=scoped_branch_id, shift_id=shift_id)
        return ApiResponse(
            success=True,
            data=data.model_dump(by_alias=True),
            message="تم جلب لوحة المبيعات بنجاح",
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"فشل جلب لوحة المبيعات: {str(e)}",
        )


# ---------------------------------------------------------------------------
# Channel Sales Endpoints (Restaurant & Delivery)
# ---------------------------------------------------------------------------

@router.get("/restaurant", response_model=ApiResponse)
def get_restaurant_sales(
    request: Request,
    branch_id: Optional[str] = Query(None, alias="branchId"),
    shift_id: Optional[str] = Query(None, alias="shiftId"),
    category: Optional[str] = Query("الكل"),
    query: Optional[str] = Query(None),
):
    """
    GET /api/v1/sales/restaurant
    استعراض مبيعات المطعم (الصالة والسفري) وتفصيل الأصناف المباعة وقوائم الفئات.
    """
    scoped_branch_id = _enforce_role_branch_scope(request, branch_id)
    try:
        data = SalesService.get_restaurant_sales(
            branch_id=scoped_branch_id,
            shift_id=shift_id,
            category=category,
            query=query,
        )
        return ApiResponse(
            success=True,
            data=data.model_dump(by_alias=True),
            message="تم جلب مبيعات المطعم بنجاح",
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"فشل جلب مبيعات المطعم: {str(e)}",
        )


@router.get("/delivery", response_model=ApiResponse)
def get_delivery_sales(
    request: Request,
    branch_id: Optional[str] = Query(None, alias="branchId"),
    shift_id: Optional[str] = Query(None, alias="shiftId"),
    channel: Optional[str] = Query("الكل"),
):
    """
    GET /api/v1/sales/delivery
    استعراض مبيعات منصات التوصيل والتوصيل المباشر ومطابقة العمولات والتحصيل.
    يعيد 0.0 بدون اختلاق أرقام افتراضية.
    """
    scoped_branch_id = _enforce_role_branch_scope(request, branch_id)
    try:
        data = SalesService.get_delivery_sales(
            branch_id=scoped_branch_id,
            shift_id=shift_id,
            channel=channel,
        )
        return ApiResponse(
            success=True,
            data=data.model_dump(by_alias=True),
            message="تم جلب مبيعات التوصيل بنجاح",
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"فشل جلب مبيعات التوصيل: {str(e)}",
        )


# ---------------------------------------------------------------------------
# Shift Management Endpoints (Authenticated RBAC & Concurrency Protected)
# ---------------------------------------------------------------------------

@router.post("/shift/open", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
@router.post("/shifts/open", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
def open_shift(payload: OpenShiftRequest, request: Request):
    """
    POST /api/v1/sales/shift/open (أو /api/v1/sales/shifts/open)
    فتح وردية جديدة وتوثيق الرصيد الافتتاحي في جدول shifts وسجل التدقيق.
    يتطلب توثيق RBAC ويرفض انتحال هوية الكاشير (Reject Spoofed Actor).
    """
    current_user = _get_authenticated_user(request)
    role = current_user.get("role", "")

    # Role validation
    if role not in ("cashier", "shift_lead", "branch_manager", "ceo"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: فتح الوردية مقتصر على الكاشيرات والمشرفين ومديري الفروع",
        )

    # Spoof actor rejection: Cashier cannot open shift on behalf of another cashier
    if role == "cashier" and payload.cashier_user_id != current_user.get("id"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: لا يمكن فتح وردية باسم كاشير آخر دون صلاحيات إشرافية (Reject Spoofed Actor)",
        )

    # Cross-branch tenant isolation: Non-CEO users can only open shifts for their assigned branch
    if role != "ceo":
        user_branch = current_user.get("branch_id")
        if user_branch and payload.branch_id != user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكن فتح وردية في فرع غير الفرع المعين لك (Cross-Branch Scope Rejected)",
            )

    try:
        shift = SalesService.open_shift(
            branch_id=payload.branch_id,
            cashier_user_id=payload.cashier_user_id,
            opening_cash=payload.opening_cash,
            supervisor_user_id=payload.supervisor_user_id or (current_user.get("id") if role in ("shift_lead", "branch_manager", "ceo") else None),
            start_time=payload.start_time,
            notes=payload.notes,
            actor_user_id=current_user.get("id"),
        )
        return ApiResponse(
            success=True,
            data=shift.model_dump(by_alias=True),
            message="تم فتح الوردية وتوثيق الرصيد الافتتاحي بنجاح",
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل فتح الوردية: {str(e)}",
        )


@router.post("/shift/entry", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
@router.post("/shifts/entry", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
@router.post("/shifts/{shift_id}/entries", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
def record_shift_entry(
    payload: ShiftEntryRequest,
    request: Request,
    shift_id: Optional[str] = None,
):
    """
    POST /api/v1/sales/shift/entry (أو /api/v1/sales/shifts/entry)
    تسجيل مبيعات الوردية وتحديث إجمالي المبيعات والقنوات آلياً.
    محمي بـ Bearer Token ودقة نقدية بالـ Decimal.
    """
    current_user = _get_authenticated_user(request)
    role = current_user.get("role", "")
    if role not in ("cashier", "shift_lead", "branch_manager", "ceo"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: تسجيل حركات المبيعات يتطلب صلاحيات تشغيلية",
        )

    # Cross-branch tenant isolation
    if role != "ceo":
        user_branch = current_user.get("branch_id")
        if payload.branch_id and user_branch and payload.branch_id != user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: تسجيل حركات المبيعات مقتصر على فرعك المعين فقط (Cross-Branch Scope Rejected)",
            )
        target_shift_check = shift_id or payload.shift_id
        if target_shift_check:
            with get_db() as conn:
                s_row = conn.execute("SELECT branch_id FROM shifts WHERE id = ?", (target_shift_check,)).fetchone()
                if s_row and user_branch and s_row["branch_id"] != user_branch:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="غير مصرح: لا يمكن تسجيل مبيعات على وردية تابعة لفرع آخر (Cross-Branch Scope Rejected)",
                    )

    try:
        target_shift = shift_id or payload.shift_id
        entry = SalesService.record_shift_entry(
            shift_id=target_shift,
            channel=payload.channel,
            gross_amount=payload.gross_amount,
            discount_amount=payload.discount_amount,
            net_amount=payload.net_amount,
            payment_method=payload.payment_method,
            order_count=payload.order_count,
            branch_id=payload.branch_id,
            items=payload.items,
            actor_user_id=current_user.get("id"),
        )
        return ApiResponse(
            success=True,
            data=entry,
            message="تم تسجيل مبيعات الوردية بنجاح",
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل تسجيل حركة المبيعات: {str(e)}",
        )


@router.post("/shift/close", response_model=ApiResponse)
@router.post("/shifts/close", response_model=ApiResponse)
@router.post("/shifts/{shift_id}/close", response_model=ApiResponse)
def close_shift(
    payload: CloseShiftRequest,
    request: Request,
    shift_id: Optional[str] = None,
):
    """
    POST /api/v1/sales/shift/close (أو /api/v1/sales/shifts/close)
    إغلاق الوردية وحساب العجز أو الزيادة ومطابقة النقد الفعلي والنظامي.
    يرفض إعادة الإغلاق للورديات المغلقة، ويتطلب إدخال نقد فعلي حقيقي (BLOCKED_UI).
    """
    current_user = _get_authenticated_user(request)
    role = current_user.get("role", "")
    if role not in ("cashier", "shift_lead", "branch_manager", "ceo"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: إغلاق الوردية يتطلب صلاحيات تشغيلية أو إشرافية",
        )

    if payload.closing_cash_actual is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="BLOCKED_UI: لا يمكن إغلاق الوردية دون إدخال النقد الفعلي المحصي في الدرج",
        )

    # Validate finite and non-negative
    try:
        cash_val = float(payload.closing_cash_actual)
    except (TypeError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="النقد الفعلي بالدرج غير صالح",
        )
    if not math.isfinite(cash_val) or cash_val < 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="النقد الفعلي بالدرج يجب أن يكون رقماً حقيقياً غير سالب (>= 0)",
        )

    user_branch = current_user.get("branch_id")
    target_shift = shift_id or payload.shift_id

    # Cross-branch tenant isolation & actor checks from SQL
    if target_shift:
        with get_db() as conn:
            s_row = conn.execute(
                "SELECT branch_id, cashier_user_id, status FROM shifts WHERE id = ?",
                (target_shift,),
            ).fetchone()
            if not s_row:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"الوردية رقم {target_shift} غير موجودة",
                )
            if role != "ceo":
                if not user_branch or s_row["branch_id"] != user_branch:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="غير مصرح: لا يمكن إغلاق وردية تابعة لفرع آخر (Cross-Branch Scope Rejected)",
                    )
            if role == "cashier" and s_row["cashier_user_id"] != current_user.get("id"):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكن للكاشير إغلاق وردية كاشير آخر (Reject Spoofed Actor)",
                )
    else:
        if role != "ceo":
            if not user_branch:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: المستخدم ليس لديه فرع معين",
                )
            if payload.branch_id and payload.branch_id != user_branch:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكن إغلاق وردية في فرع غير الفرع المعين لك (Cross-Branch Scope Rejected)",
                )
            if not payload.branch_id:
                payload.branch_id = user_branch

    try:
        closed_shift = SalesService.close_shift(
            shift_id=target_shift,
            closing_cash_actual=cash_val,
            branch_id=payload.branch_id or (user_branch if role != "ceo" else None),
            supervisor_user_id=current_user.get("id") if role in ("shift_lead", "branch_manager", "ceo") else payload.supervisor_user_id,
            notes=payload.notes,
            actor_user_id=current_user.get("id"),
        )
        return ApiResponse(
            success=True,
            data=closed_shift.model_dump(by_alias=True),
            message="تم اعتماد إغلاق الوردية ومطابقة العجز/الزيادة بنجاح",
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل إغلاق الوردية: {str(e)}",
        )


@router.get("/shift/review", response_model=ApiResponse)
@router.get("/shifts/review", response_model=ApiResponse)
def get_shift_review(
    request: Request,
    shift_id: Optional[str] = Query(None, alias="shiftId"),
):
    """
    GET /api/v1/sales/shift/review
    معاينة وتدقيق حسابات الوردية قبل الإغلاق النهائي.
    """
    user = _get_authenticated_user(request)
    req_shift = shift_id or request.query_params.get("shiftId") or request.query_params.get("shift_id")
    try:
        review_data = SalesService.get_shift_review(shift_id=req_shift)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
    if user.get("role") not in CORPORATE_ROLES:
        user_branch = user.get("branch_id")
        shift_branch = review_data.get("branch_id") or review_data.get("branchId")
        if shift_branch and user_branch and shift_branch != user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكن استعراض مراجعة وردية تابعة لفرع آخر",
            )
    return ApiResponse(
        success=True,
        data=review_data,
        message="تم جلب بيانات مراجعة الوردية بنجاح",
    )


@router.get("/shift/closed", response_model=ApiResponse)
@router.get("/shifts/closed", response_model=ApiResponse)
def get_closed_shift_summary(
    request: Request,
    shift_id: Optional[str] = Query(None, alias="shiftId"),
):
    """
    GET /api/v1/sales/shift/closed
    ملخص الوردية المغلقة المعتمدة مالياً ورقابياً.
    """
    user = _get_authenticated_user(request)
    req_shift = shift_id or request.query_params.get("shiftId") or request.query_params.get("shift_id")
    try:
        review_data = SalesService.get_shift_review(shift_id=req_shift)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
    if user.get("role") not in CORPORATE_ROLES:
        user_branch = user.get("branch_id")
        shift_branch = review_data.get("branch_id") or review_data.get("branchId")
        if shift_branch and user_branch and shift_branch != user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: لا يمكن استعراض ملخص وردية مغلقة تابعة لفرع آخر",
            )
    return ApiResponse(
        success=True,
        data=review_data,
        message="تم جلب ملخص الوردية المغلقة بنجاح",
    )


# ---------------------------------------------------------------------------
# Discounts Endpoints (Authenticated RBAC & Reconciliation)
# ---------------------------------------------------------------------------

@router.get("/discounts", response_model=ApiResponse)
def get_discounts(
    request: Request,
    shift_id: Optional[str] = Query(None, alias="shiftId"),
    branch_id: Optional[str] = Query(None, alias="branchId"),
    status_filter: Optional[str] = Query(None, alias="status"),
):
    """
    GET /api/v1/sales/discounts
    استعراض سجل الخصومات الحقيقي مع تفاصيل الفاتورة والموافقة الإدارية.
    """
    scoped_branch_id = _enforce_role_branch_scope(request, branch_id)
    try:
        discounts = SalesService.get_discounts(
            shift_id=shift_id,
            branch_id=scoped_branch_id,
            status=status_filter,
        )
        return ApiResponse(
            success=True,
            data=[d.model_dump(by_alias=True) for d in discounts],
            message=f"تم جلب {len(discounts)} خصومات بنجاح",
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"فشل جلب سجل الخصومات: {str(e)}",
        )


@router.post("/discounts", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
def create_discount(payload: DiscountCreateRequest, request: Request):
    """
    POST /api/v1/sales/discounts
    تسجيل خصم معتمد جديد على الوردية.
    مقتصر على مديري الفروع والمدير التنفيذي والمشرفين (RBAC Guarded).
    ويرفض انتحال هوية المشرف المعتمد للخصم.
    """
    current_user = _get_authenticated_user(request)
    role = current_user.get("role", "")
    if role not in ("shift_lead", "branch_manager", "ceo"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: تسجيل الخصومات مقتصر على المشرفين ومديري الفروع والمدير التنفيذي",
        )

    # Spoof check
    if payload.authorized_by_user_id and payload.authorized_by_user_id != current_user.get("id") and role not in ("branch_manager", "ceo"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: محاولة انتحال هوية المشرف المعتمد للخصم (Spoofed Actor Rejected)",
        )

    user_branch = current_user.get("branch_id")
    if role != "ceo":
        if not user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: المستخدم ليس لديه فرع معين",
            )
        if payload.shift_id:
            with get_db() as conn:
                s_row = conn.execute("SELECT branch_id FROM shifts WHERE id = ?", (payload.shift_id,)).fetchone()
                if not s_row:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail=f"الوردية رقم {payload.shift_id} غير موجودة",
                    )
                if s_row["branch_id"] != user_branch:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="غير مصرح: لا يمكن تسجيل خصم على وردية تابعة لفرع آخر (Cross-Branch Scope Rejected)",
                    )

    try:
        discount = SalesService.create_discount(
            shift_id=payload.shift_id,
            discount_code=payload.discount_code,
            type=payload.type,
            amount=payload.amount,
            reason=payload.reason,
            authorized_by_user_id=current_user.get("id"),
            actor_user_id=current_user.get("id"),
            branch_id=user_branch if role != "ceo" else None,
        )
        return ApiResponse(
            success=True,
            data=discount.model_dump(by_alias=True),
            message="تم تسجيل الخصم وتحديث المبيعات بنجاح",
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"فشل تسجيل الخصم: {str(e)}",
        )


@router.post("/discounts/{id}/cancel", response_model=ApiResponse)
def cancel_discount(
    request: Request,
    id: str = Path(..., description="Discount ID or invoice reference"),
    payload: Optional[DiscountCancelRequest] = None,
):
    """
    POST /api/v1/sales/discounts/{id}/cancel
    إلغاء خصم ممنوح، رد قيمته لحسابات الوردية، وتوثيق سبب الإلغاء في audit_logs.
    مقتصر على مديري الفروع والمدير التنفيذي، ويرفض الإلغاء المزدوج.
    """
    current_user = _get_authenticated_user(request)
    role = current_user.get("role", "")
    if role not in ("branch_manager", "ceo"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح: إلغاء الخصومات يتطلب صلاحيات مدير الفرع أو المدير التنفيذي",
        )

    user_branch = current_user.get("branch_id")
    if role != "ceo":
        if not user_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: المستخدم ليس لديه فرع معين",
            )
        with get_db() as conn:
            d_row = conn.execute(
                """
                SELECT d.id, d.status, s.branch_id
                FROM discounts d
                LEFT JOIN shifts s ON d.shift_id = s.id
                WHERE d.id = ?
                """,
                (id,),
            ).fetchone()
            if not d_row:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"الخصم رقم {id} غير موجود",
                )
            if d_row["branch_id"] and d_row["branch_id"] != user_branch:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكن إلغاء خصم مسجل على فرع آخر (Cross-Branch Scope Rejected)",
                )

    try:
        reason = payload.reason if payload else "سوء استخدام صلاحية"
        note = payload.note if payload else None

        updated = SalesService.cancel_discount(
            discount_id=id,
            reason=reason,
            cancelled_by_user_id=current_user.get("id"),
            note=note,
            actor_user_id=current_user.get("id"),
        )
        return ApiResponse(
            success=True,
            data=updated.model_dump(by_alias=True),
            message="تم إلغاء الخصم وتوثيق التدقيق بنجاح",
        )
    except ValueError as e:
        err_msg = str(e)
        status_code = status.HTTP_404_NOT_FOUND if "غير موجود" in err_msg else status.HTTP_400_BAD_REQUEST
        raise HTTPException(
            status_code=status_code,
            detail=err_msg,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل إلغاء الخصم: {str(e)}",
        )
