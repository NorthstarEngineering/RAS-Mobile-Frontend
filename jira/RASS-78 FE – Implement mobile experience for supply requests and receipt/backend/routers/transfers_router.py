from __future__ import annotations
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, HTTPException, Query, Request, status

from ..schemas.transfers_schemas import (
    ApiResponse,
    TransferCreateRequest,
    TransferReviewRequest,
    TransferSendRequest,
    TransferReceiveRequest,
    TransferResponse,
    TransferMetricsResponse,
)
from ..services.transfers_service import TransfersService

router = APIRouter(prefix="/transfers", tags=["Inter-branch Transfers"])


def _serialize_transfer(t: TransferResponse) -> dict:
    camel = t.model_dump()
    alias = t.model_dump(by_alias=True)
    res = {**alias, **camel}
    res["items"] = [{**i.model_dump(by_alias=True), **i.model_dump()} for i in t.items]
    return res


def _serialize_metrics(m: TransferMetricsResponse) -> dict:
    return {**m.model_dump(by_alias=True), **m.model_dump()}


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
    Extract authenticated user session using existing AuthService helper.
    Mandatory verified session: missing/invalid/revoked token raises HTTP 401.
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
def get_transfers(
    request: Request,
    status_filter: Optional[str] = Query(None, alias="status", description="حالة التحويل"),
    source_branch_id: Optional[str] = Query(None, alias="sourceBranchId"),
    destination_branch_id: Optional[str] = Query(None, alias="destinationBranchId"),
    branch_id: Optional[str] = Query(None, alias="branchId", description="الفرع (مصدر أو وجهة)"),
    branch_id_alt: Optional[str] = Query(None, alias="branch_id"),
    search: Optional[str] = Query(None, description="بحث برقم التحويل أو الصنف أو السائق"),
    query_alt: Optional[str] = Query(None, alias="q"),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
):
    """
    استعراض قائمة أذونات التحويل بين الفروع مع التحقق من الهوية ونطاق الفرع.
    """
    user = _require_authenticated_user(request)
    try:
        effective_search = search or query_alt
        requested_branch = branch_id or branch_id_alt
        if user.get("role") != "ceo":
            user_branch = user.get("branch_id")
            if requested_branch:
                resolved_req = TransfersService._resolve_branch_id_safe(requested_branch)
                if resolved_req != user_branch:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="غير مصرح: لا يمكنك استعراض تحويلات فرع خارج نطاق صلاحياتك",
                    )
            if source_branch_id:
                resolved_src = TransfersService._resolve_branch_id_safe(source_branch_id)
                resolved_dest = TransfersService._resolve_branch_id_safe(destination_branch_id) if destination_branch_id else None
                if resolved_src != user_branch and resolved_dest != user_branch:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="غير مصرح: لا يمكنك استعراض تحويلات لا تخص فرعك",
                    )
            effective_branch = user_branch
        else:
            effective_branch = requested_branch

        transfers = TransfersService.get_transfers(
            status=status_filter,
            source_branch_id=source_branch_id,
            destination_branch_id=destination_branch_id,
            branch_id=effective_branch,
            search=effective_search,
            limit=limit,
            offset=offset,
        )
        return ApiResponse(
            success=True,
            data=[_serialize_transfer(t) for t in transfers],
            message=f"تم جلب {len(transfers)} إذن تحويل بنجاح",
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل جلب أذونات التحويل: {str(e)}",
        )


@router.get("/metrics", response_model=ApiResponse)
def get_transfers_metrics(
    request: Request,
    branch_id: Optional[str] = Query(None, alias="branchId"),
    branch_id_alt: Optional[str] = Query(None, alias="branch_id"),
):
    """
    إحصائيات ومؤشرات لوحة التحويلات اللحظية (واردة للمراجعة، صادرة بالطريق، مكتمل).
    """
    user = _require_authenticated_user(request)
    try:
        requested_branch = branch_id or branch_id_alt
        if user.get("role") != "ceo":
            user_branch = user.get("branch_id")
            if requested_branch:
                resolved_req = TransfersService._resolve_branch_id_safe(requested_branch)
                if resolved_req != user_branch:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="غير مصرح: لا يمكنك استعراض مؤشرات فرع خارج نطاق صلاحياتك",
                    )
            effective_branch = user_branch
        else:
            effective_branch = requested_branch

        metrics = TransfersService.get_transfer_metrics(branch_id=effective_branch)
        return ApiResponse(
            success=True,
            data=_serialize_metrics(metrics),
            message="تم جلب مؤشرات التحويلات بنجاح",
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل جلب مؤشرات التحويلات: {str(e)}",
        )


@router.get("/history", response_model=ApiResponse)
def get_transfers_history(
    request: Request,
    branch_id: Optional[str] = Query(None, alias="branchId"),
    branch_id_alt: Optional[str] = Query(None, alias="branch_id"),
    search: Optional[str] = Query(None),
    query_alt: Optional[str] = Query(None, alias="q"),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
):
    """
    سجل التحويلات التاريخي والعمليات المنجزة (TR-06).
    """
    user = _require_authenticated_user(request)
    try:
        requested_branch = branch_id or branch_id_alt
        effective_search = search or query_alt
        if user.get("role") != "ceo":
            user_branch = user.get("branch_id")
            if requested_branch:
                resolved_req = TransfersService._resolve_branch_id_safe(requested_branch)
                if resolved_req != user_branch:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="غير مصرح: لا يمكنك استعراض سجل فرع خارج نطاق صلاحياتك",
                    )
            effective_branch = user_branch
        else:
            effective_branch = requested_branch

        transfers = TransfersService.get_transfers(
            branch_id=effective_branch,
            search=effective_search,
            limit=limit,
            offset=offset,
        )
        return ApiResponse(
            success=True,
            data=[_serialize_transfer(t) for t in transfers],
            message=f"تم جلب سجل التحويلات ({len(transfers)} حركة)",
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل جلب سجل التحويلات: {str(e)}",
        )


@router.get("/branches", response_model=ApiResponse)
def get_operational_branches(request: Request):
    """
    جلب قائمة الفروع التشغيلية النشطة ديناميكياً من قاعدة البيانات.
    """
    _require_authenticated_user(request)
    try:
        branches = TransfersService.get_branches()
        return ApiResponse(
            success=True,
            data=branches,
            message="تم جلب قائمة الفروع بنجاح",
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل جلب الفروع: {str(e)}",
        )


@router.get("/items", response_model=ApiResponse)
def get_available_branch_items(
    request: Request,
    branch_id: str = Query(..., alias="branchId", description="معرف الفرع لجلب أرصدته المتاحة للتحويل"),
    branch_id_alt: Optional[str] = Query(None, alias="branch_id"),
):
    """
    جلب الأصناف المتاحة للتحويل في الفرع المحدد مع الأرصدة الحقيقية من SQLite.
    """
    user = _require_authenticated_user(request)
    try:
        effective_branch = branch_id or branch_id_alt
        if user.get("role") != "ceo":
            user_branch = user.get("branch_id")
            resolved_user = TransfersService._resolve_branch_id_safe(user_branch) if user_branch else None
            resolved_req = TransfersService._resolve_branch_id_safe(effective_branch)
            if resolved_req != resolved_user:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكنك استعراض أرصدة مخزون فرع خارج نطاق صلاحياتك",
                )

        items = TransfersService.get_available_items(branch_id=effective_branch)
        return ApiResponse(
            success=True,
            data=items,
            message=f"تم جلب {len(items)} صنف متاح للتحويل بنجاح",
        )
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل جلب أصناف الفرع: {str(e)}",
        )


@router.post("", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
def create_transfer(payload: TransferCreateRequest, request: Request):
    """
    إنشاء إذن تحويل جديد بين فرعين والتحقق من أرصدة المخزون المصدر.
    يتحقق من هوية المنشئ ونطاق الفرع ومنع انتحال الهوية وجلسة المصادقة الإلزامية.
    """
    try:
        user = _require_authenticated_user(request)
        if user.get("role") in ("cashier",):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: ليس لديك صلاحية إنشاء طلبات التحويل بين الفروع",
            )
        if payload.created_by_user_id and payload.created_by_user_id != user["id"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: محاولة انتحال هوية مستخدم آخر غير مسموح بها",
            )
        creator_id = user["id"]

        if user.get("role") != "ceo" and user.get("branch_id"):
            resolved_src = TransfersService._resolve_branch_id_safe(payload.source_branch_id)
            if resolved_src != user["branch_id"]:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكنك إنشاء تحويل من فرع خارج نطاق صلاحياتك",
                )

        transfer = TransfersService.create_transfer(
            source_branch_id=payload.source_branch_id,
            destination_branch_id=payload.destination_branch_id,
            items=payload.items,
            transfer_code=payload.transfer_code,
            notes=payload.notes,
            is_urgent=payload.is_urgent or False,
            created_by_user_id=creator_id,
        )
        return ApiResponse(
            success=True,
            data=_serialize_transfer(transfer),
            message=f"تم إنشاء طلب التحويل {transfer.transferCode} بنجاح",
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
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل إنشاء طلب التحويل: {str(e)}",
        )


@router.get("/{transfer_id}", response_model=ApiResponse)
def get_transfer_by_id(transfer_id: str, request: Request):
    """
    جلب تفاصيل إذن التحويل بالمعرف الأساسي أو كود التحويل (مثل TR-5540).
    مقيد بالفروع المرتبطة بالتحويل (المصدر أو المستلم) أو CEO لمنع BOLA.
    """
    user = _require_authenticated_user(request)
    try:
        transfer = TransfersService.get_transfer_by_id(transfer_id)
        if user.get("role") != "ceo":
            user_branch = user.get("branch_id")
            if user_branch and user_branch not in (transfer.sourceBranchId, transfer.destinationBranchId):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكنك الاطلاع على تفاصيل تحويل لا يخص فرعك",
                )
        return ApiResponse(
            success=True,
            data=_serialize_transfer(transfer),
            message="تم جلب تفاصيل التحويل بنجاح",
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
            detail=f"فشل جلب إذن التحويل: {str(e)}",
        )


@router.post("/{transfer_id}/review", response_model=ApiResponse)
def review_transfer(transfer_id: str, payload: TransferReviewRequest, request: Request):
    """
    مراجعة إذن التحويل واعتماده أو رفضه مع إمكانية تعديل الكميات المعتمدة (TR-03).
    يتحقق من نطاق الفرع وصلاحيات الاعتماد وجلسة المصادقة الإلزامية.
    """
    try:
        user = _require_authenticated_user(request)
        if user.get("role") in ("cashier",):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: ليس لديك صلاحية مراجعة أو اعتماد التحويلات",
            )
        if payload.reviewed_by_user_id and payload.reviewed_by_user_id != user["id"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: محاولة انتحال هوية مستخدم آخر غير مسموح بها",
            )
        reviewer_id = user["id"]

        if user.get("role") != "ceo" and user.get("branch_id"):
            existing = TransfersService.get_transfer_by_id(transfer_id)
            if user["branch_id"] not in (existing.sourceBranchId, existing.destinationBranchId):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكنك مراجعة تحويل لا يخص فرعك",
                )

        transfer = TransfersService.review_transfer(
            transfer_id=transfer_id,
            approved=payload.approved,
            decision=payload.decision,
            notes=payload.notes,
            reviewed_by_user_id=reviewer_id,
            approved_quantities=payload.approved_quantities,
        )
        state_msg = "اعتماد" if payload.approved else "رفض"
        return ApiResponse(
            success=True,
            data=_serialize_transfer(transfer),
            message=f"تم {state_msg} إذن التحويل {transfer.transferCode} بنجاح",
        )
    except HTTPException:
        raise
    except ValueError as e:
        status_code = status.HTTP_404_NOT_FOUND if "غير موجود" in str(e) else status.HTTP_400_BAD_REQUEST
        raise HTTPException(status_code=status_code, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل مراجعة إذن التحويل: {str(e)}",
        )


@router.post("/{transfer_id}/send", response_model=ApiResponse)
def send_transfer(transfer_id: str, payload: TransferSendRequest, request: Request):
    """
    تسجيل شحن التحويل وتفاصيل السائق مع خصم فوري وذري (ACID) من مخزون الفرع المصدر (TR-04).
    يتطلب حالة معتمدة مسبقاً (approved) ويمنع الشحن المباشر من pending_review.
    يتطلب جلسة مصادقة سارية ويتحقق من نطاق الفرع.
    """
    try:
        user = _require_authenticated_user(request)
        if user.get("role") in ("cashier",):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: ليس لديك صلاحية شحن التحويلات",
            )
        if payload.sent_by_user_id and payload.sent_by_user_id != user["id"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: محاولة انتحال هوية مستخدم آخر غير مسموح بها",
            )
        sender_id = user["id"]

        if user.get("role") != "ceo" and user.get("branch_id"):
            existing = TransfersService.get_transfer_by_id(transfer_id)
            if existing.sourceBranchId != user["branch_id"]:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكنك شحن تحويل مصدره فرع آخر",
                )

        transfer = TransfersService.send_transfer(
            transfer_id=transfer_id,
            driver_name=payload.driver_name,
            driver_phone=payload.driver_phone,
            departure_time=payload.departure_time,
            vehicle=payload.vehicle,
            notes=payload.notes,
            sent_by_user_id=sender_id,
            temperature=payload.temperature,
        )
        return ApiResponse(
            success=True,
            data=_serialize_transfer(transfer),
            message=f"تم تأكيد إرسال الشحنة {transfer.transferCode} وخصم المخزون بنجاح",
        )
    except HTTPException:
        raise
    except ValueError as e:
        status_code = status.HTTP_404_NOT_FOUND if "غير موجود" in str(e) else status.HTTP_400_BAD_REQUEST
        raise HTTPException(status_code=status_code, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل إرسال الشحنة: {str(e)}",
        )


@router.post("/{transfer_id}/receive", response_model=ApiResponse)
def receive_transfer(transfer_id: str, payload: TransferReceiveRequest, request: Request):
    """
    تأكيد استلام الشحنة وإيداع المخزون في الفرع المستلم ذرياً (ACID) وتوثيق التلف إن وجد (TR-05).
    يتطلب جلسة مصادقة سارية ويتحقق من نطاق الفرع.
    """
    try:
        user = _require_authenticated_user(request)
        if user.get("role") in ("cashier",):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: ليس لديك صلاحية استلام التحويلات",
            )
        if payload.received_by_user_id and payload.received_by_user_id != user["id"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="غير مصرح: محاولة انتحال هوية مستخدم آخر غير مسموح بها",
            )
        receiver_id = user["id"]

        if user.get("role") != "ceo" and user.get("branch_id"):
            existing = TransfersService.get_transfer_by_id(transfer_id)
            if existing.destinationBranchId != user["branch_id"]:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="غير مصرح: لا يمكنك استلام تحويل وجهته فرع آخر",
                )

        transfer = TransfersService.receive_transfer(
            transfer_id=transfer_id,
            received_by_user_id=receiver_id,
            arrival_time=payload.arrival_time,
            received_items=payload.received_items,
            has_damage=payload.has_damage or False,
            damage_notes=payload.damage_notes,
            notes=payload.notes,
        )
        return ApiResponse(
            success=True,
            data=_serialize_transfer(transfer),
            message=f"تم تأكيد استلام الشحنة {transfer.transferCode} وإيداع الأرصدة بنجاح",
        )
    except HTTPException:
        raise
    except ValueError as e:
        status_code = status.HTTP_404_NOT_FOUND if "غير موجود" in str(e) else status.HTTP_400_BAD_REQUEST
        raise HTTPException(status_code=status_code, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل تأكيد الاستلام: {str(e)}",
        )
