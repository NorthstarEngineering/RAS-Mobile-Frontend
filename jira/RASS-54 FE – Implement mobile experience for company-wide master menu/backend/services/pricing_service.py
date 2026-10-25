import json
import time
import math
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional, Dict, Any, Callable
from fastapi import HTTPException, status
from ..database.connection import get_db
from ..schemas.pricing_schemas import (
    PriceChangeRequestCreate,
    PriceChangeRequestApprove,
    PriceChangeRequestReject,
    PriceChangeRequestResponse,
    PriceHistoryResponse,
    ItemPricingSummaryResponse,
)

SEED_REQUEST_NUMBERS: Dict[str, str] = {
    "pcr_1": "PCR-2024-089",
    "pcr_2": "PCR-2024-088",
    "pcr_3": "PCR-2024-087",
    "pcr_4": "PCR-2024-086",
    "pcr_5": "PCR-2024-085",
    "pcr_01": "PCR-2024-089",
    "pcr_02": "PCR-2024-087",
}

DEFAULT_REQUESTS = [
    {
        "id": "pcr_1",
        "menu_item_id": "item_1",
        "requested_by_user_id": "usr_bm1",
        "current_price": 120.00,
        "proposed_price": 135.00,
        "reason": "ارتفاع أسعار توريد اللحوم البقرية الطازجة بنسبة 15% من المورد الرئيسي.",
        "status": "pending",
        "effective_date": "2024-05-01",
        "created_at": "2024-04-16 10:00:00",
    },
    {
        "id": "pcr_2",
        "menu_item_id": "item_2",
        "requested_by_user_id": "usr_bm1",
        "current_price": 145.00,
        "proposed_price": 165.00,
        "reason": "زيادة حجم القطع وتكلفة زيت القلي المعتمد.",
        "status": "pending",
        "effective_date": "2024-05-01",
        "created_at": "2024-04-14 11:30:00",
    },
    {
        "id": "pcr_3",
        "menu_item_id": "item_3",
        "requested_by_user_id": "usr_bm1",
        "current_price": 180.00,
        "proposed_price": 195.00,
        "reason": "تحديث تسعير فئة البريميوم بما يتناسب مع السوق.",
        "status": "approved",
        "effective_date": "2024-04-15",
        "reviewed_by_user_id": "usr_ceo",
        "review_notes": "معتمد ومطابق لسياسة التسعير",
        "created_at": "2024-04-10 09:15:00",
    },
    {
        "id": "pcr_4",
        "menu_item_id": "item_4",
        "requested_by_user_id": "usr_bm1",
        "current_price": 55.00,
        "proposed_price": 65.00,
        "reason": "إضافة صوص الرانش المزدوج للطبق.",
        "status": "approved",
        "effective_date": "2024-04-12",
        "reviewed_by_user_id": "usr_ceo",
        "review_notes": "معتمد",
        "created_at": "2024-04-08 14:00:00",
    },
    {
        "id": "pcr_5",
        "menu_item_id": "item_5",
        "requested_by_user_id": "usr_bm1",
        "current_price": 40.00,
        "proposed_price": 55.00,
        "reason": "الزيادة مبالغ فيها مقارنة بأسعار السوق للمشروبات الطبيعية.",
        "status": "rejected",
        "effective_date": None,
        "reviewed_by_user_id": "usr_ceo",
        "review_notes": "الزيادة مبالغ فيها مقارنة بأسعار السوق للمشروبات الطبيعية.",
        "created_at": "2024-04-05 16:45:00",
    },
]

DEFAULT_HISTORY = [
    {
        "id": "hist_1",
        "menu_item_id": "item_1",
        "old_price": 105.00,
        "new_price": 120.00,
        "effective_date": "2024-03-01 00:00:00",
        "approved_by_user_id": "usr_ceo",
        "reason": "تعديل التكلفة التشغيلية للربع الأول 2024",
        "created_at": "2024-03-01 00:00:00",
    },
    {
        "id": "hist_2",
        "menu_item_id": "item_1",
        "old_price": 95.00,
        "new_price": 105.00,
        "effective_date": "2023-11-01 00:00:00",
        "approved_by_user_id": "usr_ceo",
        "reason": "تحديث تسعير قائمة الشتاء السنوية",
        "created_at": "2023-11-01 00:00:00",
    },
    {
        "id": "hist_3",
        "menu_item_id": "item_1",
        "old_price": 85.00,
        "new_price": 95.00,
        "effective_date": "2023-06-01 00:00:00",
        "approved_by_user_id": "usr_ceo",
        "reason": "افتتاح الفروع الجديدة وتوحيد المنيو",
        "created_at": "2023-06-01 00:00:00",
    },
    {
        "id": "hist_4",
        "menu_item_id": "item_3",
        "old_price": 180.00,
        "new_price": 195.00,
        "effective_date": "2024-04-15 00:00:00",
        "approved_by_user_id": "usr_ceo",
        "reason": "تحديث تسعير فئة البريميوم بما يتناسب مع السوق.",
        "created_at": "2024-04-15 00:00:00",
    },
    {
        "id": "hist_5",
        "menu_item_id": "item_4",
        "old_price": 55.00,
        "new_price": 65.00,
        "effective_date": "2024-04-12 00:00:00",
        "approved_by_user_id": "usr_ceo",
        "reason": "إضافة صوص الرانش المزدوج للطبق.",
        "created_at": "2024-04-12 00:00:00",
    },
]

def _get_request_number(req_id: str, created_at: str) -> str:
    if req_id in SEED_REQUEST_NUMBERS:
        return SEED_REQUEST_NUMBERS[req_id]
    year = created_at[:4] if created_at and len(created_at) >= 4 else "2024"
    numeric_suffix = abs(hash(req_id)) % 900 + 100
    return f"PCR-{year}-{numeric_suffix:03d}"

def _row_to_request_response(row) -> PriceChangeRequestResponse:
    current_price = float(row["current_price"])
    proposed_price = float(row["proposed_price"])
    diff = proposed_price - current_price
    pct = round((diff / current_price) * 100, 2) if current_price > 0 else 0.0
    req_num = _get_request_number(row["id"], row["created_at"])

    keys = row.keys() if hasattr(row, "keys") else []
    approved_price = float(row["approved_price"]) if "approved_price" in keys and row["approved_price"] is not None else None

    return PriceChangeRequestResponse(
        id=row["id"],
        requestNumber=req_num,
        itemId=row["menu_item_id"],
        itemNameAr=row["item_name_ar"] or "صنف غير محدد",
        itemNameEn=row["item_name_en"] or "",
        itemSku=row["item_sku"] or "",
        categoryName=row["category_name"] or "عام",
        currentPrice=current_price,
        proposedPrice=proposed_price,
        cost=float(row["item_cost"]) if row["item_cost"] is not None else 0.0,
        branchName=row["branch_name"] or "الفرع الرئيسي - وسط البلد",
        requestedByName=row["requested_by_name"] or "م. ألفاريز",
        requestDate=row["created_at"] or datetime.now().isoformat(),
        status=row["status"],
        reason=row["reason"] or "",
        effectiveDate=row["effective_date"],
        difference=round(diff, 2),
        percentageChange=pct,
        approvedPrice=approved_price,
    )

def _row_to_history_response(row) -> PriceHistoryResponse:
    old_p = float(row["old_price"])
    new_p = float(row["new_price"])
    diff = new_p - old_p
    pct = round((diff / old_p) * 100, 2) if old_p > 0 else 0.0

    keys = row.keys() if hasattr(row, "keys") else []
    item_name_ar = row["item_name_ar"] if "item_name_ar" in keys else None
    item_name_en = row["item_name_en"] if "item_name_en" in keys else None
    item_sku = row["item_sku"] if "item_sku" in keys else None
    category_name = row["category_name"] if "category_name" in keys else None
    current_price = float(row["current_price"]) if "current_price" in keys and row["current_price"] is not None else None

    return PriceHistoryResponse(
        id=row["id"],
        itemId=row["menu_item_id"],
        oldPrice=old_p,
        newPrice=new_p,
        effectiveDate=row["effective_date"],
        approvedByName=row["approved_by_name"] or "المدير التنفيذي",
        reason=row["reason"] or "",
        difference=round(diff, 2),
        percentageChange=pct,
        itemNameAr=item_name_ar,
        itemNameEn=item_name_en,
        itemSku=item_sku,
        categoryName=category_name,
        currentPrice=current_price,
    )

class PricingService:
    @staticmethod
    def ensure_seed_data(conn) -> None:
        """Seed initial pricing requests and history if not present."""
        for req in DEFAULT_REQUESTS:
            app_p = req.get("approved_price") or (req["proposed_price"] if req["status"] == "approved" else None)
            conn.execute(
                """
                INSERT OR IGNORE INTO price_change_requests (
                    id, menu_item_id, requested_by_user_id, current_price,
                    proposed_price, approved_price, reason, status, effective_date,
                    reviewed_by_user_id, review_notes, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    req["id"],
                    req["menu_item_id"],
                    req["requested_by_user_id"],
                    req["current_price"],
                    req["proposed_price"],
                    app_p,
                    req["reason"],
                    req["status"],
                    req.get("effective_date"),
                    req.get("reviewed_by_user_id"),
                    req.get("review_notes"),
                    req["created_at"],
                ),
            )

        for h in DEFAULT_HISTORY:
            conn.execute(
                """
                INSERT OR IGNORE INTO price_history (
                    id, menu_item_id, old_price, new_price,
                    effective_date, approved_by_user_id, reason, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    h["id"],
                    h["menu_item_id"],
                    h["old_price"],
                    h["new_price"],
                    h["effective_date"],
                    h["approved_by_user_id"],
                    h["reason"],
                    h["created_at"],
                ),
            )

    @staticmethod
    def get_requests(
        status: Optional[str] = None,
        item_id: Optional[str] = None,
        branch_id: Optional[str] = None,
    ) -> List[PriceChangeRequestResponse]:
        with get_db() as conn:
            query = """
                SELECT 
                    p.id,
                    p.menu_item_id,
                    p.requested_by_user_id,
                    p.current_price,
                    p.proposed_price,
                    p.approved_price,
                    p.reason,
                    p.status,
                    p.effective_date,
                    p.reviewed_by_user_id,
                    p.review_notes,
                    p.created_at,
                    m.name_ar AS item_name_ar,
                    m.name_en AS item_name_en,
                    m.sku AS item_sku,
                    m.cost AS item_cost,
                    c.name_ar AS category_name,
                    u.full_name_ar AS requested_by_name,
                    b.name_ar AS branch_name
                FROM price_change_requests p
                LEFT JOIN menu_items m ON p.menu_item_id = m.id
                LEFT JOIN menu_categories c ON m.category_id = c.id
                LEFT JOIN users u ON p.requested_by_user_id = u.id
                LEFT JOIN branches b ON u.branch_id = b.id
                WHERE 1=1
            """
            params = []
            if status:
                query += " AND p.status = ?"
                params.append(status.lower())
            if item_id:
                query += " AND p.menu_item_id = ?"
                params.append(item_id)
            if branch_id:
                query += " AND (u.branch_id = ? OR b.id = ?)"
                params.extend([branch_id, branch_id])

            query += " ORDER BY p.created_at DESC"

            cursor = conn.execute(query, params)
            rows = cursor.fetchall()
            return [_row_to_request_response(r) for r in rows]

    @staticmethod
    def get_request_by_id(request_id: str) -> PriceChangeRequestResponse:
        with get_db() as conn:
            query = """
                SELECT 
                    p.id,
                    p.menu_item_id,
                    p.requested_by_user_id,
                    p.current_price,
                    p.proposed_price,
                    p.approved_price,
                    p.reason,
                    p.status,
                    p.effective_date,
                    p.reviewed_by_user_id,
                    p.review_notes,
                    p.created_at,
                    m.name_ar AS item_name_ar,
                    m.name_en AS item_name_en,
                    m.sku AS item_sku,
                    m.cost AS item_cost,
                    c.name_ar AS category_name,
                    u.full_name_ar AS requested_by_name,
                    b.name_ar AS branch_name
                FROM price_change_requests p
                LEFT JOIN menu_items m ON p.menu_item_id = m.id
                LEFT JOIN menu_categories c ON m.category_id = c.id
                LEFT JOIN users u ON p.requested_by_user_id = u.id
                LEFT JOIN branches b ON u.branch_id = b.id
                WHERE p.id = ?
            """
            cursor = conn.execute(query, (request_id,))
            row = cursor.fetchone()
            if not row:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Price change request '{request_id}' not found",
                )
            return _row_to_request_response(row)

    @staticmethod
    def create_request(
        payload: PriceChangeRequestCreate,
        user_id: Optional[str] = None,
    ) -> PriceChangeRequestResponse:
        if payload.proposedPrice is None or not math.isfinite(payload.proposedPrice) or payload.proposedPrice <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Proposed price must be a positive finite number (> 0)",
            )
        if payload.currentPrice is not None and (not math.isfinite(payload.currentPrice) or payload.currentPrice < 0):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Current price must be a non-negative finite number (>= 0)",
            )

        with get_db() as conn:
            # Check menu item exists
            item_cur = conn.execute("SELECT * FROM menu_items WHERE id = ?", (payload.itemId,))
            item_row = item_cur.fetchone()
            if not item_row:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Menu item '{payload.itemId}' not found",
                )

            # Canonical effective current price fetched from SQLite for target item
            db_curr_dec = Decimal(str(item_row["price"])).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
            prop_dec = Decimal(str(payload.proposedPrice)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

            if prop_dec == db_curr_dec:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="السعر المقترح يجب أن يختلف عن السعر الحالي",
                )

            current_price = float(db_curr_dec)
            request_id = payload.id or f"pcr_{int(time.time() * 1000)}"
            created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            requested_by = user_id or payload.requestedByUserId or "usr_bm1"

            conn.execute(
                """
                INSERT INTO price_change_requests (
                    id, menu_item_id, requested_by_user_id, current_price,
                    proposed_price, reason, status, effective_date, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, ?)
                """,
                (
                    request_id,
                    payload.itemId,
                    requested_by,
                    current_price,
                    payload.proposedPrice,
                    payload.reason,
                    payload.effectiveDate,
                    created_at,
                ),
            )

            # Audit log with user_id
            conn.execute(
                """
                INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, new_values_json)
                VALUES (?, ?, 'CREATE_PRICE_REQUEST', 'price_change_requests', ?, ?)
                """,
                (
                    f"aud_{int(time.time() * 1000)}",
                    requested_by,
                    request_id,
                    json.dumps(payload.model_dump(), ensure_ascii=False),
                ),
            )

        return PricingService.get_request_by_id(request_id)

    @staticmethod
    def approve_request(
        request_id: str,
        payload: Optional[PriceChangeRequestApprove] = None,
        user_id: Optional[str] = None,
        clock: Optional[Callable[[], datetime]] = None,
    ) -> PriceChangeRequestResponse:
        """
        ACID Transaction:
        1. Validates request status is pending.
        2. Updates request status to 'approved' with conditional state guard.
        3. Updates menu_items table with new price ONLY IF due now (effective_date <= current business day).
        4. Inserts entry in price_history table (stores scheduled/approved price).
        5. Writes to audit_logs table with user_id and scheduling flags.
        All committed together or rolled back completely on failure.
        """
        approved_by = user_id or (payload.approvedByUserId if payload and payload.approvedByUserId else "usr_ceo")
        review_notes = payload.reviewNotes if payload and payload.reviewNotes else "تم اعتماد السعر"
        effective_date = payload.effectiveDate if payload else None

        with get_db() as conn:
            # 1. Fetch request
            cur = conn.execute("SELECT * FROM price_change_requests WHERE id = ?", (request_id,))
            req_row = cur.fetchone()
            if not req_row:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Price change request '{request_id}' not found",
                )

            if req_row["status"] != "pending":
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Request '{request_id}' is already {req_row['status']}",
                )

            menu_item_id = req_row["menu_item_id"]
            old_price = float(req_row["current_price"])
            new_price = float(req_row["proposed_price"])
            reason = req_row["reason"]

            # 2. Fetch menu item
            item_cur = conn.execute("SELECT * FROM menu_items WHERE id = ?", (menu_item_id,))
            item_row = item_cur.fetchone()
            if not item_row:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Menu item '{menu_item_id}' not found",
                )

            # Revalidate under transaction: if live item price in DB is already identical to final price
            live_item_dec = Decimal(str(item_row["price"])).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
            
            is_override = False
            if payload and payload.approvedPrice is not None:
                approved_price_dec = Decimal(str(payload.approvedPrice)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
                if approved_price_dec <= Decimal("0"):
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="السعر المعتمد يجب أن يكون رقماً حقيقياً موجباً (> 0)",
                    )
                if live_item_dec == approved_price_dec:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="السعر المعتمد يجب أن يختلف عن السعر الحالي للصنف",
                    )
                final_price = float(approved_price_dec)
                is_override = True
            else:
                proposed_price_dec = Decimal(str(new_price)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
                if live_item_dec == proposed_price_dec:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="السعر الحالي للصنف مطابق بالفعل للسعر المقترح (لا يوجد تغيير لتطبيقه)",
                    )
                final_price = float(proposed_price_dec)

            now_dt = clock() if clock and callable(clock) else datetime.now()
            today_str = now_dt.strftime("%Y-%m-%d")
            created_at_val = now_dt.strftime("%Y-%m-%d %H:%M:%S")
            eff_date = effective_date or req_row["effective_date"] or today_str
            eff_clean = eff_date.strip()[:10] if eff_date else today_str
            is_future = eff_clean > today_str

            item_cost = float(item_row["cost"])
            new_margin = round(((final_price - item_cost) / final_price) * 100, 2) if final_price > 0 else 0.0

            # 3. Update price_change_requests conditionally (State Guard / Concurrent Idempotency)
            update_cur = conn.execute(
                """
                UPDATE price_change_requests
                SET status = 'approved',
                    approved_price = ?,
                    reviewed_by_user_id = ?,
                    review_notes = ?,
                    effective_date = ?
                WHERE id = ? AND status = 'pending'
                """,
                (final_price, approved_by, review_notes, eff_date, request_id),
            )
            if update_cur.rowcount == 0:
                check_cur = conn.execute("SELECT status FROM price_change_requests WHERE id = ?", (request_id,))
                fresh_row = check_cur.fetchone()
                fresh_status = fresh_row["status"] if fresh_row else "already modified"
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Request '{request_id}' is already {fresh_status}",
                )

            # 4. Update menu_items (Atomic) ONLY IF DUE NOW
            if not is_future:
                conn.execute(
                    """
                    UPDATE menu_items
                    SET price = ?,
                        margin_percent = ?,
                        updated_at = datetime('now')
                    WHERE id = ?
                    """,
                    (final_price, new_margin, menu_item_id),
                )

            # 5. Insert into price_history (Atomic)
            history_id = f"hist_{int(time.time() * 1000)}"
            conn.execute(
                """
                INSERT INTO price_history (
                    id, menu_item_id, old_price, new_price, effective_date,
                    approved_by_user_id, reason, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    history_id,
                    menu_item_id,
                    old_price,
                    final_price,
                    eff_date,
                    approved_by,
                    reason,
                    created_at_val,
                ),
            )

            # 6. Insert audit log with user_id
            audit_id = f"aud_{int(time.time() * 1000)}"
            conn.execute(
                """
                INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, old_values_json, new_values_json)
                VALUES (?, ?, 'APPROVE_PRICE_CHANGE', 'price_change_requests', ?, ?, ?)
                """,
                (
                    audit_id,
                    approved_by,
                    request_id,
                    json.dumps({
                        "status": "pending",
                        "old_price": old_price,
                        "proposed_price": float(req_row["proposed_price"]),
                    }, ensure_ascii=False),
                    json.dumps({
                        "status": "approved",
                        "new_price": final_price,
                        "approved_price": final_price,
                        "requested_price": float(req_row["proposed_price"]),
                        "history_id": history_id,
                        "effective_date": eff_date,
                        "is_override": is_override,
                        "is_future": is_future,
                    }, ensure_ascii=False),
                ),
            )

        return PricingService.get_request_by_id(request_id)

    @staticmethod
    def activate_due_prices(
        clock: Optional[Callable[[], datetime]] = None,
        conn: Optional[Any] = None,
    ) -> List[Dict[str, Any]]:
        """
        Activates due price changes whose effective_date is <= current business day (clock).
        - Idempotent and thread-safe: updates menu_items atomically where price != new_price.
        - Preserves ordering: picks latest effective_date DESC, created_at DESC, id DESC.
        - Records activation audit in audit_logs without duplicate entries in price_history.
        """
        now_dt = clock() if clock and callable(clock) else datetime.now()
        today_str = now_dt.strftime("%Y-%m-%d")

        query = """
            SELECT 
                h.menu_item_id,
                h.new_price,
                h.id as history_id,
                h.effective_date,
                m.cost,
                m.price as current_item_price
            FROM price_history h
            JOIN menu_items m ON h.menu_item_id = m.id
            WHERE substr(h.effective_date, 1, 10) <= ?
              AND h.id = (
                  SELECT h2.id
                  FROM price_history h2
                  WHERE h2.menu_item_id = h.menu_item_id
                    AND substr(h2.effective_date, 1, 10) <= ?
                  ORDER BY substr(h2.effective_date, 1, 10) DESC, h2.created_at DESC, h2.rowid DESC, h2.id DESC
                  LIMIT 1
              )
              AND m.price != h.new_price
        """

        def _execute_activation(c) -> List[Dict[str, Any]]:
            cur = c.execute(query, (today_str, today_str))
            rows = cur.fetchall()
            act_list = []
            for r in rows:
                item_id = r["menu_item_id"]
                new_p = float(r["new_price"])
                old_p = float(r["current_item_price"])
                item_cost = float(r["cost"]) if r["cost"] is not None else 0.0
                new_margin = round(((new_p - item_cost) / new_p) * 100, 2) if new_p > 0 else 0.0
                hist_id = r["history_id"]
                eff_d = r["effective_date"]

                # Atomic conditional update
                upd_cur = c.execute(
                    """
                    UPDATE menu_items
                    SET price = ?,
                        margin_percent = ?,
                        updated_at = datetime('now')
                    WHERE id = ? AND price != ?
                    """,
                    (new_p, new_margin, item_id, new_p),
                )
                if upd_cur.rowcount > 0:
                    audit_id = f"aud_{int(time.time() * 1000)}_{abs(hash(hist_id)) % 10000}"
                    c.execute(
                        """
                        INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, old_values_json, new_values_json)
                        VALUES (?, NULL, 'ACTIVATE_PRICE_CHANGE', 'menu_items', ?, ?, ?)
                        """,
                        (
                            audit_id,
                            item_id,
                            json.dumps({"old_price": old_p}, ensure_ascii=False),
                            json.dumps({
                                "new_price": new_p,
                                "effective_date": eff_d,
                                "history_id": hist_id,
                                "activated_at": today_str,
                                "actor": "system_scheduler",
                            }, ensure_ascii=False),
                        ),
                    )
                    act_list.append({
                        "item_id": item_id,
                        "old_price": old_p,
                        "new_price": new_p,
                        "effective_date": eff_d,
                        "history_id": hist_id,
                    })
            return act_list

        if conn is not None:
            return _execute_activation(conn)
        else:
            with get_db() as db_conn:
                return _execute_activation(db_conn)

    @staticmethod
    def reject_request(
        request_id: str,
        payload: Optional[PriceChangeRequestReject] = None,
        user_id: Optional[str] = None,
    ) -> PriceChangeRequestResponse:
        reviewed_by = user_id or (payload.reviewedByUserId if payload and payload.reviewedByUserId else "usr_ceo")
        review_notes = payload.reviewNotes if payload and payload.reviewNotes else "تم رفض الطلب"

        with get_db() as conn:
            cur = conn.execute("SELECT * FROM price_change_requests WHERE id = ?", (request_id,))
            req_row = cur.fetchone()
            if not req_row:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Price change request '{request_id}' not found",
                )

            if req_row["status"] != "pending":
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Request '{request_id}' is already {req_row['status']}",
                )

            update_cur = conn.execute(
                """
                UPDATE price_change_requests
                SET status = 'rejected',
                    reviewed_by_user_id = ?,
                    review_notes = ?
                WHERE id = ? AND status = 'pending'
                """,
                (reviewed_by, review_notes, request_id),
            )
            if update_cur.rowcount == 0:
                check_cur = conn.execute("SELECT status FROM price_change_requests WHERE id = ?", (request_id,))
                fresh_row = check_cur.fetchone()
                fresh_status = fresh_row["status"] if fresh_row else "already modified"
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Request '{request_id}' is already {fresh_status}",
                )

            # Audit log with user_id
            audit_id = f"aud_{int(time.time() * 1000)}"
            conn.execute(
                """
                INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, old_values_json, new_values_json)
                VALUES (?, ?, 'REJECT_PRICE_CHANGE', 'price_change_requests', ?, ?, ?)
                """,
                (
                    audit_id,
                    reviewed_by,
                    request_id,
                    json.dumps({"status": "pending"}, ensure_ascii=False),
                    json.dumps({"status": "rejected", "notes": review_notes}, ensure_ascii=False),
                ),
            )

        return PricingService.get_request_by_id(request_id)

    @staticmethod
    def get_price_history(item_id: str) -> List[PriceHistoryResponse]:
        with get_db() as conn:
            cursor = conn.execute(
                """
                SELECT 
                    h.id,
                    h.menu_item_id,
                    h.old_price,
                    h.new_price,
                    h.effective_date,
                    h.approved_by_user_id,
                    h.reason,
                    h.created_at,
                    u.full_name_ar AS approved_by_name,
                    m.name_ar AS item_name_ar,
                    m.name_en AS item_name_en,
                    m.sku AS item_sku,
                    m.price AS current_price,
                    c.name_ar AS category_name
                FROM price_history h
                LEFT JOIN users u ON h.approved_by_user_id = u.id
                LEFT JOIN menu_items m ON h.menu_item_id = m.id
                LEFT JOIN menu_categories c ON m.category_id = c.id
                WHERE h.menu_item_id = ?
                ORDER BY substr(h.effective_date, 1, 10) DESC, h.created_at DESC, h.rowid DESC, h.id DESC
                """,
                (item_id,),
            )
            rows = cursor.fetchall()
            return [_row_to_history_response(r) for r in rows]

    @staticmethod
    def get_item_pricing_summary(
        item_id: str,
        clock: Optional[Callable[[], datetime]] = None,
    ) -> ItemPricingSummaryResponse:
        now_dt = clock() if clock and callable(clock) else datetime.now()
        today_str = now_dt.strftime("%Y-%m-%d")

        with get_db() as conn:
            item_cur = conn.execute(
                """
                SELECT 
                    m.id,
                    m.name_ar AS item_name_ar,
                    m.name_en AS item_name_en,
                    m.sku AS item_sku,
                    m.price AS current_price,
                    m.cost AS item_cost,
                    c.name_ar AS category_name
                FROM menu_items m
                LEFT JOIN menu_categories c ON m.category_id = c.id
                WHERE m.id = ?
                """,
                (item_id,),
            )
            item_row = item_cur.fetchone()
            if not item_row:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Menu item '{item_id}' not found",
                )

            # Active effective date from history (effective on or before current business day)
            hist_cur = conn.execute(
                """
                SELECT effective_date
                FROM price_history
                WHERE menu_item_id = ? AND substr(effective_date, 1, 10) <= ?
                ORDER BY substr(effective_date, 1, 10) DESC, created_at DESC, rowid DESC, id DESC
                LIMIT 1
                """,
                (item_id, today_str),
            )
            hist_row = hist_cur.fetchone()
            effective_since = hist_row["effective_date"] if hist_row else None

            # Upcoming request (pending or approved with future effective date)
            upcoming_cur = conn.execute(
                """
                SELECT proposed_price, approved_price, effective_date, status
                FROM price_change_requests
                WHERE menu_item_id = ? 
                  AND (
                      status = 'pending' 
                      OR (status = 'approved' AND (effective_date IS NOT NULL AND substr(effective_date, 1, 10) > ?))
                  )
                ORDER BY created_at DESC
                LIMIT 1
                """,
                (item_id, today_str),
            )
            upcoming_row = upcoming_cur.fetchone()
            if upcoming_row:
                if upcoming_row["status"] == "approved" and upcoming_row["approved_price"] is not None:
                    upcoming_price = float(upcoming_row["approved_price"])
                else:
                    upcoming_price = float(upcoming_row["proposed_price"])
                upcoming_date = upcoming_row["effective_date"]
                upcoming_status = upcoming_row["status"]
            else:
                upcoming_price = None
                upcoming_date = None
                upcoming_status = None

            return ItemPricingSummaryResponse(
                itemId=item_row["id"],
                itemNameAr=item_row["item_name_ar"] or "صنف غير محدد",
                itemNameEn=item_row["item_name_en"] or "",
                itemSku=item_row["item_sku"] or "",
                categoryName=item_row["category_name"] or "عام",
                currentPrice=float(item_row["current_price"]),
                cost=float(item_row["item_cost"]) if item_row["item_cost"] is not None else 0.0,
                effectiveSince=effective_since,
                upcomingPrice=upcoming_price,
                upcomingEffectiveDate=upcoming_date,
                upcomingStatus=upcoming_status,
            )

    @staticmethod
    def get_active_menu_items() -> List[Dict[str, Any]]:
        with get_db() as conn:
            cur = conn.execute(
                """
                SELECT 
                    m.id,
                    m.name_ar,
                    m.name_en,
                    m.sku,
                    m.price,
                    m.cost,
                    c.name_ar AS category_name
                FROM menu_items m
                LEFT JOIN menu_categories c ON m.category_id = c.id
                WHERE m.is_active = 1
                ORDER BY m.name_ar ASC
                """
            )
            rows = cur.fetchall()
            return [
                {
                    "id": r["id"],
                    "nameAr": r["name_ar"],
                    "nameEn": r["name_en"] or "",
                    "sku": r["sku"] or "",
                    "price": float(r["price"]),
                    "cost": float(r["cost"]) if r["cost"] is not None else 0.0,
                    "categoryName": r["category_name"] or "عام",
                }
                for r in rows
            ]
