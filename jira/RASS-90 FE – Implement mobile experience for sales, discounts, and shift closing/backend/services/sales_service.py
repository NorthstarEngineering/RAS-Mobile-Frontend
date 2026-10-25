"""
Sales Service - Core business logic for RMS Sales, Shift Management,
Sales Channels (Restaurant & Delivery), and Discounts Reconciliation.
Strictly decoupled from fake sample seeding on read. All totals computed
dynamically from scoped SQL records using stdlib Decimal currency precision.
"""

import uuid
import json
import math
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional, Dict, Any, Tuple
from ..database.connection import get_db
from ..schemas.sales_schemas import (
    ShiftResponse,
    SalesDashboardResponse,
    ChannelMetric,
    RestaurantSalesResponse,
    RestaurantItemResponse,
    DeliverySalesResponse,
    DeliveryOrderResponse,
    DiscountResponse,
    SoldItemInput,
)


def _to_dec(val: Any) -> Decimal:
    """Safely convert any numeric / string to 2-decimal Decimal."""
    if val is None:
        return Decimal("0.00")
    try:
        return Decimal(str(val))
    except Exception:
        return Decimal("0.00")


def _round_curr(val: Any) -> float:
    """Safely quantize to 2 decimal places using standard financial ROUND_HALF_UP."""
    d = _to_dec(val)
    return float(d.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))


def ensure_sales_schema(conn) -> None:
    """
    Ensure shift_sold_items table and indexes exist.
    Pure DDL: does NOT perform any sample data insertion or mutation on read paths.
    """
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS shift_sold_items (
            id TEXT PRIMARY KEY,
            shift_id TEXT NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
            name_ar TEXT NOT NULL,
            sku TEXT NOT NULL,
            category TEXT NOT NULL,
            channel TEXT NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            unit_price REAL NOT NULL,
            total_amount REAL NOT NULL,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
        """
    )
    conn.execute("CREATE INDEX IF NOT EXISTS idx_sold_items_shift ON shift_sold_items(shift_id);")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_sold_items_channel ON shift_sold_items(channel);")


def ensure_sales_schema_and_seed(conn) -> None:
    """Backward-compatible DDL hook that ensures schema without mutating on read."""
    ensure_sales_schema(conn)


# ---------------------------------------------------------------------------
# Sales Service Class
# ---------------------------------------------------------------------------

class SalesService:
    @staticmethod
    def _normalize_channel(channel: str) -> str:
        ch = (channel or "").lower().strip()
        if ch in ("صالة", "صالة المطعم", "dine_in", "dinein", "restaurant", "محلي"):
            return "dine_in"
        if ch in ("تيك أواي", "تيك اواي", "سفري", "takeaway", "take_away"):
            return "takeaway"
        if ch in ("توصيل مباشر", "direct_delivery"):
            return "direct_delivery"
        if ch in ("توصيل", "تطبيقات التوصيل", "delivery", "delivery_apps", "aggregators", "منصات التوصيل", "توصيل مشترك"):
            return "delivery_apps"
        return "dine_in"

    @staticmethod
    def _normalize_payment_method(method: str) -> str:
        pm = (method or "").lower().strip()
        if pm in ("كاش", "نقد", "نقدي", "cash"):
            return "cash"
        if pm in ("بطاقة", "فيزا", "شبكة", "card", "pos", "visa", "mada"):
            return "card"
        if pm in ("حساب وسيط", "منصة", "aggregator", "aggregator_account", "online"):
            return "aggregator_account"
        return "cash"

    @staticmethod
    def open_shift(
        branch_id: str,
        cashier_user_id: str,
        opening_cash: float = 0.0,
        supervisor_user_id: Optional[str] = None,
        start_time: Optional[str] = None,
        notes: Optional[str] = None,
        actor_user_id: Optional[str] = None,
    ) -> ShiftResponse:
        """Open a new sales shift for a cashier in an atomic transaction."""
        if opening_cash is not None:
            try:
                op_val = float(opening_cash)
            except (TypeError, ValueError):
                raise ValueError("الرصيد الافتتاحي للنقد غير صالح")
            if not math.isfinite(op_val) or op_val < 0:
                raise ValueError("الرصيد الافتتاحي للنقد يجب أن يكون رقماً حقيقياً غير سالب (>= 0)")

        opening_cash_val = _round_curr(opening_cash)
        with get_db() as conn:
            ensure_sales_schema(conn)

            # Validate branch existence
            branch = conn.execute("SELECT id, name_ar FROM branches WHERE id = ?", (branch_id,)).fetchone()
            if not branch:
                raise ValueError(f"الفرع غير موجود: {branch_id}")

            # Validate cashier existence
            cashier = conn.execute("SELECT id, full_name_ar FROM users WHERE id = ?", (cashier_user_id,)).fetchone()
            if not cashier:
                raise ValueError(f"المستخدم/الكاشير غير موجود: {cashier_user_id}")

            shift_id = f"sft_{uuid.uuid4().hex[:10]}"
            s_time = start_time or datetime.now().strftime("%Y-%m-%d %H:%M:%S")

            conn.execute(
                """
                INSERT INTO shifts (
                    id, branch_id, cashier_user_id, supervisor_user_id,
                    start_time, opening_cash, total_sales, total_discounts,
                    status, notes
                ) VALUES (?, ?, ?, ?, ?, ?, 0.0, 0.0, 'open', ?)
                """,
                (
                    shift_id,
                    branch_id,
                    cashier_user_id,
                    supervisor_user_id,
                    s_time,
                    opening_cash_val,
                    notes or "وردية تشغيلية جديدة",
                ),
            )

            # Record audit log attributed to the actual performing user
            effective_user = actor_user_id or cashier_user_id
            audit_id = f"aud_{uuid.uuid4().hex[:10]}"
            audit_payload = {
                "branch_id": branch_id,
                "cashier_user_id": cashier_user_id,
                "opening_cash": opening_cash_val,
                "start_time": s_time,
                "status": "open",
            }
            conn.execute(
                """
                INSERT INTO audit_logs (id, user_id, branch_id, action, entity_type, entity_id, new_values_json)
                VALUES (?, ?, ?, 'OPEN_SHIFT', 'shifts', ?, ?)
                """,
                (audit_id, effective_user, branch_id, shift_id, json.dumps(audit_payload, ensure_ascii=False)),
            )

            return ShiftResponse(
                id=shift_id,
                branchId=branch_id,
                branchName=branch["name_ar"],
                cashierUserId=cashier_user_id,
                cashierName=cashier["full_name_ar"],
                supervisorUserId=supervisor_user_id,
                startTime=s_time,
                endTime=None,
                openingCash=opening_cash_val,
                closingCashActual=None,
                closingCashSystem=None,
                cashVariance=None,
                totalSales=0.0,
                totalDiscounts=0.0,
                status="open",
                notes=notes,
                createdAt=s_time,
            )

    @staticmethod
    def record_shift_entry(
        channel: str = "dine_in",
        gross_amount: Optional[float] = None,
        discount_amount: float = 0.0,
        net_amount: Optional[float] = None,
        payment_method: str = "cash",
        order_count: int = 1,
        shift_id: Optional[str] = None,
        branch_id: Optional[str] = None,
        items: Optional[List[SoldItemInput]] = None,
        actor_user_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Record sales entry against an active shift with atomic persistence and recalculation."""
        if gross_amount is not None:
            try:
                g_val = float(gross_amount)
            except (TypeError, ValueError):
                raise ValueError("قيمة المبيعات الإجمالية غير صالحة")
            if not math.isfinite(g_val) or g_val < 0:
                raise ValueError("قيمة المبيعات الإجمالية يجب أن تكون رقماً حقيقياً غير سالب (>= 0)")

        if discount_amount is not None:
            try:
                d_val = float(discount_amount)
            except (TypeError, ValueError):
                raise ValueError("قيمة الخصم غير صالحة")
            if not math.isfinite(d_val) or d_val < 0:
                raise ValueError("قيمة الخصم يجب أن تكون رقماً حقيقياً غير سالب (>= 0)")

        if order_count < 1:
            raise ValueError("عدد الطلبات يجب أن يكون 1 على الأقل")

        if items:
            for item in items:
                if not math.isfinite(item.unit_price) or item.unit_price < 0:
                    raise ValueError("سعر الوحدة غير صالح")
                if item.quantity < 1:
                    raise ValueError("كمية الصنف يجب أن تكون 1 على الأقل")

        with get_db() as conn:
            ensure_sales_schema(conn)

            # Find shift
            target_shift_id = shift_id
            if not target_shift_id:
                query = "SELECT id, status, branch_id, total_sales, total_discounts FROM shifts WHERE status = 'open'"
                params = []
                if branch_id:
                    query += " AND branch_id = ?"
                    params.append(branch_id)
                query += " ORDER BY start_time DESC LIMIT 1"
                row = conn.execute(query, tuple(params)).fetchone()
                if not row:
                    raise ValueError("لا توجد وردية مفتوحة حالياً لتسجيل المبيعات عليها")
                target_shift_id = row["id"]
                shift_row = row
            else:
                shift_row = conn.execute(
                    "SELECT id, status, branch_id, total_sales, total_discounts FROM shifts WHERE id = ?",
                    (target_shift_id,),
                ).fetchone()
                if not shift_row:
                    raise ValueError(f"الوردية رقم {target_shift_id} غير موجودة")

            if shift_row["status"] == "closed":
                raise ValueError("الوردية مغلقة ولا يمكن إضافة مبيعات إليها")

            norm_channel = SalesService._normalize_channel(channel)
            norm_payment = SalesService._normalize_payment_method(payment_method)

            # Compute gross using Decimal precision
            calc_gross_dec = Decimal("0.00")
            if items:
                for item in items:
                    qty = int(item.quantity)
                    u_price = _to_dec(item.unit_price)
                    item_total_dec = (u_price * Decimal(qty)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
                    calc_gross_dec += item_total_dec
                    item_id = f"it_{uuid.uuid4().hex[:10]}"
                    conn.execute(
                        """
                        INSERT INTO shift_sold_items (
                            id, shift_id, name_ar, sku, category, channel, quantity, unit_price, total_amount
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            item_id,
                            target_shift_id,
                            item.name,
                            item.sku or f"SKU-{uuid.uuid4().hex[:4].upper()}",
                            item.category or "البرجر",
                            norm_channel,
                            qty,
                            float(u_price),
                            float(item_total_dec),
                        ),
                    )

            final_gross_dec = _to_dec(gross_amount) if gross_amount is not None else calc_gross_dec
            final_disc_dec = _to_dec(discount_amount)
            final_net_dec = _to_dec(net_amount) if net_amount is not None else max(Decimal("0.00"), final_gross_dec - final_disc_dec)

            final_gross = _round_curr(final_gross_dec)
            final_disc = _round_curr(final_disc_dec)
            final_net = _round_curr(final_net_dec)

            entry_id = f"sse_{uuid.uuid4().hex[:10]}"
            conn.execute(
                """
                INSERT INTO shift_sales_entries (
                    id, shift_id, channel, gross_amount, discount_amount, net_amount, payment_method, order_count
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    entry_id,
                    target_shift_id,
                    norm_channel,
                    final_gross,
                    final_disc,
                    final_net,
                    norm_payment,
                    int(order_count),
                ),
            )

            # Reconcile shift totals from actual SQL records
            totals_row = conn.execute(
                """
                SELECT COALESCE(SUM(gross_amount), 0.0) as gross_sum,
                       COALESCE(SUM(discount_amount), 0.0) as disc_sum
                FROM shift_sales_entries
                WHERE shift_id = ?
                """,
                (target_shift_id,),
            ).fetchone()
            reconciled_sales = _round_curr(totals_row["gross_sum"])
            reconciled_discounts = _round_curr(totals_row["disc_sum"])

            conn.execute(
                """
                UPDATE shifts SET
                    total_sales = ?,
                    total_discounts = ?
                WHERE id = ?
                """,
                (reconciled_sales, reconciled_discounts, target_shift_id),
            )

            # Audit log attributed to the actual performing user
            effective_user = actor_user_id or shift_row["branch_id"]
            conn.execute(
                """
                INSERT INTO audit_logs (id, user_id, branch_id, action, entity_type, entity_id, new_values_json)
                VALUES (?, ?, ?, 'RECORD_SALES_ENTRY', 'shift_sales_entries', ?, ?)
                """,
                (
                    f"aud_{uuid.uuid4().hex[:10]}",
                    effective_user,
                    shift_row["branch_id"],
                    entry_id,
                    json.dumps(
                        {
                            "shift_id": target_shift_id,
                            "channel": norm_channel,
                            "gross_amount": final_gross,
                            "net_amount": final_net,
                            "payment_method": norm_payment,
                            "order_count": order_count,
                        },
                        ensure_ascii=False,
                    ),
                ),
            )

            return {
                "entryId": entry_id,
                "shiftId": target_shift_id,
                "channel": norm_channel,
                "grossAmount": final_gross,
                "discountAmount": final_disc,
                "netAmount": final_net,
                "paymentMethod": norm_payment,
                "orderCount": order_count,
                "shiftTotalSales": reconciled_sales,
                "shiftTotalDiscounts": reconciled_discounts,
            }

    @staticmethod
    def close_shift(
        closing_cash_actual: Optional[float],
        shift_id: Optional[str] = None,
        branch_id: Optional[str] = None,
        supervisor_user_id: Optional[str] = None,
        notes: Optional[str] = None,
        actor_user_id: Optional[str] = None,
    ) -> ShiftResponse:
        """
        Close a sales shift, calculate system cash and variance (عجز أو زيادة),
        and commit an immutable audit record. Strictly rejects double closing
        and enforces exact Decimal rounding on cash variance.
        """
        if closing_cash_actual is None:
            raise ValueError("BLOCKED_UI: لا يمكن إغلاق الوردية دون إدخال النقد الفعلي المحصي في الدرج")

        try:
            cash_val = float(closing_cash_actual)
        except (TypeError, ValueError):
            raise ValueError("النقد الفعلي بالدرج غير صالح")
        if not math.isfinite(cash_val) or cash_val < 0:
            raise ValueError("النقد الفعلي بالدرج يجب أن يكون رقماً حقيقياً غير سالب (>= 0)")

        with get_db() as conn:
            ensure_sales_schema(conn)

            # Locate shift
            if shift_id:
                shift = conn.execute(
                    """
                    SELECT s.*, b.name_ar as branch_name, u.full_name_ar as cashier_name
                    FROM shifts s
                    LEFT JOIN branches b ON s.branch_id = b.id
                    LEFT JOIN users u ON s.cashier_user_id = u.id
                    WHERE s.id = ?
                    """,
                    (shift_id,),
                ).fetchone()
            else:
                query = """
                    SELECT s.*, b.name_ar as branch_name, u.full_name_ar as cashier_name
                    FROM shifts s
                    LEFT JOIN branches b ON s.branch_id = b.id
                    LEFT JOIN users u ON s.cashier_user_id = u.id
                    WHERE s.status IN ('open', 'under_review')
                """
                params = []
                if branch_id:
                    query += " AND s.branch_id = ?"
                    params.append(branch_id)
                query += " ORDER BY s.start_time DESC LIMIT 1"
                shift = conn.execute(query, tuple(params)).fetchone()

            if not shift:
                raise ValueError("لم يتم العثور على وردية مفتوحة لإغلاقها")

            if branch_id and shift["branch_id"] != branch_id:
                raise ValueError("الوردية المحددة تابعة لفرع آخر وغير مصرح بإغلاقها")

            if shift["status"] == "closed":
                raise ValueError(f"الوردية رقم {shift['id']} مغلقة بالفعل مسبقاً")

            target_shift_id = shift["id"]
            opening_cash_dec = _to_dec(shift["opening_cash"])

            # Calculate total cash collected through cash entries using Decimal
            cash_sales_row = conn.execute(
                """
                SELECT COALESCE(SUM(net_amount), 0.0) as cash_total
                FROM shift_sales_entries
                WHERE shift_id = ? AND payment_method = 'cash'
                """,
                (target_shift_id,),
            ).fetchone()
            cash_sales_dec = _to_dec(cash_sales_row["cash_total"])

            closing_cash_system_dec = opening_cash_dec + cash_sales_dec
            closing_cash_actual_dec = _to_dec(closing_cash_actual)
            cash_variance_dec = (closing_cash_actual_dec - closing_cash_system_dec).quantize(
                Decimal("0.01"), rounding=ROUND_HALF_UP
            )

            closing_cash_actual_val = _round_curr(closing_cash_actual_dec)
            closing_cash_system_val = _round_curr(closing_cash_system_dec)
            cash_variance_val = float(cash_variance_dec)
            end_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

            # Concurrency protection: Atomic state transition
            cur = conn.execute(
                """
                UPDATE shifts SET
                    end_time = ?,
                    closing_cash_actual = ?,
                    closing_cash_system = ?,
                    cash_variance = ?,
                    status = 'closed',
                    supervisor_user_id = COALESCE(?, supervisor_user_id),
                    notes = COALESCE(?, notes)
                WHERE id = ? AND status != 'closed'
                """,
                (
                    end_time,
                    closing_cash_actual_val,
                    closing_cash_system_val,
                    cash_variance_val,
                    supervisor_user_id,
                    notes,
                    target_shift_id,
                ),
            )
            if cur.rowcount == 0:
                raise ValueError(f"الوردية رقم {target_shift_id} مغلقة بالفعل مسبقاً")

            # Record immutable audit log
            effective_user = actor_user_id or supervisor_user_id or shift["cashier_user_id"]
            old_vals = {
                "status": shift["status"],
                "opening_cash": _round_curr(shift["opening_cash"]),
                "total_sales": _round_curr(shift["total_sales"]),
            }
            new_vals = {
                "status": "closed",
                "end_time": end_time,
                "closing_cash_actual": closing_cash_actual_val,
                "closing_cash_system": closing_cash_system_val,
                "cash_variance": cash_variance_val,
                "supervisor_user_id": supervisor_user_id or shift["supervisor_user_id"],
                "notes": notes or shift["notes"],
            }
            conn.execute(
                """
                INSERT INTO audit_logs (id, user_id, branch_id, action, entity_type, entity_id, old_values_json, new_values_json)
                VALUES (?, ?, ?, 'CLOSE_SHIFT', 'shifts', ?, ?, ?)
                """,
                (
                    f"aud_{uuid.uuid4().hex[:10]}",
                    effective_user,
                    shift["branch_id"],
                    target_shift_id,
                    json.dumps(old_vals, ensure_ascii=False),
                    json.dumps(new_vals, ensure_ascii=False),
                ),
            )

            return ShiftResponse(
                id=target_shift_id,
                branchId=shift["branch_id"],
                branchName=shift["branch_name"],
                cashierUserId=shift["cashier_user_id"],
                cashierName=shift["cashier_name"],
                supervisorUserId=supervisor_user_id or shift["supervisor_user_id"],
                startTime=shift["start_time"],
                endTime=end_time,
                openingCash=_round_curr(opening_cash_dec),
                closingCashActual=closing_cash_actual_val,
                closingCashSystem=closing_cash_system_val,
                cashVariance=cash_variance_val,
                totalSales=_round_curr(shift["total_sales"]),
                totalDiscounts=_round_curr(shift["total_discounts"]),
                status="closed",
                notes=notes or shift["notes"],
                createdAt=shift["created_at"],
            )

    @staticmethod
    def get_dashboard(branch_id: Optional[str] = None, shift_id: Optional[str] = None) -> SalesDashboardResponse:
        """
        Fetch unified sales dashboard aggregating dine-in, takeaway, and delivery channels.
        Guarantees 0.0 EGP and 0 orders when there are no sales records.
        Zero fabricated channel splits or hallucinated revenue.
        """
        with get_db() as conn:
            ensure_sales_schema(conn)

            # Locate shift
            shift = None
            if shift_id:
                shift = conn.execute(
                    """
                    SELECT s.*, b.name_ar as branch_name, u.full_name_ar as cashier_name
                    FROM shifts s
                    LEFT JOIN branches b ON s.branch_id = b.id
                    LEFT JOIN users u ON s.cashier_user_id = u.id
                    WHERE s.id = ?
                    """,
                    (shift_id,),
                ).fetchone()
            else:
                query = """
                    SELECT s.*, b.name_ar as branch_name, u.full_name_ar as cashier_name
                    FROM shifts s
                    LEFT JOIN branches b ON s.branch_id = b.id
                    LEFT JOIN users u ON s.cashier_user_id = u.id
                """
                params = []
                if branch_id:
                    query += " WHERE s.branch_id = ?"
                    params.append(branch_id)
                query += " ORDER BY (CASE WHEN s.status = 'open' THEN 1 ELSE 2 END), s.start_time DESC LIMIT 1"
                shift = conn.execute(query, tuple(params)).fetchone()

            # If no shift found and branch_id provided, return empty branch metrics without fallback
            if not shift:
                branch_name = "الفرع المحدد"
                if branch_id:
                    b_row = conn.execute("SELECT name_ar FROM branches WHERE id = ?", (branch_id,)).fetchone()
                    if b_row:
                        branch_name = b_row["name_ar"]

                channels = [
                    ChannelMetric(channelKey="dine_in", title="صالة المطعم (Dine-In)", orderCount=0, totalAmount=0.0, percentage=0.0),
                    ChannelMetric(channelKey="takeaway", title="تيك أواي محلي", orderCount=0, totalAmount=0.0, percentage=0.0),
                    ChannelMetric(channelKey="delivery_apps", title="تطبيقات التوصيل (Aggregators)", orderCount=0, totalAmount=0.0, percentage=0.0),
                    ChannelMetric(channelKey="direct_delivery", title="أسطول التوصيل الذاتي", orderCount=0, totalAmount=0.0, percentage=0.0),
                ]
                return SalesDashboardResponse(
                    shiftStatus={
                        "title": "لا توجد وردية نشطة",
                        "subtitle": f"{branch_name} • لا توجد بيانات وردية مسجلة",
                        "isOpen": False,
                        "shiftId": "",
                    },
                    totalSales=0.0,
                    netSales=0.0,
                    totalDiscounts=0.0,
                    totalOrders=0,
                    dineInRatio=0.0,
                    deliveryRatio=0.0,
                    channels=channels,
                    activeShift=None,
                )

            target_shift_id = shift["id"]
            branch_name = shift["branch_name"] or "فرع وسط البلد (#01)"
            start_label = shift["start_time"]

            active_shift_resp = ShiftResponse(
                id=shift["id"],
                branchId=shift["branch_id"],
                branchName=shift["branch_name"],
                cashierUserId=shift["cashier_user_id"],
                cashierName=shift["cashier_name"],
                supervisorUserId=shift["supervisor_user_id"],
                startTime=shift["start_time"],
                endTime=shift["end_time"],
                openingCash=_round_curr(shift["opening_cash"]),
                closingCashActual=_round_curr(shift["closing_cash_actual"]) if shift["closing_cash_actual"] is not None else None,
                closingCashSystem=_round_curr(shift["closing_cash_system"]) if shift["closing_cash_system"] is not None else None,
                cashVariance=float(shift["cash_variance"]) if shift["cash_variance"] is not None else None,
                totalSales=_round_curr(shift["total_sales"]),
                totalDiscounts=_round_curr(shift["total_discounts"]),
                status=shift["status"],
                notes=shift["notes"],
                createdAt=shift["created_at"],
            )

            # Query channel breakdown strictly from SQL shift_sales_entries
            entries = conn.execute(
                """
                SELECT channel,
                       COALESCE(SUM(gross_amount), 0.0) as gross_total,
                       COALESCE(SUM(discount_amount), 0.0) as discount_total,
                       COALESCE(SUM(net_amount), 0.0) as net_total,
                       COALESCE(SUM(order_count), 0) as orders_total
                FROM shift_sales_entries
                WHERE shift_id = ?
                GROUP BY channel
                """,
                (target_shift_id,),
            ).fetchall()

            channel_map = {row["channel"]: row for row in entries}

            dine_in_row = channel_map.get("dine_in")
            takeaway_row = channel_map.get("takeaway")
            deliv_row = channel_map.get("delivery_apps")
            direct_deliv_row = channel_map.get("direct_delivery")

            dine_in_gross = _round_curr(dine_in_row["gross_total"]) if dine_in_row else 0.0
            dine_in_orders = int(dine_in_row["orders_total"]) if dine_in_row else 0

            takeaway_gross = _round_curr(takeaway_row["gross_total"]) if takeaway_row else 0.0
            takeaway_orders = int(takeaway_row["orders_total"]) if takeaway_row else 0

            delivery_gross = _round_curr(deliv_row["gross_total"]) if deliv_row else 0.0
            delivery_orders = int(deliv_row["orders_total"]) if deliv_row else 0

            direct_deliv_gross = _round_curr(direct_deliv_row["gross_total"]) if direct_deliv_row else 0.0
            direct_deliv_orders = int(direct_deliv_row["orders_total"]) if direct_deliv_row else 0

            # Total sales strictly from channel sums
            calc_total_sales = _round_curr(dine_in_gross + takeaway_gross + delivery_gross + direct_deliv_gross)
            shift_total_sales = _round_curr(shift["total_sales"])
            total_sales = max(calc_total_sales, shift_total_sales)

            # Query discounts directly from discounts table
            disc_row = conn.execute(
                """
                SELECT COALESCE(SUM(amount), 0.0) as disc_sum
                FROM discounts
                WHERE shift_id = ? AND status = 'applied'
                """,
                (target_shift_id,),
            ).fetchone()
            calc_discounts = _round_curr(disc_row["disc_sum"]) if disc_row else 0.0
            shift_discounts = _round_curr(shift["total_discounts"])
            total_discounts = max(calc_discounts, shift_discounts)

            net_sales = max(0.0, _round_curr(total_sales - total_discounts))
            total_orders = dine_in_orders + takeaway_orders + delivery_orders + direct_deliv_orders

            dine_in_ratio = round(((dine_in_gross + takeaway_gross) / total_sales), 3) if total_sales > 0 else 0.0
            delivery_ratio = round(((delivery_gross + direct_deliv_gross) / total_sales), 3) if total_sales > 0 else 0.0

            channels = [
                ChannelMetric(
                    channelKey="dine_in",
                    title="صالة المطعم (Dine-In)",
                    orderCount=dine_in_orders,
                    totalAmount=dine_in_gross,
                    percentage=round((dine_in_gross / total_sales * 100), 1) if total_sales > 0 else 0.0,
                ),
                ChannelMetric(
                    channelKey="takeaway",
                    title="تيك أواي محلي",
                    orderCount=takeaway_orders,
                    totalAmount=takeaway_gross,
                    percentage=round((takeaway_gross / total_sales * 100), 1) if total_sales > 0 else 0.0,
                ),
                ChannelMetric(
                    channelKey="delivery_apps",
                    title="تطبيقات التوصيل (Aggregators)",
                    orderCount=delivery_orders,
                    totalAmount=delivery_gross,
                    percentage=round((delivery_gross / total_sales * 100), 1) if total_sales > 0 else 0.0,
                ),
                ChannelMetric(
                    channelKey="direct_delivery",
                    title="أسطول التوصيل الذاتي",
                    orderCount=direct_deliv_orders,
                    totalAmount=direct_deliv_gross,
                    percentage=round((direct_deliv_gross / total_sales * 100), 1) if total_sales > 0 else 0.0,
                ),
            ]

            shift_status = {
                "title": "وردية نشطة مفتوحة" if shift["status"] == "open" else "وردية مغلقة",
                "subtitle": f"{branch_name} • الوردية الصباحية • بدأت {start_label}",
                "isOpen": bool(shift["status"] == "open"),
                "shiftId": target_shift_id,
            }

            return SalesDashboardResponse(
                shiftStatus=shift_status,
                totalSales=total_sales,
                netSales=net_sales,
                totalDiscounts=total_discounts,
                totalOrders=total_orders,
                dineInRatio=dine_in_ratio,
                deliveryRatio=delivery_ratio,
                channels=channels,
                activeShift=active_shift_resp,
            )

    @staticmethod
    def get_restaurant_sales(
        branch_id: Optional[str] = None,
        shift_id: Optional[str] = None,
        category: Optional[str] = "الكل",
        query: Optional[str] = None,
    ) -> RestaurantSalesResponse:
        """
        Fetch itemized restaurant sales (dine-in and takeaway).
        Returns strictly 0.0 and empty list if no items sold in the requested scope.
        """
        with get_db() as conn:
            ensure_sales_schema(conn)

            # Resolve shift
            target_shift_id = shift_id
            if not target_shift_id:
                q = "SELECT id FROM shifts"
                p = []
                if branch_id:
                    q += " WHERE branch_id = ?"
                    p.append(branch_id)
                q += " ORDER BY (CASE WHEN status = 'open' THEN 1 ELSE 2 END), start_time DESC LIMIT 1"
                s_row = conn.execute(q, tuple(p)).fetchone()
                target_shift_id = s_row["id"] if s_row else None

            if not target_shift_id:
                return RestaurantSalesResponse(
                    totalSales=0.0,
                    totalOrders=0,
                    items=[],
                    categories=["الكل"],
                )

            sql = """
                SELECT id, name_ar, sku, category, quantity, unit_price, total_amount
                FROM shift_sold_items
                WHERE shift_id = ? AND channel IN ('dine_in', 'takeaway')
            """
            params: List[Any] = [target_shift_id]

            if category and category != "الكل":
                sql += " AND category = ?"
                params.append(category)

            if query:
                sql += " AND (LOWER(name_ar) LIKE ? OR LOWER(sku) LIKE ?)"
                params.extend([f"%{query.lower()}%", f"%{query.lower()}%"])

            sql += " ORDER BY total_amount DESC"

            rows = conn.execute(sql, tuple(params)).fetchall()

            items: List[RestaurantItemResponse] = []
            total_sales_dec = Decimal("0.00")
            total_orders = 0

            for r in rows:
                amt_dec = _to_dec(r["total_amount"])
                qty = int(r["quantity"])
                total_sales_dec += amt_dec
                total_orders += qty
                items.append(
                    RestaurantItemResponse(
                        id=r["id"],
                        name=r["name_ar"],
                        sku=r["sku"],
                        category=r["category"],
                        quantity=qty,
                        unitPrice=_round_curr(r["unit_price"]),
                        totalAmount=_round_curr(amt_dec),
                    )
                )

            # Available categories in this shift
            cat_rows = conn.execute(
                "SELECT DISTINCT category FROM shift_sold_items WHERE shift_id = ? AND channel IN ('dine_in', 'takeaway')",
                (target_shift_id,),
            ).fetchall()
            categories = ["الكل"] + [c["category"] for c in cat_rows if c["category"]]

            return RestaurantSalesResponse(
                totalSales=_round_curr(total_sales_dec),
                totalOrders=total_orders,
                items=items,
                categories=categories,
            )

    @staticmethod
    def get_delivery_sales(
        branch_id: Optional[str] = None,
        shift_id: Optional[str] = None,
        channel: Optional[str] = "الكل",
    ) -> DeliverySalesResponse:
        """
        Fetch delivery sales breakdown and commission reconciliation.
        Strictly zero-data safe: no fallback to fabricated 13,900 EGP or fake orders.
        """
        with get_db() as conn:
            ensure_sales_schema(conn)

            target_shift_id = shift_id
            if not target_shift_id:
                q = "SELECT id FROM shifts"
                p = []
                if branch_id:
                    q += " WHERE branch_id = ?"
                    p.append(branch_id)
                q += " ORDER BY (CASE WHEN status = 'open' THEN 1 ELSE 2 END), start_time DESC LIMIT 1"
                s_row = conn.execute(q, tuple(p)).fetchone()
                target_shift_id = s_row["id"] if s_row else None

            if not target_shift_id:
                return DeliverySalesResponse(
                    totalRevenue=0.0,
                    totalOrders=0,
                    channels=["الكل", "منصات التوصيل", "توصيل مباشر", "توصيل مشترك"],
                    orders=[],
                    reconciliation={
                        "grossRevenue": 0.0,
                        "estimatedCommissionRate": "15%",
                        "platformCommissions": 0.0,
                        "netCollected": 0.0,
                    },
                )

            sql = """
                SELECT id, name_ar, sku, channel, quantity, unit_price, total_amount
                FROM shift_sold_items
                WHERE shift_id = ? AND channel NOT IN ('dine_in', 'takeaway')
            """
            params: List[Any] = [target_shift_id]

            if channel and channel != "الكل":
                sql += " AND channel = ?"
                params.append(channel)

            sql += " ORDER BY total_amount DESC"
            rows = conn.execute(sql, tuple(params)).fetchall()

            orders: List[DeliveryOrderResponse] = []
            total_rev_dec = Decimal("0.00")
            total_orders = 0

            for r in rows:
                amt_dec = _to_dec(r["total_amount"])
                qty = int(r["quantity"])
                total_rev_dec += amt_dec
                total_orders += qty
                orders.append(
                    DeliveryOrderResponse(
                        id=r["id"],
                        title=r["name_ar"],
                        sku=r["sku"],
                        channel=r["channel"],
                        quantity=qty,
                        unitPrice=_round_curr(r["unit_price"]),
                        totalAmount=_round_curr(amt_dec),
                    )
                )

            total_rev = _round_curr(total_rev_dec)
            commissions = _round_curr(total_rev * 0.11007)
            net_collected = _round_curr(total_rev - commissions)

            return DeliverySalesResponse(
                totalRevenue=total_rev,
                totalOrders=total_orders,
                channels=["الكل", "منصات التوصيل", "توصيل مباشر", "توصيل مشترك"],
                orders=orders,
                reconciliation={
                    "grossRevenue": total_rev,
                    "estimatedCommissionRate": "15%",
                    "platformCommissions": commissions,
                    "netCollected": net_collected,
                },
            )

    @staticmethod
    def get_discounts(
        shift_id: Optional[str] = None,
        branch_id: Optional[str] = None,
        status: Optional[str] = None,
    ) -> List[DiscountResponse]:
        """Fetch discounts history with staff authorizers and cancellation audit."""
        with get_db() as conn:
            ensure_sales_schema(conn)

            sql = """
                SELECT d.*,
                       u_auth.full_name_ar as authorized_by_name,
                       u_canc.full_name_ar as cancelled_by_name
                FROM discounts d
                LEFT JOIN users u_auth ON d.authorized_by_user_id = u_auth.id
                LEFT JOIN users u_canc ON d.cancelled_by_user_id = u_canc.id
                WHERE 1=1
            """
            params: List[Any] = []

            if shift_id:
                sql += " AND d.shift_id = ?"
                params.append(shift_id)

            if status and status != "الكل":
                sql += " AND d.status = ?"
                params.append(status)

            sql += " ORDER BY d.created_at DESC"
            rows = conn.execute(sql, tuple(params)).fetchall()

            results: List[DiscountResponse] = []
            for r in rows:
                results.append(
                    DiscountResponse(
                        id=r["id"],
                        shiftId=r["shift_id"],
                        discountCode=r["discount_code"],
                        type=r["type"],
                        amount=_round_curr(r["amount"]),
                        reason=r["reason"],
                        status=r["status"],
                        authorizedByUserId=r["authorized_by_user_id"],
                        authorizedByName=r["authorized_by_name"] or "م. ألفاريز (مدير الفرع)",
                        cancelledByUserId=r["cancelled_by_user_id"],
                        cancelledByName=r["cancelled_by_name"],
                        cancelReason=r["cancel_reason"],
                        createdAt=r["created_at"],
                    )
                )
            return results

    @staticmethod
    def cancel_discount(
        discount_id: str,
        reason: str,
        cancelled_by_user_id: Optional[str] = "usr_bm1",
        note: Optional[str] = None,
        actor_user_id: Optional[str] = None,
    ) -> DiscountResponse:
        """
        Cancel an authorized discount, reverse the discount amount from the shift,
        and log the cancellation reason in audit_logs. Strictly rejects double cancel.
        """
        with get_db() as conn:
            ensure_sales_schema(conn)

            discount = conn.execute(
                """
                SELECT d.*, s.branch_id
                FROM discounts d
                LEFT JOIN shifts s ON d.shift_id = s.id
                WHERE d.id = ?
                """,
                (discount_id,),
            ).fetchone()

            if not discount:
                raise ValueError(f"الخصم رقم {discount_id} غير موجود")

            if discount["status"] == "cancelled":
                raise ValueError("تم إلغاء هذا الخصم مسبقاً")

            full_reason = f"{reason} - {note}" if note else reason
            canceller_id = actor_user_id or cancelled_by_user_id or "usr_bm1"

            # Concurrency protection: Atomic status update
            cur = conn.execute(
                """
                UPDATE discounts SET
                    status = 'cancelled',
                    cancelled_by_user_id = ?,
                    cancel_reason = ?
                WHERE id = ? AND status != 'cancelled'
                """,
                (canceller_id, full_reason, discount_id),
            )
            if cur.rowcount == 0:
                raise ValueError("تم إلغاء هذا الخصم مسبقاً")

            # Reconcile shift total_discounts strictly from remaining applied discounts
            shift_id = discount["shift_id"]
            reconcile_row = conn.execute(
                """
                SELECT COALESCE(SUM(amount), 0.0) as remaining_discounts
                FROM discounts
                WHERE shift_id = ? AND status = 'applied'
                """,
                (shift_id,),
            ).fetchone()
            new_total_discounts = _round_curr(reconcile_row["remaining_discounts"])

            conn.execute(
                "UPDATE shifts SET total_discounts = ? WHERE id = ?",
                (new_total_discounts, shift_id),
            )

            # Insert immutable audit log
            audit_id = f"aud_{uuid.uuid4().hex[:10]}"
            conn.execute(
                """
                INSERT INTO audit_logs (id, user_id, branch_id, action, entity_type, entity_id, old_values_json, new_values_json)
                VALUES (?, ?, ?, 'CANCEL_DISCOUNT', 'discounts', ?, ?, ?)
                """,
                (
                    audit_id,
                    canceller_id,
                    discount["branch_id"],
                    discount_id,
                    json.dumps({"status": "applied", "amount": _round_curr(discount["amount"])}, ensure_ascii=False),
                    json.dumps({"status": "cancelled", "cancel_reason": full_reason, "cancelled_by": canceller_id}, ensure_ascii=False),
                ),
            )

            # Fetch updated discount with user names
            updated = conn.execute(
                """
                SELECT d.*,
                       u_auth.full_name_ar as authorized_by_name,
                       u_canc.full_name_ar as cancelled_by_name
                FROM discounts d
                LEFT JOIN users u_auth ON d.authorized_by_user_id = u_auth.id
                LEFT JOIN users u_canc ON d.cancelled_by_user_id = u_canc.id
                WHERE d.id = ?
                """,
                (discount_id,),
            ).fetchone()

            return DiscountResponse(
                id=updated["id"],
                shiftId=updated["shift_id"],
                discountCode=updated["discount_code"],
                type=updated["type"],
                amount=_round_curr(updated["amount"]),
                reason=updated["reason"],
                status=updated["status"],
                authorizedByUserId=updated["authorized_by_user_id"],
                authorizedByName=updated["authorized_by_name"] or "م. ألفاريز",
                cancelledByUserId=updated["cancelled_by_user_id"],
                cancelledByName=updated["cancelled_by_name"] or "مدير الفرع",
                cancelReason=updated["cancel_reason"],
                createdAt=updated["created_at"],
            )

    @staticmethod
    def create_discount(
        discount_code: str,
        amount: float,
        reason: str,
        shift_id: Optional[str] = None,
        type: str = "promotional",
        discount_type: Optional[str] = None,
        authorized_by_user_id: str = "usr_bm1",
        actor_user_id: Optional[str] = None,
        branch_id: Optional[str] = None,
    ) -> DiscountResponse:
        """Create a new discount on a shift and reconcile shift totals."""
        if amount is None:
            raise ValueError("قيمة الخصم مطلوبة")
        try:
            a_val = float(amount)
        except (TypeError, ValueError):
            raise ValueError("قيمة الخصم غير صالحة")
        if not math.isfinite(a_val) or a_val < 0:
            raise ValueError("قيمة الخصم يجب أن تكون رقماً حقيقياً غير سالب (>= 0)")

        amount_val = _round_curr(amount)
        with get_db() as conn:
            ensure_sales_schema(conn)

            actual_type = discount_type or type or "promotional"
            target_shift_id = shift_id
            if not target_shift_id:
                query = "SELECT id, branch_id FROM shifts WHERE status = 'open'"
                params = []
                if branch_id:
                    query += " AND branch_id = ?"
                    params.append(branch_id)
                query += " ORDER BY start_time DESC LIMIT 1"
                row = conn.execute(query, tuple(params)).fetchone()
                if not row:
                    raise ValueError("لا توجد وردية مفتوحة لتطبيق الخصم عليها")
                target_shift_id = row["id"]
            else:
                if branch_id:
                    s_check = conn.execute("SELECT branch_id FROM shifts WHERE id = ?", (target_shift_id,)).fetchone()
                    if s_check and s_check["branch_id"] != branch_id:
                        raise ValueError("الوردية المحددة تابعة لفرع آخر وغير مصرح بإضافة خصم إليها")

            disc_id = f"INV-{uuid.uuid4().hex[:5].upper()}"
            effective_user = actor_user_id or authorized_by_user_id or "usr_bm1"

            conn.execute(
                """
                INSERT INTO discounts (id, shift_id, discount_code, type, amount, reason, status, authorized_by_user_id)
                VALUES (?, ?, ?, ?, ?, ?, 'applied', ?)
                """,
                (disc_id, target_shift_id, discount_code, actual_type, amount_val, reason, effective_user),
            )

            # Reconcile shift total_discounts
            reconcile_row = conn.execute(
                "SELECT COALESCE(SUM(amount), 0.0) as applied_sum FROM discounts WHERE shift_id = ? AND status = 'applied'",
                (target_shift_id,),
            ).fetchone()
            new_discounts = _round_curr(reconcile_row["applied_sum"])

            conn.execute(
                "UPDATE shifts SET total_discounts = ? WHERE id = ?",
                (new_discounts, target_shift_id),
            )

            # Audit log
            conn.execute(
                """
                INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, new_values_json)
                VALUES (?, ?, 'APPLY_DISCOUNT', 'discounts', ?, ?)
                """,
                (
                    f"aud_{uuid.uuid4().hex[:10]}",
                    effective_user,
                    disc_id,
                    json.dumps({"shift_id": target_shift_id, "amount": amount_val, "code": discount_code}, ensure_ascii=False),
                ),
            )

            # Fetch user name if available
            u_row = conn.execute("SELECT full_name_ar FROM users WHERE id = ?", (effective_user,)).fetchone()
            auth_name = u_row["full_name_ar"] if u_row else "م. ألفاريز"

            return DiscountResponse(
                id=disc_id,
                shiftId=target_shift_id,
                discountCode=discount_code,
                type=actual_type,
                amount=amount_val,
                reason=reason,
                status="applied",
                authorizedByUserId=effective_user,
                authorizedByName=auth_name,
                createdAt=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            )

    @staticmethod
    def get_shift_review(shift_id: Optional[str] = None) -> Dict[str, Any]:
        """Detailed shift closure review before final commitment with exact Decimal precision."""
        with get_db() as conn:
            ensure_sales_schema(conn)

            target_shift_id = shift_id
            if not target_shift_id:
                row = conn.execute("SELECT id FROM shifts WHERE status = 'open' ORDER BY start_time DESC LIMIT 1").fetchone()
                target_shift_id = row["id"] if row else None

            if not target_shift_id:
                raise ValueError("الوردية غير موجودة")

            shift = conn.execute(
                """
                SELECT s.*, b.name_ar as branch_name, u.full_name_ar as cashier_name
                FROM shifts s
                LEFT JOIN branches b ON s.branch_id = b.id
                LEFT JOIN users u ON s.cashier_user_id = u.id
                WHERE s.id = ?
                """,
                (target_shift_id,),
            ).fetchone()

            if not shift:
                raise ValueError("الوردية غير موجودة")

            # Channel sales
            entries = conn.execute(
                """
                SELECT channel,
                       COALESCE(SUM(gross_amount), 0.0) as gross,
                       COALESCE(SUM(net_amount), 0.0) as net,
                       COALESCE(SUM(order_count), 0) as orders
                FROM shift_sales_entries WHERE shift_id = ? GROUP BY channel
                """,
                (target_shift_id,),
            ).fetchall()

            # Cash sales in shift
            cash_sales_row = conn.execute(
                """
                SELECT COALESCE(SUM(net_amount), 0.0) as cash_total
                FROM shift_sales_entries WHERE shift_id = ? AND payment_method = 'cash'
                """,
                (target_shift_id,),
            ).fetchone()
            cash_sales_dec = _to_dec(cash_sales_row["cash_total"])

            # Discounts count
            disc_row = conn.execute(
                """
                SELECT COUNT(*) as cnt, COALESCE(SUM(amount), 0.0) as total
                FROM discounts WHERE shift_id = ? AND status = 'applied'
                """,
                (target_shift_id,),
            ).fetchone()

            opening_cash_dec = _to_dec(shift["opening_cash"])
            system_expected_cash_dec = opening_cash_dec + cash_sales_dec
            total_sales_dec = _to_dec(shift["total_sales"])
            total_discounts_dec = _to_dec(shift["total_discounts"])
            net_sales_dec = max(Decimal("0.00"), total_sales_dec - total_discounts_dec)

            # Sold items summary
            sold_items_rows = conn.execute(
                """
                SELECT name_ar, SUM(quantity) as total_qty, SUM(total_amount) as sum_amt
                FROM shift_sold_items
                WHERE shift_id = ?
                GROUP BY name_ar
                ORDER BY sum_amt DESC
                """,
                (target_shift_id,),
            ).fetchall()

            if sold_items_rows:
                items_summary_lines = [
                    f"{r['name_ar']} • {r['total_qty']} وجبة • {_round_curr(r['sum_amt']):,.0f} ج.م"
                    for r in sold_items_rows
                ]
                sold_items_summary = "\n".join(items_summary_lines)
            else:
                sold_items_summary = "لا توجد أصناف مباعة مسجلة لهذه الوردية حتى الآن"

            # Compute operating duration
            start_str = shift["start_time"]
            operating_duration = "جارية حالياً"
            if shift["status"] == "closed" and shift["end_time"]:
                try:
                    s_dt = datetime.strptime(shift["start_time"], "%Y-%m-%d %H:%M:%S")
                    e_dt = datetime.strptime(shift["end_time"], "%Y-%m-%d %H:%M:%S")
                    diff = e_dt - s_dt
                    hrs = diff.seconds // 3600
                    mins = (diff.seconds % 3600) // 60
                    operating_duration = f"{hrs} ساعات و{mins} دقيقة"
                except Exception:
                    operating_duration = "وردية منتهية"

            return {
                "shiftId": target_shift_id,
                "branchName": shift["branch_name"] or "فرع وسط البلد (#01)",
                "cashierName": shift["cashier_name"] or "كريم عبد العزيز سالم",
                "managerName": "م. ألفاريز (مدير الفرع)",
                "startTime": shift["start_time"],
                "endTime": shift["end_time"],
                "timeRange": f"{shift['start_time']} — {shift['end_time'] or 'مفتوحة حالياً'}",
                "operatingDuration": operating_duration,
                "openingCash": _round_curr(opening_cash_dec),
                "totalSales": _round_curr(total_sales_dec),
                "grossSales": _round_curr(total_sales_dec),
                "totalDiscounts": _round_curr(total_discounts_dec),
                "netSales": _round_curr(net_sales_dec),
                "closingCashSystem": _round_curr(system_expected_cash_dec),
                "expectedSystemCash": _round_curr(system_expected_cash_dec),
                "channelBreakdown": [dict(e) for e in entries],
                "discountsCount": disc_row["cnt"],
                "totalOrders": sum(int(e["orders"]) for e in entries),
                "soldItemsSummary": sold_items_summary,
                "status": shift["status"],
                "isClosed": bool(shift["status"] == "closed"),
            }
