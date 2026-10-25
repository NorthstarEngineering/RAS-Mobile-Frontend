import json
import uuid
from datetime import datetime
from typing import List, Optional, Dict, Any, Tuple

from ..database.connection import get_db
from ..schemas.transfers_schemas import (
    TransferItemCreate,
    TransferItemResponse,
    TransferResponse,
    TransferMetricsResponse,
)

STATUS_LABELS_AR = {
    "pending_review": "قيد المراجعة والاعتماد",
    "approved": "معتمد ومجهز للإرسال",
    "in_transit": "بالطريق / جاهز للاستلام",
    "received": "مكتمل ومستلم",
    "rejected": "مرفوض",
}


_SEED_INITIALIZED = False


def ensure_seed_data(conn, force: bool = False) -> None:
    """Ensure baseline stock items and baseline transfers exist in SQLite per connection."""
    cur = conn.cursor()

    if not force:
        try:
            cur.execute("SELECT 1 FROM transfers WHERE transfer_code = 'TR-5540' LIMIT 1")
            if cur.fetchone():
                return
        except Exception:
            pass

    # 1. Baseline Stock Items (needed across branches for transfer testing & operations)
    default_stock = [
        # Downtown Branch (br_01)
        ("stock_br1_01", "br_01", "صدور دجاج فيليه متبلة", "CHK-MAR-BR1", "لحوم مجهزة", 70.0, "كجم", 95.0, 20.0, 100.0, "ثلاجة الفرع الرئيسية", "available"),
        ("stock_br1_02", "br_01", "صوص شيدر مدخن جاهز", "CHED-BR1", "ألبان وصوصات", 35.0, "لتر", 125.0, 15.0, 50.0, "ثلاجة الجبن", "available"),
        ("stock_br1_beef", "br_01", "لحم بقري مفروم (خام)", "RAW-BEEF-01", "لحوم", 85.0, "كجم", 160.0, 25.0, 120.0, "ثلاجة التجميد B1", "available"),
        ("stock_br1_bun", "br_01", "خبز بريوش طازج", "BUN-BRIO-01", "مخبوزات", 250.0, "قطعة", 4.5, 80.0, 500.0, "مستودع المخبوزات", "available"),
        ("stock_br1_fries", "br_01", "بطاطس جاهزة للقلي", "FRIES-BR1", "مجمدات", 60.0, "كجم", 38.0, 30.0, 100.0, "فريزر التجهيز السريع", "available"),

        # Maadi Branch (br_02)
        ("stock_br2_01", "br_02", "صدور دجاج فيليه متبلة", "CHK-MAR-BR1", "لحوم مجهزة", 15.0, "كجم", 95.0, 20.0, 60.0, "ثلاجة التبريد", "low"),
        ("stock_br2_02", "br_02", "صوص شيدر مدخن جاهز", "CHED-BR1", "ألبان وصوصات", 8.0, "لتر", 125.0, 15.0, 40.0, "ثلاجة الصوصات", "critical"),
        ("stock_br2_beef", "br_02", "لحم بقري مفروم (خام)", "RAW-BEEF-01", "لحوم", 6.0, "كجم", 160.0, 20.0, 80.0, "فريزر اللحوم", "critical"),
        ("stock_br2_bun", "br_02", "خبز بريوش طازج", "BUN-BRIO-01", "مخبوزات", 90.0, "قطعة", 4.5, 60.0, 300.0, "مستودع الخبز", "available"),

        # 5th Settlement Branch (br_03)
        ("stock_br3_01", "br_03", "صدور دجاج فيليه متبلة", "CHK-MAR-BR1", "لحوم مجهزة", 20.0, "كجم", 95.0, 20.0, 60.0, "ثلاجة الفرع", "low"),
        ("stock_br3_02", "br_03", "صوص شيدر مدخن جاهز", "CHED-BR1", "ألبان وصوصات", 25.0, "لتر", 125.0, 15.0, 40.0, "ثلاجة الفرع", "available"),
        ("stock_br3_beef", "br_03", "لحم بقري مفروم (خام)", "RAW-BEEF-01", "لحوم", 18.0, "كجم", 160.0, 20.0, 80.0, "فريزر التجميد", "low"),
        ("stock_br3_bun", "br_03", "خبز بريوش طازج", "BUN-BRIO-01", "مخبوزات", 110.0, "قطعة", 4.5, 60.0, 300.0, "مستودع الخبز", "available"),

        # Central Kitchen (br_04)
        ("stock_ck_beef", "br_04", "لحم بقري مفروم (خام)", "RAW-BEEF-01", "لحوم", 300.0, "كجم", 160.0, 50.0, 500.0, "ثلاجة التجميد الكبرى", "available"),
        ("stock_ck_chick", "br_04", "صدور دجاج فيليه متبلة", "CHK-MAR-BR1", "لحوم مجهزة", 220.0, "كجم", 95.0, 40.0, 400.0, "ثلاجة التبريد الكبرى", "available"),
        ("stock_ck_bun", "br_04", "خبز بريوش طازج", "BUN-BRIO-01", "مخبوزات", 800.0, "قطعة", 4.5, 200.0, 1500.0, "مستودع المخبوزات المركزي", "available"),
    ]

    for item in default_stock:
        cur.execute(
            """
            INSERT OR IGNORE INTO stock_items (
                id, branch_id, name, sku, category, quantity, unit, unit_cost,
                safety_stock, capacity, location, stock_level
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            item,
        )

    # 2. Baseline Transfers (matches Flutter Preview Data: TR-5540, TR-5538, TR-5532, TR-5510)
    baseline_transfers = [
        (
            "tr_preview_5540",
            "TR-5540",
            "br_01",
            "br_02",
            "pending_review",
            None,
            None,
            None,
            None,
            "طلب عاجل لتغطية عجز صدور الدجاج المتبلة قبل عطلة نهاية الأسبوع",
            "usr_bm1",
            None,
            None,
            [("stock_br1_01", 25.0)],
        ),
        (
            "tr_preview_5538",
            "TR-5538",
            "br_03",
            "br_01",
            "pending_review",
            None,
            None,
            None,
            None,
            "طلب صوص شيدر مدخن جاهز لفرع وسط البلد",
            "usr_bm1",
            None,
            None,
            [("stock_br3_02", 15.0)],
        ),
        (
            "tr_preview_5532",
            "TR-5532",
            "br_01",
            "br_02",
            "in_transit",
            "محمود سعيد",
            "01123456789",
            "11:15:00",
            None,
            "شحنة لحم بقري مفروم في سيارة نقل تبريد رقم 02",
            "usr_bm1",
            "usr_bm1",
            None,
            [("stock_br1_beef", 20.0)],
        ),
        (
            "tr_preview_5510",
            "TR-5510",
            "br_01",
            "br_03",
            "received",
            "أحمد رشوان",
            "01098765432",
            "09:00:00",
            "10:45:00",
            "تم الاستلام بالكامل وفحص درجات الحرارة",
            "usr_bm1",
            "usr_bm1",
            "usr_bm1",
            [("stock_br1_bun", 80.0)],
        ),
    ]

    for tr in baseline_transfers:
        (
            tr_id,
            code,
            src,
            dest,
            status,
            driver_name,
            driver_phone,
            dep_time,
            arr_time,
            notes,
            created_by,
            approved_by,
            received_by,
            items,
        ) = tr

        cur.execute("SELECT id FROM transfers WHERE transfer_code = ?", (code,))
        existing = cur.fetchone()
        if not existing:
            cur.execute(
                """
                INSERT INTO transfers (
                    id, transfer_code, source_branch_id, destination_branch_id, status,
                    driver_name, driver_phone, departure_time, arrival_time, notes,
                    created_by_user_id, approved_by_user_id, received_by_user_id
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    tr_id,
                    code,
                    src,
                    dest,
                    status,
                    driver_name,
                    driver_phone,
                    dep_time,
                    arr_time,
                    notes,
                    created_by,
                    approved_by,
                    received_by,
                ),
            )
            for stock_id, qty in items:
                item_id = f"tri_{uuid.uuid4().hex[:8]}"
                rec_qty = qty if status == "received" else None
                cur.execute(
                    """
                    INSERT INTO transfer_items (
                        id, transfer_id, stock_item_id, quantity, received_quantity
                    ) VALUES (?, ?, ?, ?, ?)
                    """,
                    (item_id, tr_id, stock_id, qty, rec_qty),
                )


class TransfersService:
    @staticmethod
    def _resolve_branch_id(conn, branch_input: str) -> str:
        """Resolve branch identifier by ID, code, or name."""
        cur = conn.cursor()
        # Direct ID check
        cur.execute("SELECT id FROM branches WHERE id = ?", (branch_input,))
        row = cur.fetchone()
        if row:
            return row["id"]

        # Code check (e.g., BR-01, BR-02)
        cur.execute("SELECT id FROM branches WHERE UPPER(code) = UPPER(?)", (branch_input.strip(),))
        row = cur.fetchone()
        if row:
            return row["id"]

        # Substring / number search (e.g. '01', '#01', 'وسط البلد')
        clean_input = branch_input.strip()
        cur.execute(
            """
            SELECT id FROM branches
            WHERE name_ar LIKE ? OR name_en LIKE ? OR code LIKE ?
            LIMIT 1
            """,
            (f"%{clean_input}%", f"%{clean_input}%", f"%{clean_input}%"),
        )
        row = cur.fetchone()
        if row:
            return row["id"]

        # Fallback regex-like search for branch numbers: #01 -> BR-01, #02 -> BR-02
        for num in ["01", "02", "03", "04"]:
            if num in branch_input:
                cur.execute("SELECT id FROM branches WHERE code LIKE ?", (f"%{num}",))
                row = cur.fetchone()
                if row:
                    return row["id"]

        raise ValueError(f"الفرع غير موجود: {branch_input}")

    @classmethod
    def _resolve_branch_id_safe(cls, branch_input: str) -> str:
        """Resolve branch id using isolated connection without side effects."""
        with get_db() as conn:
            return cls._resolve_branch_id(conn, branch_input)

    @staticmethod
    def _resolve_stock_item(conn, branch_id: str, stock_item_id: Optional[str], sku: Optional[str], item_name: Optional[str]):
        """Find corresponding stock_items row for the branch canonically (never map cross-branch)."""
        cur = conn.cursor()
        if stock_item_id:
            cur.execute("SELECT * FROM stock_items WHERE id = ? AND branch_id = ?", (stock_item_id, branch_id))
            row = cur.fetchone()
            if row:
                return row

            # If stock_item_id was passed from another branch or old client resolution, resolve its SKU
            cur.execute("SELECT sku FROM stock_items WHERE id = ?", (stock_item_id,))
            id_row = cur.fetchone()
            if id_row and id_row["sku"]:
                cur.execute("SELECT * FROM stock_items WHERE sku = ? AND branch_id = ?", (id_row["sku"], branch_id))
                row = cur.fetchone()
                if row:
                    return row

        if sku:
            cur.execute("SELECT * FROM stock_items WHERE UPPER(sku) = UPPER(?) AND branch_id = ?", (sku.strip(), branch_id))
            row = cur.fetchone()
            if row:
                return row

        if item_name:
            cur.execute(
                "SELECT * FROM stock_items WHERE branch_id = ? AND (name = ? OR name LIKE ?)",
                (branch_id, item_name.strip(), f"%{item_name.strip()}%"),
            )
            row = cur.fetchone()
            if row:
                return row

        # If not present in this branch's inventory, return None (do NOT return item from another branch!)
        return None

    @staticmethod
    def _row_to_transfer_response(conn, row) -> TransferResponse:
        """Convert a transfers row with joins into TransferResponse with live balances."""
        cur = conn.cursor()
        transfer_id = row["id"]
        dest_branch_id = row["destination_branch_id"]

        # Fetch items
        cur.execute(
            """
            SELECT 
                ti.id, ti.transfer_id, ti.stock_item_id, ti.quantity, ti.received_quantity,
                si.name, si.sku, si.category, si.unit, si.unit_cost, si.quantity as current_source_qty
            FROM transfer_items ti
            LEFT JOIN stock_items si ON ti.stock_item_id = si.id
            WHERE ti.transfer_id = ?
            """,
            (transfer_id,),
        )
        item_rows = cur.fetchall()

        items_resp: List[TransferItemResponse] = []
        total_qty = 0.0
        first_src_balance: Optional[float] = None
        first_dest_balance: Optional[float] = None

        for ir in item_rows:
            qty = float(ir["quantity"])
            total_qty += qty
            src_qty = float(ir["current_source_qty"]) if ir["current_source_qty"] is not None else None

            # Live balance at destination branch for this SKU
            dest_qty: Optional[float] = None
            if ir["sku"] and dest_branch_id:
                cur.execute(
                    "SELECT quantity FROM stock_items WHERE branch_id = ? AND sku = ?",
                    (dest_branch_id, ir["sku"]),
                )
                dest_row = cur.fetchone()
                if dest_row is not None:
                    dest_qty = float(dest_row["quantity"])
                else:
                    dest_qty = 0.0

            if first_src_balance is None and src_qty is not None:
                first_src_balance = src_qty
            if first_dest_balance is None and dest_qty is not None:
                first_dest_balance = dest_qty

            items_resp.append(
                TransferItemResponse(
                    id=ir["id"],
                    transferId=ir["transfer_id"],
                    stockItemId=ir["stock_item_id"] or "",
                    name=ir["name"] or "صنف غير محدد",
                    sku=ir["sku"] or "SKU-UNKNOWN",
                    category=ir["category"] or "عام",
                    unit=ir["unit"] or "وحدة",
                    quantity=qty,
                    receivedQuantity=float(ir["received_quantity"]) if ir["received_quantity"] is not None else None,
                    unitCost=float(ir["unit_cost"] or 0.0),
                    availableQuantityAtSource=src_qty,
                    availableQuantityAtDestination=dest_qty,
                )
            )

        status_code = row["status"]
        status_label = STATUS_LABELS_AR.get(status_code, status_code)

        return TransferResponse(
            id=row["id"],
            transferCode=row["transfer_code"],
            sourceBranchId=row["source_branch_id"],
            sourceBranchName=row["source_branch_name"] or "فرع غير معروف",
            sourceBranchCode=row["source_branch_code"],
            destinationBranchId=row["destination_branch_id"],
            destinationBranchName=row["destination_branch_name"] or "فرع غير معروف",
            destinationBranchCode=row["destination_branch_code"],
            status=status_code,
            statusLabelAr=status_label,
            driverName=row["driver_name"],
            driverPhone=row["driver_phone"],
            departureTime=row["departure_time"],
            arrivalTime=row["arrival_time"],
            notes=row["notes"],
            createdByUserId=row["created_by_user_id"],
            createdByName=row["creator_name"] or "مسؤول التشغيل",
            approvedByUserId=row["approved_by_user_id"],
            approvedByName=row["approver_name"],
            receivedByUserId=row["received_by_user_id"],
            receivedByName=row["receiver_name"],
            items=items_resp,
            itemsCount=len(items_resp),
            totalQuantity=total_qty,
            sourceBalance=first_src_balance,
            destinationBalance=first_dest_balance,
            createdAt=str(row["created_at"]),
            updatedAt=str(row["updated_at"]),
        )

    @classmethod
    def get_transfers(
        cls,
        status: Optional[str] = None,
        source_branch_id: Optional[str] = None,
        destination_branch_id: Optional[str] = None,
        branch_id: Optional[str] = None,
        search: Optional[str] = None,
        limit: int = 100,
        offset: int = 0,
    ) -> List[TransferResponse]:
        """Fetch transfer orders with filtering and search (zero seed mutation)."""
        with get_db() as conn:
            cur = conn.cursor()

            query = """
                SELECT 
                    t.*,
                    sb.name_ar as source_branch_name, sb.code as source_branch_code,
                    db.name_ar as destination_branch_name, db.code as destination_branch_code,
                    uc.full_name_ar as creator_name,
                    ua.full_name_ar as approver_name,
                    ur.full_name_ar as receiver_name
                FROM transfers t
                LEFT JOIN branches sb ON t.source_branch_id = sb.id
                LEFT JOIN branches db ON t.destination_branch_id = db.id
                LEFT JOIN users uc ON t.created_by_user_id = uc.id
                LEFT JOIN users ua ON t.approved_by_user_id = ua.id
                LEFT JOIN users ur ON t.received_by_user_id = ur.id
                WHERE 1=1
            """
            params: List[Any] = []

            if status:
                query += " AND t.status = ?"
                params.append(status.strip())

            if source_branch_id:
                query += " AND t.source_branch_id = ?"
                params.append(source_branch_id.strip())

            if destination_branch_id:
                query += " AND t.destination_branch_id = ?"
                params.append(destination_branch_id.strip())

            if branch_id:
                query += " AND (t.source_branch_id = ? OR t.destination_branch_id = ?)"
                params.extend([branch_id.strip(), branch_id.strip()])

            if search:
                pattern = f"%{search.strip()}%"
                query += """ AND (
                    t.transfer_code LIKE ? OR 
                    t.notes LIKE ? OR 
                    t.driver_name LIKE ? OR 
                    sb.name_ar LIKE ? OR 
                    db.name_ar LIKE ?
                )"""
                params.extend([pattern, pattern, pattern, pattern, pattern])

            query += " ORDER BY t.created_at DESC LIMIT ? OFFSET ?"
            params.extend([limit, offset])

            cur.execute(query, params)
            rows = cur.fetchall()

            return [cls._row_to_transfer_response(conn, r) for r in rows]

    @classmethod
    def get_transfer_by_id(cls, transfer_id_or_code: str) -> TransferResponse:
        """Fetch single transfer order by primary key ID or transfer_code (zero seed mutation)."""
        with get_db() as conn:
            cur = conn.cursor()

            query = """
                SELECT 
                    t.*,
                    sb.name_ar as source_branch_name, sb.code as source_branch_code,
                    db.name_ar as destination_branch_name, db.code as destination_branch_code,
                    uc.full_name_ar as creator_name,
                    ua.full_name_ar as approver_name,
                    ur.full_name_ar as receiver_name
                FROM transfers t
                LEFT JOIN branches sb ON t.source_branch_id = sb.id
                LEFT JOIN branches db ON t.destination_branch_id = db.id
                LEFT JOIN users uc ON t.created_by_user_id = uc.id
                LEFT JOIN users ua ON t.approved_by_user_id = ua.id
                LEFT JOIN users ur ON t.received_by_user_id = ur.id
                WHERE t.id = ? OR t.transfer_code = ?
                LIMIT 1
            """
            cur.execute(query, (transfer_id_or_code, transfer_id_or_code))
            row = cur.fetchone()
            if not row:
                raise ValueError(f"إذن التحويل غير موجود: {transfer_id_or_code}")

            return cls._row_to_transfer_response(conn, row)

    @classmethod
    def get_transfer_metrics(cls, branch_id: Optional[str] = None) -> TransferMetricsResponse:
        """Aggregate counts for transfers dashboard metrics (zero seed mutation)."""
        with get_db() as conn:
            cur = conn.cursor()

            where_clause = ""
            params: List[Any] = []
            if branch_id:
                where_clause = " WHERE (source_branch_id = ? OR destination_branch_id = ?)"
                params = [branch_id, branch_id]

            cur.execute(f"SELECT status, COUNT(*) FROM transfers{where_clause} GROUP BY status", params)
            counts = {r[0]: r[1] for r in cur.fetchall()}

            pending = counts.get("pending_review", 0)
            in_transit = counts.get("in_transit", 0)
            received = counts.get("received", 0)
            total = sum(counts.values())

            return TransferMetricsResponse(
                pendingReviewCount=pending,
                inTransitCount=in_transit,
                receivedCount=received,
                totalTransfers=total,
            )

    @classmethod
    def get_branches(cls) -> List[Dict[str, Any]]:
        """List all active operational branches dynamically from SQLite."""
        with get_db() as conn:
            cur = conn.cursor()
            cur.execute(
                """
                SELECT id, name_ar, name_en, code, type
                FROM branches 
                WHERE is_active = 1 
                ORDER BY code ASC
                """
            )
            return [dict(r) for r in cur.fetchall()]

    @classmethod
    def get_available_items(cls, branch_id: str) -> List[Dict[str, Any]]:
        """List all available items for a branch with actual SQLite stock balances."""
        with get_db() as conn:
            cur = conn.cursor()
            resolved_branch = cls._resolve_branch_id(conn, branch_id)
            cur.execute(
                """
                SELECT id, name, sku, category, quantity, unit, unit_cost, safety_stock, location, stock_level
                FROM stock_items 
                WHERE branch_id = ? AND quantity > 0
                ORDER BY name ASC
                """,
                (resolved_branch,)
            )
            return [dict(r) for r in cur.fetchall()]

    @classmethod
    def create_transfer(
        cls,
        source_branch_id: str,
        destination_branch_id: str,
        items: List[TransferItemCreate],
        transfer_code: Optional[str] = None,
        notes: Optional[str] = None,
        is_urgent: bool = False,
        created_by_user_id: str = "usr_bm1",
    ) -> TransferResponse:
        """
        Create a new inter-branch transfer request in pending_review status.
        Validates branch existence, items existence, and sufficient source branch stock.
        """
        with get_db() as conn:
            cur = conn.cursor()

            src_id = cls._resolve_branch_id(conn, source_branch_id)
            dest_id = cls._resolve_branch_id(conn, destination_branch_id)

            if src_id == dest_id:
                raise ValueError("لا يمكن إجراء تحويل بين نفس الفرع (الفرع المصدر والمستلم متطابقان)")

            if not items:
                raise ValueError("يجب تحديد صنف واحد على الأقل في إذن التحويل")

            # Check creator user
            cur.execute("SELECT id FROM users WHERE id = ?", (created_by_user_id,))
            if not cur.fetchone():
                created_by_user_id = "usr_bm1"

            # Generate transfer code if missing
            if not transfer_code:
                cur.execute("SELECT COUNT(*) FROM transfers")
                next_num = 5540 + cur.fetchone()[0] + 1
                transfer_code = f"TR-{next_num}"
            else:
                transfer_code = transfer_code.strip()
                cur.execute("SELECT id FROM transfers WHERE transfer_code = ?", (transfer_code,))
                if cur.fetchone():
                    raise ValueError(f"كود التحويل {transfer_code} مستخدم بالفعل")

            transfer_id = f"tr_{uuid.uuid4().hex[:10]}"
            full_notes = notes or ""
            if is_urgent:
                full_notes = f"[عاجل] {full_notes}".strip()

            now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

            # Validate each item and check available stock at source
            validated_items = []
            for itm in items:
                if itm.quantity <= 0:
                    raise ValueError("كمية التحويل يجب أن تكون أكبر من الصفر")

                stock_row = cls._resolve_stock_item(conn, src_id, itm.stock_item_id, itm.sku, itm.item_name)
                if not stock_row:
                    raise ValueError(f"الصنف المطلوب غير مسجل في النظام: {itm.item_name or itm.sku or itm.stock_item_id}")

                available_qty = float(stock_row["quantity"])
                if available_qty < itm.quantity:
                    raise ValueError(
                        f"رصيد الصنف '{stock_row['name']}' غير كافٍ في الفرع المصدر: "
                        f"المتاح {available_qty} {stock_row['unit']} والمطلوب {itm.quantity} {stock_row['unit']}"
                    )

                validated_items.append((stock_row["id"], itm.quantity))

            # Insert transfer header
            cur.execute(
                """
                INSERT INTO transfers (
                    id, transfer_code, source_branch_id, destination_branch_id, status,
                    driver_name, driver_phone, departure_time, arrival_time, notes,
                    created_by_user_id, approved_by_user_id, received_by_user_id,
                    created_at, updated_at
                ) VALUES (?, ?, ?, ?, 'pending_review', NULL, NULL, NULL, NULL, ?, ?, NULL, NULL, ?, ?)
                """,
                (
                    transfer_id,
                    transfer_code,
                    src_id,
                    dest_id,
                    full_notes,
                    created_by_user_id,
                    now_str,
                    now_str,
                ),
            )

            # Insert transfer items
            for stock_id, qty in validated_items:
                tri_id = f"tri_{uuid.uuid4().hex[:8]}"
                cur.execute(
                    """
                    INSERT INTO transfer_items (
                        id, transfer_id, stock_item_id, quantity, received_quantity
                    ) VALUES (?, ?, ?, ?, NULL)
                    """,
                    (tri_id, transfer_id, stock_id, qty),
                )

            # Audit log
            audit_id = f"aud_{uuid.uuid4().hex[:8]}"
            cur.execute(
                """
                INSERT INTO audit_logs (
                    id, user_id, branch_id, action, entity_type, entity_id, new_values_json, timestamp
                ) VALUES (?, ?, ?, 'TRANSFER_CREATE', 'transfer', ?, ?, ?)
                """,
                (
                    audit_id,
                    created_by_user_id,
                    src_id,
                    transfer_id,
                    json.dumps({"transfer_code": transfer_code, "status": "pending_review", "items_count": len(validated_items)}),
                    now_str,
                ),
            )

        return cls.get_transfer_by_id(transfer_id)

    @classmethod
    def review_transfer(
        cls,
        transfer_id: str,
        approved: bool = True,
        decision: Optional[str] = "approved",
        notes: Optional[str] = None,
        reviewed_by_user_id: str = "usr_bm1",
        approved_quantities: Optional[Dict[str, float]] = None,
    ) -> TransferResponse:
        """
        Review and approve or reject a transfer in pending_review status.
        Supports adjusting item quantities upon approval.
        """
        with get_db() as conn:
            cur = conn.cursor()

            cur.execute("SELECT * FROM transfers WHERE id = ? OR transfer_code = ?", (transfer_id, transfer_id))
            transfer = cur.fetchone()
            if not transfer:
                raise ValueError(f"إذن التحويل غير موجود: {transfer_id}")

            if transfer["status"] != "pending_review":
                raise ValueError(f"لا يمكن مراجعة الإذن في حالته الحالية: {transfer['status']} (يجب أن يكون 'قيد المراجعة')")

            now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            is_approve = approved and decision != "rejected"

            if is_approve:
                # Update item quantities if adjustments were passed
                if approved_quantities:
                    for item_ref, new_qty in approved_quantities.items():
                        if float(new_qty) <= 0:
                            raise ValueError(f"الكمية المعتمدة يجب أن تكون موجبة: {new_qty}")
                        cur.execute(
                            """
                            UPDATE transfer_items 
                            SET quantity = ? 
                            WHERE transfer_id = ? AND (id = ? OR stock_item_id = ? OR (SELECT COUNT(*) FROM transfer_items WHERE transfer_id = ?) = 1)
                            """,
                            (float(new_qty), transfer["id"], item_ref, item_ref, transfer["id"]),
                        )

                combined_notes = transfer["notes"] or ""
                if notes:
                    combined_notes = f"{combined_notes} | [ملاحظات الاعتماد]: {notes}".strip(" | ")

                cur.execute(
                    """
                    UPDATE transfers SET
                        status = 'approved',
                        approved_by_user_id = ?,
                        notes = ?,
                        updated_at = ?
                    WHERE id = ? AND status = 'pending_review'
                    """,
                    (reviewed_by_user_id, combined_notes, now_str, transfer["id"]),
                )
                if cur.rowcount == 0:
                    raise ValueError("تعذر اعتماد التحويل: حالة التحويل تغيرت بالفعل أو لم يعد قيد المراجعة")

                audit_action = "TRANSFER_REVIEW_APPROVED"
            else:
                combined_notes = transfer["notes"] or ""
                reject_reason = notes or "تم الرفض بواسطة الإدارة"
                combined_notes = f"{combined_notes} | [سبب الرفض]: {reject_reason}".strip(" | ")

                cur.execute(
                    """
                    UPDATE transfers SET
                        status = 'rejected',
                        approved_by_user_id = ?,
                        notes = ?,
                        updated_at = ?
                    WHERE id = ? AND status = 'pending_review'
                    """,
                    (reviewed_by_user_id, combined_notes, now_str, transfer["id"]),
                )
                if cur.rowcount == 0:
                    raise ValueError("تعذر رفض التحويل: حالة التحويل تغيرت بالفعل أو لم يعد قيد المراجعة")

                audit_action = "TRANSFER_REVIEW_REJECTED"

            # Write Audit log
            audit_id = f"aud_{uuid.uuid4().hex[:8]}"
            cur.execute(
                """
                INSERT INTO audit_logs (
                    id, user_id, branch_id, action, entity_type, entity_id, new_values_json, timestamp
                ) VALUES (?, ?, ?, ?, 'transfer', ?, ?, ?)
                """,
                (
                    audit_id,
                    reviewed_by_user_id,
                    transfer["source_branch_id"],
                    audit_action,
                    transfer["id"],
                    json.dumps({"status": "approved" if is_approve else "rejected", "notes": notes}),
                    now_str,
                ),
            )

        return cls.get_transfer_by_id(transfer["id"])

    @classmethod
    def send_transfer(
        cls,
        transfer_id: str,
        driver_name: str,
        driver_phone: Optional[str] = None,
        departure_time: Optional[str] = None,
        vehicle: Optional[str] = None,
        notes: Optional[str] = None,
        sent_by_user_id: str = "usr_bm1",
        temperature: Optional[str] = None,
    ) -> TransferResponse:
        """
        Record transfer shipment and driver details.
        Enforces status == 'approved' (zero auto-approval from pending_review).
        Applies ACID Transaction with atomic conditional update in SQLite:
        - Atomically verifies status is 'approved' and updates to 'in_transit'.
        - Verifies stock levels in source branch.
        - Deducts quantities atomically from source branch stock_items.
        - Updates stock levels (available/low/critical).
        - Inserts stock_movements (transfer).
        - If any check fails, rolls back entire transaction completely.
        """
        with get_db() as conn:
            cur = conn.cursor()

            # 1. Fetch Transfer
            cur.execute(
                """
                SELECT t.*, sb.name_ar as src_name, db.name_ar as dest_name 
                FROM transfers t
                LEFT JOIN branches sb ON t.source_branch_id = sb.id
                LEFT JOIN branches db ON t.destination_branch_id = db.id
                WHERE t.id = ? OR t.transfer_code = ?
                """,
                (transfer_id, transfer_id),
            )
            transfer = cur.fetchone()
            if not transfer:
                raise ValueError(f"إذن التحويل غير موجود: {transfer_id}")

            if transfer["status"] != "approved":
                raise ValueError(
                    f"لا يمكن شحن التحويل في حالته الحالية: '{transfer['status']}' (يجب أن يكون 'approved' ومراجعاً مسبقاً)"
                )

            now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            dep_time_val = departure_time or datetime.now().strftime("%I:%M %p")

            # 2. Atomic conditional status check & update
            combined_notes = transfer["notes"] or ""
            info_parts = []
            if vehicle:
                info_parts.append(f"المركبة: {vehicle}")
            if temperature:
                info_parts.append(f"الحرارة: {temperature}")
            if notes:
                info_parts.append(notes)
            if info_parts:
                combined_notes = f"{combined_notes} | [بيانات النقل]: {', '.join(info_parts)}".strip(" | ")

            cur.execute(
                """
                UPDATE transfers SET
                    status = 'in_transit',
                    driver_name = ?,
                    driver_phone = ?,
                    departure_time = ?,
                    notes = ?,
                    updated_at = ?
                WHERE (id = ? OR transfer_code = ?) AND status = 'approved'
                """,
                (
                    driver_name.strip(),
                    driver_phone.strip() if driver_phone else None,
                    dep_time_val,
                    combined_notes,
                    now_str,
                    transfer["id"],
                    transfer["id"],
                ),
            )
            if cur.rowcount == 0:
                raise ValueError("فشل إرسال الشحنة: تم شحن التحويل بالفعل أو تغيرت حالته (نزاع تزامني)")

            # 3. Fetch items
            cur.execute("SELECT * FROM transfer_items WHERE transfer_id = ?", (transfer["id"],))
            items = cur.fetchall()
            if not items:
                raise ValueError("لا توجد أصناف مسجلة في إذن التحويل للشحن")

            # 4. Atomically check and deduct stock for each item in source branch
            for itm in items:
                cur.execute(
                    "SELECT * FROM stock_items WHERE id = ? AND branch_id = ?",
                    (itm["stock_item_id"], transfer["source_branch_id"]),
                )
                stock = cur.fetchone()
                if not stock:
                    raise ValueError(f"الصنف {itm['stock_item_id']} غير موجود بمخزون الفرع المصدر")

                req_qty = float(itm["quantity"])
                current_qty = float(stock["quantity"])
                if current_qty < req_qty:
                    raise ValueError(
                        f"رصيد غير كافٍ للصنف '{stock['name']}' ({stock['sku']}) بمخزن المصدر: "
                        f"المتاح {current_qty} {stock['unit']} والمطلوب خصمه {req_qty} {stock['unit']}"
                    )

                new_qty = round(current_qty - req_qty, 3)
                safety = float(stock["safety_stock"] or 0.0)
                new_level = "critical" if new_qty <= safety * 0.5 else ("low" if new_qty <= safety else "available")

                cur.execute(
                    """
                    UPDATE stock_items 
                    SET quantity = ?, stock_level = ?, updated_at = ? 
                    WHERE id = ?
                    """,
                    (new_qty, new_level, now_str, stock["id"]),
                )

                # Insert stock movement
                mov_id = f"mov_{uuid.uuid4().hex[:8]}"
                mov_code = f"MOV-TR-OUT-{uuid.uuid4().hex[:6].upper()}"
                desc = f"خصم إرسال شحنة تحويل {transfer['transfer_code']} إلى {transfer['dest_name']}"
                cur.execute(
                    """
                    INSERT INTO stock_movements (\n                        id, code, stock_item_id, branch_id, movement_type, quantity, balance_after, description, created_by_user_id, created_at\n                    ) VALUES (?, ?, ?, ?, 'transfer', ?, ?, ?, ?, ?)\n                    """,
                    (
                        mov_id,
                        mov_code,
                        stock["id"],
                        transfer["source_branch_id"],
                        -req_qty,
                        new_qty,
                        desc,
                        sent_by_user_id,
                        now_str,
                    ),
                )

            # 5. Audit Log
            audit_id = f"aud_{uuid.uuid4().hex[:8]}"
            cur.execute(
                """
                INSERT INTO audit_logs (
                    id, user_id, branch_id, action, entity_type, entity_id, new_values_json, timestamp
                ) VALUES (?, ?, ?, 'TRANSFER_SENT', 'transfer', ?, ?, ?)
                """,
                (
                    audit_id,
                    sent_by_user_id,
                    transfer["source_branch_id"],
                    transfer["id"],
                    json.dumps({
                        "status": "in_transit",
                        "driver_name": driver_name,
                        "driver_phone": driver_phone,
                        "departure_time": dep_time_val,
                    }, ensure_ascii=False),
                    now_str,
                ),
            )

        return cls.get_transfer_by_id(transfer["id"])

    @classmethod
    def receive_transfer(
        cls,
        transfer_id: str,
        received_by_user_id: str = "usr_bm1",
        arrival_time: Optional[str] = None,
        received_items: Optional[List[Dict[str, Any]]] = None,
        has_damage: bool = False,
        damage_notes: Optional[str] = None,
        notes: Optional[str] = None,
    ) -> TransferResponse:
        """
        Confirm receipt of transfer shipment at destination branch.
        Applies ACID Transaction with atomic conditional update in SQLite:
        - Conditionally updates status from 'in_transit' to 'received'.
        - Updates received quantities in transfer_items.
        - Deposits stock into destination branch stock_items.
        - Records single stock_movement (receipt) with zero double movements.
        - Preserves damage notes and partial receipt.
        """
        with get_db() as conn:
            cur = conn.cursor()

            # 1. Fetch transfer
            cur.execute(
                """
                SELECT t.*, sb.name_ar as src_name, db.name_ar as dest_name 
                FROM transfers t
                LEFT JOIN branches sb ON t.source_branch_id = sb.id
                LEFT JOIN branches db ON t.destination_branch_id = db.id
                WHERE t.id = ? OR t.transfer_code = ?
                """,
                (transfer_id, transfer_id),
            )
            transfer = cur.fetchone()
            if not transfer:
                raise ValueError(f"إذن التحويل غير موجود: {transfer_id}")

            if transfer["status"] != "in_transit":
                raise ValueError(
                    f"لا يمكن تأكيد استلام الشحنة في حالتها الحالية: '{transfer['status']}' (يجب أن تكون 'in_transit')"
                )

            now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            arr_time_val = arrival_time or datetime.now().strftime("%I:%M %p")

            # 2. Atomic conditional status check & update
            combined_notes = transfer["notes"] or ""
            info_parts = []
            if has_damage:
                info_parts.append(f"تلف/عجز: {damage_notes or 'تم رصد تلف أثناء النقل'}")
            if notes:
                info_parts.append(notes)
            if info_parts:
                combined_notes = f"{combined_notes} | [محضر الاستلام]: {', '.join(info_parts)}".strip(" | ")

            cur.execute(
                """
                UPDATE transfers SET
                    status = 'received',
                    received_by_user_id = ?,
                    arrival_time = ?,
                    notes = ?,
                    updated_at = ?
                WHERE (id = ? OR transfer_code = ?) AND status = 'in_transit'
                """,
                (
                    received_by_user_id,
                    arr_time_val,
                    combined_notes,
                    now_str,
                    transfer["id"],
                    transfer["id"],
                ),
            )
            if cur.rowcount == 0:
                raise ValueError("فشل تأكيد الاستلام: تم استلام الشحنة بالفعل أو تغيرت حالتها (نزاع تزامني)")

            # 3. Fetch items
            cur.execute("SELECT * FROM transfer_items WHERE transfer_id = ?", (transfer["id"],))
            items = cur.fetchall()
            if not items:
                raise ValueError("لا توجد أصناف لتأكيد استلامها")

            # Map received quantities from payload if supplied
            rec_map: Dict[str, float] = {}
            if received_items:
                for ri in received_items:
                    ref_key = ri.get("stock_item_id") or ri.get("stockItemId") or ri.get("item_id") or ri.get("id") or ri.get("sku")
                    qty_val = ri.get("received_quantity") if "received_quantity" in ri else ri.get("receivedQuantity")
                    if ref_key and qty_val is not None:
                        rec_map[str(ref_key)] = float(qty_val)
                if len(items) == 1 and len(received_items) == 1:
                    single_val = received_items[0].get("received_quantity") if "received_quantity" in received_items[0] else received_items[0].get("receivedQuantity")
                    if single_val is not None:
                        rec_map[items[0]["id"]] = float(single_val)
                        rec_map[items[0]["stock_item_id"]] = float(single_val)

            # 4. For each item, update received quantity and deposit to destination stock
            for itm in items:
                # Determine received qty: explicit or default to sent quantity
                rec_qty = rec_map.get(itm["id"], rec_map.get(itm["stock_item_id"], float(itm["quantity"])))
                import math
                if not math.isfinite(rec_qty) or rec_qty < 0:
                    raise ValueError("الكمية المستلمة يجب أن تكون قيمة عددية موجبة أو صفر (finite non-negative)")

                sent_qty = float(itm["quantity"])
                if rec_qty > sent_qty:
                    raise ValueError(f"الكمية المستلمة ({rec_qty}) لا يمكن أن تتجاوز الكمية المشحونة ({sent_qty}) للصنف '{itm['stock_item_id']}'")

                cur.execute(
                    "UPDATE transfer_items SET received_quantity = ? WHERE id = ?",
                    (rec_qty, itm["id"]),
                )

                # Fetch source stock item details
                cur.execute("SELECT * FROM stock_items WHERE id = ?", (itm["stock_item_id"],))
                source_item = cur.fetchone()
                if not source_item:
                    raise ValueError(f"بيانات صنف المصدر {itm['stock_item_id']} مفقودة")

                # Find matching stock item in destination branch by SKU
                cur.execute(
                    "SELECT * FROM stock_items WHERE branch_id = ? AND sku = ?",
                    (transfer["destination_branch_id"], source_item["sku"]),
                )
                dest_stock = cur.fetchone()

                if dest_stock:
                    dest_stock_id = dest_stock["id"]
                    old_qty = round(float(dest_stock["quantity"]), 3)
                    new_qty = round(old_qty + rec_qty, 3)
                    safety = float(dest_stock["safety_stock"] or source_item["safety_stock"] or 0.0)
                    new_level = "critical" if new_qty <= safety * 0.5 else ("low" if new_qty <= safety else "available")

                    cur.execute(
                        """
                        UPDATE stock_items 
                        SET quantity = ?, stock_level = ?, updated_at = ? 
                        WHERE id = ?
                        """,
                        (new_qty, new_level, now_str, dest_stock_id),
                    )
                else:
                    dest_stock_id = f"stock_{transfer['destination_branch_id']}_{source_item['sku'].replace('-', '_').lower()}"
                    old_qty = 0.0
                    new_qty = rec_qty
                    safety = float(source_item["safety_stock"] or 0.0)
                    new_level = "critical" if new_qty <= safety * 0.5 else ("low" if new_qty <= safety else "available")

                    cur.execute(
                        """
                        INSERT INTO stock_items (
                            id, branch_id, name, sku, category, quantity, unit, unit_cost,
                            safety_stock, capacity, location, stock_level, updated_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            dest_stock_id,
                            transfer["destination_branch_id"],
                            source_item["name"],
                            source_item["sku"],
                            source_item["category"],
                            new_qty,
                            source_item["unit"],
                            source_item["unit_cost"],
                            safety,
                            source_item["capacity"],
                            f"مستودع فرع {transfer['dest_name']}",
                            new_level,
                            now_str,
                        ),
                    )

                # Record stock movements with correct ledger balance continuity and no double counting:
                damaged_qty = round(sent_qty - rec_qty, 3)
                if damaged_qty > 0:
                    # 1. Gross receipt movement (dispatched gross quantity into destination receiving)
                    intermediate_balance = round(old_qty + sent_qty, 3)
                    mov_id = f"mov_{uuid.uuid4().hex[:8]}"
                    mov_code = f"MOV-TR-IN-{uuid.uuid4().hex[:6].upper()}"
                    desc = f"استلام شحنة تحويل {transfer['transfer_code']} من {transfer['src_name']}"
                    cur.execute(
                        """
                        INSERT INTO stock_movements (
                            id, code, stock_item_id, branch_id, movement_type, quantity, balance_after, description, created_by_user_id, created_at
                        ) VALUES (?, ?, ?, ?, 'receipt', ?, ?, ?, ?, ?)
                        """,
                        (
                            mov_id,
                            mov_code,
                            dest_stock_id,
                            transfer["destination_branch_id"],
                            sent_qty,
                            intermediate_balance,
                            desc,
                            received_by_user_id,
                            now_str,
                        ),
                    )

                    # 2. Damage adjustment movement within same atomic transaction (final balance matches physical stock)
                    mov_adj_id = f"mov_{uuid.uuid4().hex[:8]}"
                    mov_adj_code = f"MOV-ADJ-{uuid.uuid4().hex[:6].upper()}"
                    d_notes = (
                        damage_notes
                        or ("تلف وعجز أثناء النقل" if has_damage else "عجز في الكمية المستلمة")
                    ).strip()
                    adj_desc = (
                        f"تسوية عجز/تلف شحنة تحويل {transfer['transfer_code']} "
                        f"[REASON:DAMAGE_IN_TRANSIT] {d_notes}"
                    )
                    cur.execute(
                        """
                        INSERT INTO stock_movements (
                            id, code, stock_item_id, branch_id, movement_type, quantity, balance_after, description, created_by_user_id, created_at
                        ) VALUES (?, ?, ?, ?, 'adjustment', ?, ?, ?, ?, ?)
                        """,
                        (
                            mov_adj_id,
                            mov_adj_code,
                            dest_stock_id,
                            transfer["destination_branch_id"],
                            -damaged_qty,
                            new_qty,
                            adj_desc,
                            received_by_user_id,
                            now_str,
                        ),
                    )
                else:
                    # Clean single receipt movement when undamaged
                    mov_id = f"mov_{uuid.uuid4().hex[:8]}"
                    mov_code = f"MOV-TR-IN-{uuid.uuid4().hex[:6].upper()}"
                    desc = f"استلام وإيداع شحنة تحويل {transfer['transfer_code']} من {transfer['src_name']}"
                    cur.execute(
                        """
                        INSERT INTO stock_movements (
                            id, code, stock_item_id, branch_id, movement_type, quantity, balance_after, description, created_by_user_id, created_at
                        ) VALUES (?, ?, ?, ?, 'receipt', ?, ?, ?, ?, ?)
                        """,
                        (
                            mov_id,
                            mov_code,
                            dest_stock_id,
                            transfer["destination_branch_id"],
                            rec_qty,
                            new_qty,
                            desc,
                            received_by_user_id,
                            now_str,
                        ),
                    )

            # 5. Write audit log
            audit_id = f"aud_{uuid.uuid4().hex[:8]}"
            cur.execute(
                """
                INSERT INTO audit_logs (
                    id, user_id, branch_id, action, entity_type, entity_id, new_values_json, timestamp
                ) VALUES (?, ?, ?, 'TRANSFER_RECEIVED', 'transfer', ?, ?, ?)
                """,
                (
                    audit_id,
                    received_by_user_id,
                    transfer["destination_branch_id"],
                    transfer["id"],
                    json.dumps({
                        "status": "received",
                        "has_damage": has_damage,
                        "damage_notes": damage_notes,
                        "arrival_time": arr_time_val,
                    }, ensure_ascii=False),
                    now_str,
                ),
            )

        return cls.get_transfer_by_id(transfer["id"])
