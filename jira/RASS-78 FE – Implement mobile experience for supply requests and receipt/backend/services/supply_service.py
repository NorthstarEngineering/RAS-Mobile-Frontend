import json
import sqlite3
import uuid
from datetime import datetime
from typing import Dict, List, Optional, Any, Tuple

from ..database.connection import get_db
from ..schemas.supply_schemas import (
    SupplyOrderCreate,
    SupplyOrderResponse,
    SupplyOrderItemResponse,
    ExecuteSupplyOrderRequest,
    ReceiveSupplyOrderRequest,
)

STATUS_AR_MAP: Dict[str, str] = {
    "draft": "مسودة",
    "pending": "قيد المراجعة",
    "preparing": "قيد التجهيز",
    "in_transit": "قيد الشحن",
    "received": "تم الاستلام",
    "rejected": "مرفوض",
}

AR_STATUS_MAP: Dict[str, str] = {v: k for k, v in STATUS_AR_MAP.items()}

KNOWN_STOCK_ALIASES: Dict[str, str] = {
    "stock_ck_01": "RAW-BEEF-01",
    "stock_ck_02": "RAW-OIL-02",
    "stock_ck_03": "SAUCE-SPEC-01",
    "stock_ck_04": "DAIRY-CHED-01",
    "stock_ck_05": "FRIES-FROZ-01",
    "stock_ck_06": "BUN-BRIO-01",
}


def compute_stock_level(quantity: float, safety_stock: float) -> str:
    """Calculates stock status level based on quantity and safety stock threshold."""
    if quantity <= safety_stock * 0.5:
        return "critical"
    elif quantity <= safety_stock:
        return "low"
    else:
        return "available"


def ensure_supply_seed_data(conn: sqlite3.Connection) -> None:
    """
    Ensures baseline Central Kitchen stock items and baseline supply orders exist
    WITHOUT overwriting or auto-replenishing existing stock quantities.
    Follows canonical stock lookup to avoid UNIQUE(branch_id, sku) collisions.
    """
    cur = conn.cursor()

    # 1. Baseline Central Kitchen Stock Items (br_04) - only insert missing SKUs
    cur.execute("SELECT sku FROM stock_items WHERE branch_id = 'br_04'")
    existing_ck_skus = {
        (r["sku"] if isinstance(r, sqlite3.Row) else r[0])
        for r in cur.fetchall()
    }

    ck_stock_items = [
        ("stock_ck_01", "br_04", "لحم بقري مفروم ممتاز", "RAW-BEEF-01", "لحوم", 12.0, "كجم", 160.0, 50.0, 200.0, "ثلاجة التجميد A1", "critical"),
        ("stock_ck_02", "br_04", "زيت قلي نقي 20 لتر", "RAW-OIL-02", "زيوت", 15.0, "لتر", 85.0, 60.0, 300.0, "مستودع الجاف B2", "critical"),
        ("stock_ck_03", "br_04", "صلصة البرجر السرية الخاصة", "SAUCE-SPEC-01", "صوصات", 8.0, "كجم", 45.0, 30.0, 150.0, "غرفة التبريد C1", "critical"),
        ("stock_ck_04", "br_04", "جبنة شيدر معتقة شرائح", "DAIRY-CHED-01", "ألبان", 22.0, "كجم", 120.0, 40.0, 100.0, "ثلاجة الألبان", "low"),
        ("stock_ck_05", "br_04", "بطاطس نصف مقلية فاخرة", "FRIES-FROZ-01", "مجمدات", 180.0, "كجم", 35.0, 80.0, 500.0, "ثلاجة التجميد الكبرى", "available"),
        ("stock_ck_06", "br_04", "خبز بريوش طازج محمص", "BUN-BRIO-01", "مخبوزات", 450.0, "قطعة", 4.5, 200.0, 1000.0, "مستودع المخبوزات", "available"),
    ]

    items_to_insert = [itm for itm in ck_stock_items if itm[3] not in existing_ck_skus]
    if items_to_insert:
        cur.executemany(
            """
            INSERT OR IGNORE INTO stock_items (
                id, branch_id, name, sku, category, quantity, unit, unit_cost,
                safety_stock, capacity, location, stock_level
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            items_to_insert,
        )

    # Note: NO auto-replenishment of depleted stock items here or in runtime reads.
    # Conservation invariant guarantees physical consistency.

    # 2. Baseline supply orders - only insert if table is empty
    cur.execute("SELECT COUNT(*) FROM supply_orders")
    count_row = cur.fetchone()
    order_count = count_row[0] if not isinstance(count_row, sqlite3.Row) else count_row["COUNT(*)"]
    if order_count == 0:
        baseline_orders = [
            ("so_01", "SO-2026-001", "br_04", "br_01", "preparing", 8500.0, "2026-10-24", "usr_bm1", "usr_bm1", None),
            ("so_02", "SO-2026-002", "br_04", "br_02", "pending", 6200.0, "2026-10-24", "usr_bm1", None, None),
            ("so_03", "SO-2026-003", "br_04", "br_03", "in_transit", 9400.0, "2026-10-24", "usr_bm1", "usr_bm1", None),
            ("so_04", "SO-2026-004", "br_04", "br_01", "preparing", 4500.0, "2026-10-25", "usr_bm1", "usr_bm1", None),
            ("so_05", "SO-2026-005", "br_04", "br_02", "preparing", 7800.0, "2026-10-25", "usr_bm1", "usr_bm1", None),
            ("so_06", "SO-2026-006", "br_04", "br_03", "draft", 3200.0, "2026-10-25", "usr_bm1", None, None),
        ]
        cur.executemany(
            """
            INSERT OR IGNORE INTO supply_orders (
                id, order_number, source_kitchen_id, destination_branch_id, status,
                total_cost, requested_delivery_date, created_by_user_id, executed_by_user_id, received_by_user_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            baseline_orders,
        )

    # 3. Check if supply_order_items exists
    cur.execute("SELECT COUNT(*) FROM supply_order_items")
    count_row = cur.fetchone()
    items_count = count_row[0] if not isinstance(count_row, sqlite3.Row) else count_row["COUNT(*)"]
    if items_count > 0:
        conn.commit()
        return

    # Look up canonical Central Kitchen stock items by SKU
    cur.execute("SELECT id, sku, unit_cost FROM stock_items WHERE branch_id = 'br_04'")
    kitchen_items = {r["sku"]: r for r in cur.fetchall()}
    if not kitchen_items:
        conn.commit()
        return

    sample_items = [
        # so_01: preparing (total_cost: 8500.0) -> Beef, Sauce, Cheddar
        ("so_01", "RAW-BEEF-01", 30.0, 30.0, None, 160.0),
        ("so_01", "SAUCE-SPEC-01", 40.0, 40.0, None, 45.0),
        ("so_01", "DAIRY-CHED-01", 15.0, 15.0, None, 120.0),
        # so_02: pending (total_cost: 6200.0) -> Oil, Fries
        ("so_02", "RAW-OIL-02", 40.0, None, None, 85.0),
        ("so_02", "FRIES-FROZ-01", 80.0, None, None, 35.0),
        # so_03: in_transit (total_cost: 9400.0) -> Beef, Cheddar
        ("so_03", "RAW-BEEF-01", 40.0, 40.0, None, 160.0),
        ("so_03", "DAIRY-CHED-01", 25.0, 25.0, None, 120.0),
        # so_04: preparing (total_cost: 4500.0) -> Fries, Bun
        ("so_04", "FRIES-FROZ-01", 100.0, 100.0, None, 35.0),
        ("so_04", "BUN-BRIO-01", 222.0, 222.0, None, 4.5),
        # so_05: preparing (total_cost: 7800.0) -> Beef, Cheddar
        ("so_05", "RAW-BEEF-01", 30.0, 30.0, None, 160.0),
        ("so_05", "DAIRY-CHED-01", 25.0, 25.0, None, 120.0),
        # so_06: draft (total_cost: 3200.0) -> Sauce, Bun
        ("so_06", "SAUCE-SPEC-01", 40.0, None, None, 45.0),
        ("so_06", "BUN-BRIO-01", 311.0, None, None, 4.5),
    ]

    for order_id, sku, req_q, disp_q, rec_q, default_cost in sample_items:
        cur.execute("SELECT id FROM supply_orders WHERE id = ?", (order_id,))
        if not cur.fetchone():
            continue
        st_row = kitchen_items.get(sku)
        if not st_row:
            continue
        unit_cost = float(st_row["unit_cost"]) or default_cost
        item_id = f"soi_{order_id}_{sku.lower().replace('-', '_')}"
        cur.execute(
            """
            INSERT OR IGNORE INTO supply_order_items (
                id, supply_order_id, stock_item_id,
                requested_quantity, dispatched_quantity, received_quantity, unit_cost
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (item_id, order_id, st_row["id"], req_q, disp_q, rec_q, unit_cost),
        )

    conn.commit()


class SupplyService:
    @staticmethod
    def _execute_with_conn(callback, conn: Optional[sqlite3.Connection] = None):
        """
        Executes operations directly on SQLite database connection without
        running auto-replenishment or mutation routines on read/mutation calls.
        """
        if conn is not None:
            return callback(conn)
        with get_db() as db:
            return callback(db)

    @staticmethod
    def _resolve_stock_item(
        db: sqlite3.Connection,
        identifier: str,
        branch_id: str,
    ) -> Optional[sqlite3.Row]:
        """
        Performs canonical stock lookup against the actual SQLite database:
        1. Direct ID match within target branch
        2. Direct SKU match within target branch
        3. Known legacy alias mapping (e.g. stock_ck_01 -> RAW-BEEF-01) within branch
        4. Global ID match across branches
        5. Global SKU match across branches
        """
        if not identifier:
            return None

        # 1. Match by branch_id + id
        cur = db.execute(
            "SELECT * FROM stock_items WHERE branch_id = ? AND id = ?",
            (branch_id, identifier),
        )
        row = cur.fetchone()
        if row:
            return row

        # 2. Match by branch_id + sku
        cur = db.execute(
            "SELECT * FROM stock_items WHERE branch_id = ? AND sku = ?",
            (branch_id, identifier),
        )
        row = cur.fetchone()
        if row:
            return row

        # 3. Known alias lookup within branch
        mapped_sku = KNOWN_STOCK_ALIASES.get(identifier)
        if mapped_sku:
            cur = db.execute(
                "SELECT * FROM stock_items WHERE branch_id = ? AND sku = ?",
                (branch_id, mapped_sku),
            )
            row = cur.fetchone()
            if row:
                return row

        # 4. Global match by ID
        cur = db.execute("SELECT * FROM stock_items WHERE id = ? LIMIT 1", (identifier,))
        row = cur.fetchone()
        if row:
            return row

        # 5. Global match by SKU (or mapped SKU)
        target_sku = mapped_sku or identifier
        cur = db.execute("SELECT * FROM stock_items WHERE sku = ? LIMIT 1", (target_sku,))
        return cur.fetchone()

    @classmethod
    def get_supply_orders(
        cls,
        status: Optional[str] = None,
        branch_id: Optional[str] = None,
        destination_branch_id: Optional[str] = None,
        source_kitchen_id: Optional[str] = None,
        search: Optional[str] = None,
        conn: Optional[sqlite3.Connection] = None,
    ) -> Tuple[List[SupplyOrderResponse], Dict[str, Any]]:
        """
        Retrieves list of supply orders with full items, joins, filtering and summary statistics.
        Operates strictly as a read query with zero stock side-effects.
        """
        def _op(db: sqlite3.Connection):
            normalized_status = status
            if status and status in AR_STATUS_MAP:
                normalized_status = AR_STATUS_MAP[status]

            query = """
                SELECT 
                    so.id, so.order_number, so.source_kitchen_id, so.destination_branch_id,
                    so.status, so.total_cost, so.requested_delivery_date,
                    so.created_by_user_id, so.executed_by_user_id, so.received_by_user_id,
                    so.created_at, so.updated_at,
                    sb.name_ar as source_kitchen_name,
                    db.name_ar as destination_branch_name,
                    cu.full_name_ar as created_by_name,
                    eu.full_name_ar as executed_by_name,
                    ru.full_name_ar as received_by_name
                FROM supply_orders so
                LEFT JOIN branches sb ON so.source_kitchen_id = sb.id
                LEFT JOIN branches db ON so.destination_branch_id = db.id
                LEFT JOIN users cu ON so.created_by_user_id = cu.id
                LEFT JOIN users eu ON so.executed_by_user_id = eu.id
                LEFT JOIN users ru ON so.received_by_user_id = ru.id
                WHERE 1=1
            """
            params: List[Any] = []

            if normalized_status:
                query += " AND so.status = ?"
                params.append(normalized_status)

            if branch_id:
                query += " AND (so.destination_branch_id = ? OR so.source_kitchen_id = ?)"
                params.extend([branch_id, branch_id])

            if destination_branch_id:
                query += " AND so.destination_branch_id = ?"
                params.append(destination_branch_id)

            if source_kitchen_id:
                query += " AND so.source_kitchen_id = ?"
                params.append(source_kitchen_id)

            if search:
                query += " AND (so.order_number LIKE ? OR db.name_ar LIKE ? OR sb.name_ar LIKE ?)"
                like_term = f"%{search}%"
                params.extend([like_term, like_term, like_term])

            query += " ORDER BY so.created_at DESC, so.order_number DESC"

            cur = db.execute(query, params)
            order_rows = cur.fetchall()

            orders: List[SupplyOrderResponse] = []
            for row in order_rows:
                items = cls._get_order_items(db, row["id"])
                
                summary_parts = []
                for it in items[:3]:
                    summary_parts.append(f"{it.itemName} {int(it.requestedQuantity)} {it.unit}")
                summary = " • ".join(summary_parts) if summary_parts else "بدون تفاصيل أصناف"

                orders.append(
                    SupplyOrderResponse(
                        id=row["id"],
                        order_number=row["order_number"],
                        source_kitchen_id=row["source_kitchen_id"],
                        source_kitchen_name=row["source_kitchen_name"] or "",
                        destination_branch_id=row["destination_branch_id"],
                        destination_branch_name=row["destination_branch_name"] or "",
                        status=row["status"],
                        status_ar=STATUS_AR_MAP.get(row["status"], row["status"]),
                        total_cost=float(row["total_cost"] or 0.0),
                        requested_delivery_date=row["requested_delivery_date"],
                        created_by_user_id=row["created_by_user_id"],
                        created_by_name=row["created_by_name"] or "",
                        executed_by_user_id=row["executed_by_user_id"],
                        executed_by_name=row["executed_by_name"] or "",
                        received_by_user_id=row["received_by_user_id"],
                        received_by_name=row["received_by_name"] or "",
                        items_count=len(items),
                        summary=summary,
                        created_at=row["created_at"],
                        updated_at=row["updated_at"],
                        items=items,
                    )
                )

            # Metadata counts by status directly from current orders table
            cur = db.execute("SELECT status, COUNT(*) as c FROM supply_orders GROUP BY status")
            counts_by_status = {k: 0 for k in STATUS_AR_MAP.keys()}
            for r in cur.fetchall():
                counts_by_status[r["status"]] = r["c"]

            meta = {
                "total": len(orders),
                "countsByStatus": counts_by_status,
                "countsByStatusAr": {
                    STATUS_AR_MAP[k]: v for k, v in counts_by_status.items()
                },
            }
            return orders, meta

        return cls._execute_with_conn(_op, conn)

    @classmethod
    def get_supply_order_by_id(
        cls,
        order_id_or_number: str,
        conn: Optional[sqlite3.Connection] = None,
    ) -> SupplyOrderResponse:
        """
        Retrieves a single supply order by its internal id or order_number.
        """
        def _op(db: sqlite3.Connection):
            query = """
                SELECT 
                    so.id, so.order_number, so.source_kitchen_id, so.destination_branch_id,
                    so.status, so.total_cost, so.requested_delivery_date,
                    so.created_by_user_id, so.executed_by_user_id, so.received_by_user_id,
                    so.created_at, so.updated_at,
                    sb.name_ar as source_kitchen_name,
                    db.name_ar as destination_branch_name,
                    cu.full_name_ar as created_by_name,
                    eu.full_name_ar as executed_by_name,
                    ru.full_name_ar as received_by_name
                FROM supply_orders so
                LEFT JOIN branches sb ON so.source_kitchen_id = sb.id
                LEFT JOIN branches db ON so.destination_branch_id = db.id
                LEFT JOIN users cu ON so.created_by_user_id = cu.id
                LEFT JOIN users eu ON so.executed_by_user_id = eu.id
                LEFT JOIN users ru ON so.received_by_user_id = ru.id
                WHERE so.id = ? OR so.order_number = ?
            """
            cur = db.execute(query, (order_id_or_number, order_id_or_number))
            row = cur.fetchone()
            if not row:
                raise ValueError(f"طلب التوريد '{order_id_or_number}' غير موجود")

            items = cls._get_order_items(db, row["id"])
            summary_parts = [f"{it.itemName} {int(it.requestedQuantity)} {it.unit}" for it in items[:3]]
            summary = " • ".join(summary_parts) if summary_parts else "بدون تفاصيل أصناف"

            return SupplyOrderResponse(
                id=row["id"],
                order_number=row["order_number"],
                source_kitchen_id=row["source_kitchen_id"],
                source_kitchen_name=row["source_kitchen_name"] or "",
                destination_branch_id=row["destination_branch_id"],
                destination_branch_name=row["destination_branch_name"] or "",
                status=row["status"],
                status_ar=STATUS_AR_MAP.get(row["status"], row["status"]),
                total_cost=float(row["total_cost"] or 0.0),
                requested_delivery_date=row["requested_delivery_date"],
                created_by_user_id=row["created_by_user_id"],
                created_by_name=row["created_by_name"] or "",
                executed_by_user_id=row["executed_by_user_id"],
                executed_by_name=row["executed_by_name"] or "",
                received_by_user_id=row["received_by_user_id"],
                received_by_name=row["received_by_name"] or "",
                items_count=len(items),
                summary=summary,
                created_at=row["created_at"],
                updated_at=row["updated_at"],
                items=items,
            )

        return cls._execute_with_conn(_op, conn)

    @classmethod
    def _get_order_items(cls, db: sqlite3.Connection, order_id: str) -> List[SupplyOrderItemResponse]:
        query = """
            SELECT 
                soi.id, soi.supply_order_id, soi.stock_item_id,
                soi.requested_quantity, soi.dispatched_quantity, soi.received_quantity,
                soi.unit_cost,
                si.name as item_name, si.sku as item_sku, si.category, si.unit
            FROM supply_order_items soi
            LEFT JOIN stock_items si ON soi.stock_item_id = si.id
            WHERE soi.supply_order_id = ?
            ORDER BY soi.id ASC
        """
        cur = db.execute(query, (order_id,))
        items: List[SupplyOrderItemResponse] = []
        for r in cur.fetchall():
            unit_cost = float(r["unit_cost"] or 0.0)
            req_qty = float(r["requested_quantity"] or 0.0)
            total_cost = unit_cost * req_qty
            items.append(
                SupplyOrderItemResponse(
                    id=r["id"],
                    supply_order_id=r["supply_order_id"],
                    stock_item_id=r["stock_item_id"],
                    item_name=r["item_name"] or "",
                    item_sku=r["item_sku"] or "",
                    category=r["category"] or "",
                    unit=r["unit"] or "كجم",
                    requested_quantity=req_qty,
                    dispatched_quantity=float(r["dispatched_quantity"]) if r["dispatched_quantity"] is not None else None,
                    received_quantity=float(r["received_quantity"]) if r["received_quantity"] is not None else None,
                    unit_cost=unit_cost,
                    total_cost=total_cost,
                )
            )
        return items

    @classmethod
    def create_supply_order(
        cls,
        data: SupplyOrderCreate,
        user_id: Optional[str] = None,
        conn: Optional[sqlite3.Connection] = None,
    ) -> SupplyOrderResponse:
        """
        Creates a new supply order with requested items in an ACID transaction.
        Validates destination and source branches against SQLite branches table.
        Performs canonical stock lookup against actual DB.
        """
        def _op(db: sqlite3.Connection):
            # 1. Validate destination branch
            cur = db.execute("SELECT id, name_ar FROM branches WHERE id = ?", (data.destination_branch_id,))
            dest_branch = cur.fetchone()
            if not dest_branch:
                raise ValueError(f"فرع الاستلام '{data.destination_branch_id}' غير موجود في النظام")

            # 2. Validate source kitchen
            source_kitchen_id = data.source_kitchen_id or "br_04"
            cur = db.execute("SELECT id, name_ar FROM branches WHERE id = ?", (source_kitchen_id,))
            kitchen = cur.fetchone()
            if not kitchen:
                raise ValueError(f"المطبخ المركزي '{source_kitchen_id}' غير موجود في النظام")

            # 3. Validate items list
            if not data.items:
                raise ValueError("يجب تحديد صنف واحد على الأقل في طلب التوريد")

            # 4. Generate order ID and unique order number
            order_id = f"so_{uuid.uuid4().hex[:8]}"
            order_number = data.order_number
            if not order_number:
                cur = db.execute(
                    "SELECT order_number FROM supply_orders WHERE order_number LIKE 'SO-2026-%' ORDER BY order_number DESC LIMIT 1"
                )
                row = cur.fetchone()
                if row and row["order_number"]:
                    try:
                        seq = int(row["order_number"].split("-")[-1]) + 1
                    except Exception:
                        seq = 100
                else:
                    seq = 1
                order_number = f"SO-2026-{seq:03d}"

            delivery_date = data.requested_delivery_date or datetime.now().strftime("%Y-%m-%d")
            status = data.status or "pending"
            if status not in STATUS_AR_MAP:
                raise ValueError(f"حالة الطلب '{status}' غير صحيحة")

            total_cost = 0.0
            order_items_to_insert = []

            # 5. Resolve and validate each item against actual stock catalog in DB
            for item in data.items:
                st_row = cls._resolve_stock_item(db, item.stock_item_id, source_kitchen_id)
                if not st_row:
                    raise ValueError(f"صنف المخزون '{item.stock_item_id}' غير معرف في النظام أو المطبخ المركزي")

                unit_cost = (
                    float(item.unit_cost)
                    if (item.unit_cost is not None and item.unit_cost > 0)
                    else float(st_row["unit_cost"] or 0.0)
                )
                line_cost = float(item.requested_quantity) * unit_cost
                total_cost += line_cost

                item_id = f"soi_{uuid.uuid4().hex[:8]}"
                order_items_to_insert.append(
                    (
                        item_id,
                        order_id,
                        st_row["id"],
                        float(item.requested_quantity),
                        unit_cost,
                    )
                )

            actor = user_id or data.created_by_user_id or "usr_bm1"

            # 6. Insert Order
            db.execute(
                """
                INSERT INTO supply_orders (
                    id, order_number, source_kitchen_id, destination_branch_id,
                    status, total_cost, requested_delivery_date,
                    created_by_user_id, executed_by_user_id, received_by_user_id,
                    created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, datetime('now'), datetime('now'))
                """,
                (
                    order_id,
                    order_number,
                    source_kitchen_id,
                    data.destination_branch_id,
                    status,
                    total_cost,
                    delivery_date,
                    actor,
                ),
            )

            # 7. Insert Order Items
            for soi in order_items_to_insert:
                db.execute(
                    """
                    INSERT INTO supply_order_items (
                        id, supply_order_id, stock_item_id,
                        requested_quantity, dispatched_quantity, received_quantity, unit_cost
                    ) VALUES (?, ?, ?, ?, NULL, NULL, ?)
                    """,
                    soi,
                )

            # 8. Insert Audit Log
            db.execute(
                """
                INSERT INTO audit_logs (
                    id, user_id, branch_id, action, entity_type, entity_id,
                    old_values_json, new_values_json, ip_address, user_agent, timestamp
                ) VALUES (?, ?, ?, 'SUPPLY_ORDER_CREATED', 'supply_order', ?, NULL, ?, '127.0.0.1', 'RMS-Backend/1.0', datetime('now'))
                """,
                (
                    f"aud_{uuid.uuid4().hex[:8]}",
                    actor,
                    data.destination_branch_id,
                    order_id,
                    json.dumps({
                        "order_number": order_number,
                        "total_cost": total_cost,
                        "items_count": len(order_items_to_insert),
                        "status": status,
                    }),
                ),
            )

            return cls.get_supply_order_by_id(order_id, conn=db)

        return cls._execute_with_conn(_op, conn)

    @classmethod
    def execute_supply_order(
        cls,
        order_id: str,
        data: ExecuteSupplyOrderRequest,
        user_id: Optional[str] = None,
        conn: Optional[sqlite3.Connection] = None,
    ) -> SupplyOrderResponse:
        """
        Executes and dispatches a supply order from the Central Kitchen.
        Deducts inventory from Central Kitchen stock items and creates stock_movement 'issue' records.
        Pending/preparing orders transition to 'in_transit' ONLY after atomic source debit.
        Operates strictly inside an ACID transaction.
        """
        def _op(db: sqlite3.Connection):
            # 1. Fetch order
            cur = db.execute(
                "SELECT * FROM supply_orders WHERE id = ? OR order_number = ?",
                (order_id, order_id),
            )
            order = cur.fetchone()
            if not order:
                raise ValueError(f"طلب التوريد '{order_id}' غير موجود")

            # 2. Status invariants
            current_status = order["status"]
            if current_status == "in_transit":
                raise ValueError("الطلب قيد الشحن بالفعل وتم تنفيذه سابقاً")
            if current_status == "received":
                raise ValueError("لا يمكن تنفيذ طلب تم استلامه وإيداعه بالمخزن مسبقاً")
            if current_status == "rejected":
                raise ValueError("لا يمكن تنفيذ طلب توريد مرفوض")
            if current_status not in ("draft", "pending", "preparing"):
                raise ValueError(f"لا يمكن تنفيذ الطلب في حالته الحالية: '{current_status}'")

            # 3. Fetch order items
            cur = db.execute(
                "SELECT * FROM supply_order_items WHERE supply_order_id = ?",
                (order["id"],),
            )
            items = cur.fetchall()
            if not items:
                raise ValueError("لا توجد أصناف في طلب التوريد للتنفيذ")

            # 4. Map dispatched quantities if provided
            disp_map: Dict[str, float] = {}
            if data.items:
                for it in data.items:
                    if it.item_id:
                        disp_map[it.item_id] = it.dispatched_quantity
                    if it.stock_item_id:
                        disp_map[it.stock_item_id] = it.dispatched_quantity

            actor = user_id or data.executed_by_user_id or "usr_bm1"

            # 5. Process each item: deduct kitchen stock & record movement
            for it in items:
                item_id = it["id"]
                stock_item_id = it["stock_item_id"]
                req_qty = float(it["requested_quantity"])

                if disp_map:
                    disp_qty = disp_map.get(item_id, disp_map.get(stock_item_id, req_qty))
                else:
                    disp_qty = req_qty

                # Locate Central Kitchen stock item using canonical resolution
                kitchen_item = cls._resolve_stock_item(db, stock_item_id, order["source_kitchen_id"])
                if not kitchen_item:
                    raise ValueError(f"صنف المخزون الأساسي '{stock_item_id}' غير مسجل في مستودع المطبخ المركزي")

                current_qty = float(kitchen_item["quantity"])
                safety_stock = float(kitchen_item["safety_stock"] or 0.0)

                # Check inventory constraint
                if current_qty < disp_qty and not data.allow_overdraw:
                    raise ValueError(
                        f"رصيد الصنف '{kitchen_item['name']}' غير كافٍ في المطبخ المركزي "
                        f"(المتاح: {current_qty} {kitchen_item['unit']}، المطلوب صرفه: {disp_qty} {kitchen_item['unit']})"
                    )

                new_qty = current_qty - disp_qty
                new_level = compute_stock_level(new_qty, safety_stock)

                # Update Central Kitchen stock item
                db.execute(
                    """
                    UPDATE stock_items
                    SET quantity = ?, stock_level = ?, updated_at = datetime('now')
                    WHERE id = ?
                    """,
                    (new_qty, new_level, kitchen_item["id"]),
                )

                # Record stock movement (issue)
                mov_id = f"mov_{uuid.uuid4().hex[:8]}"
                mov_code = f"MOV-ISS-{uuid.uuid4().hex[:6].upper()}"
                db.execute(
                    """
                    INSERT INTO stock_movements (
                        id, code, stock_item_id, branch_id, movement_type,
                        quantity, balance_after, description, created_by_user_id, created_at
                    ) VALUES (?, ?, ?, ?, 'issue', ?, ?, ?, ?, datetime('now'))
                    """,
                    (
                        mov_id,
                        mov_code,
                        kitchen_item["id"],
                        order["source_kitchen_id"],
                        disp_qty,
                        new_qty,
                        f"صرف شحنة طلب توريد {order['order_number']}",
                        actor,
                    ),
                )

                # Update dispatched quantity on order item
                db.execute(
                    """
                    UPDATE supply_order_items
                    SET dispatched_quantity = ?
                    WHERE id = ?
                    """,
                    (disp_qty, item_id),
                )

            # 6. Update order status to 'in_transit'
            cur_upd = db.execute(
                """
                UPDATE supply_orders
                SET status = 'in_transit',
                    executed_by_user_id = ?,
                    updated_at = datetime('now')
                WHERE id = ? AND status IN ('draft', 'pending', 'preparing')
                """,
                (actor, order["id"]),
            )
            if cur_upd.rowcount == 0:
                raise ValueError("فشل تنفيذ الطلب: تغيرت حالة الطلب أو تم تنفيذه مسبقاً (نزاع تزامني)")

            # 7. Audit log
            db.execute(
                """
                INSERT INTO audit_logs (
                    id, user_id, branch_id, action, entity_type, entity_id,
                    old_values_json, new_values_json, ip_address, user_agent, timestamp
                ) VALUES (?, ?, ?, 'SUPPLY_ORDER_EXECUTED', 'supply_order', ?, ?, ?, '127.0.0.1', 'RMS-Backend/1.0', datetime('now'))
                """,
                (
                    f"aud_{uuid.uuid4().hex[:8]}",
                    actor,
                    order["source_kitchen_id"],
                    order["id"],
                    json.dumps({"status": current_status}),
                    json.dumps({
                        "status": "in_transit",
                        "vehicle_info": data.vehicle_info,
                        "driver_name": data.driver_name,
                        "driver_phone": data.driver_phone,
                    }),
                ),
            )

            return cls.get_supply_order_by_id(order["id"], conn=db)

        return cls._execute_with_conn(_op, conn)

    @classmethod
    def receive_supply_order(
        cls,
        order_id: str,
        data: ReceiveSupplyOrderRequest,
        user_id: Optional[str] = None,
        conn: Optional[sqlite3.Connection] = None,
    ) -> SupplyOrderResponse:
        """
        Confirms receipt of a supply order at the destination branch.
        INVARIANTS:
        - Only orders in 'in_transit' status can be received (receiving from 'preparing' is rejected).
        - Can only be received once.
        - Received quantity must be <= dispatched quantity.
        - If received quantity < dispatched quantity, explicit reason for mismatch/damage is mandatory.
        - Deposits inventory into branch stock and logs stock_movements 'receipt'.
        - Operates strictly within an ACID transaction.
        """
        def _op(db: sqlite3.Connection):
            # 1. Fetch order
            cur = db.execute(
                "SELECT * FROM supply_orders WHERE id = ? OR order_number = ?",
                (order_id, order_id),
            )
            order = cur.fetchone()
            if not order:
                raise ValueError(f"طلب التوريد '{order_id}' غير موجود")

            current_status = order["status"]
            if current_status == "received":
                raise ValueError("طلب التوريد تم استلامه وإيداعه بالمخزن مسبقاً")
            if current_status == "rejected":
                raise ValueError("لا يمكن استلام طلب توريد مرفوض")
            if current_status != "in_transit":
                raise ValueError(
                    f"يجب تنفيذ وشحن الطلب أولاً قبل الاستلام (حالة الطلب الحالية: '{current_status}')"
                )

            # 2. Fetch order items
            cur = db.execute(
                "SELECT * FROM supply_order_items WHERE supply_order_id = ?",
                (order["id"],),
            )
            items = cur.fetchall()
            if not items:
                raise ValueError("لا توجد أصناف في طلب التوريد للاستلام")

            # 3. Map received quantities if provided
            rec_map: Dict[str, float] = {}
            if data.items:
                for it in data.items:
                    if it.item_id:
                        rec_map[it.item_id] = it.received_quantity
                    if it.stock_item_id:
                        rec_map[it.stock_item_id] = it.received_quantity

            dest_branch_id = order["destination_branch_id"]
            actor = user_id or data.received_by_user_id or "usr_bm1"

            # 4. Deposit each item into destination branch stock
            for it in items:
                item_id = it["id"]
                stock_item_id = it["stock_item_id"]
                disp_qty_val = it["dispatched_quantity"]
                if disp_qty_val is None:
                    raise ValueError(
                        f"لم يتم تسجيل كمية مشحونة للصنف '{item_id}'؛ يجب صرف الشحنة أولاً قبل تأكيد الاستلام"
                    )
                disp_qty = float(disp_qty_val)

                if rec_map:
                    rec_qty = rec_map.get(item_id, rec_map.get(stock_item_id, disp_qty))
                else:
                    rec_qty = disp_qty

                # Get master item details to copy SKU, name, category, unit, unit_cost
                src_item = cls._resolve_stock_item(db, stock_item_id, order["source_kitchen_id"])
                if not src_item:
                    raise ValueError(f"بيانات صنف المخزون الأصلي '{stock_item_id}' غير موجودة")

                item_name = src_item["name"]
                sku = src_item["sku"]

                # Invariant: received quantity cannot exceed dispatched quantity
                if rec_qty > disp_qty:
                    raise ValueError(
                        f"الكمية المستلمة ({rec_qty} {src_item['unit']}) لا يمكن أن تتجاوز الكمية المشحونة "
                        f"({disp_qty} {src_item['unit']}) للصنف '{item_name}'"
                    )

                # Invariant: if received quantity < dispatched quantity, explicit mismatch reason is required
                if rec_qty < disp_qty:
                    mismatch_reason = (data.shortage_notes or data.notes or "").strip()
                    if not mismatch_reason:
                        raise ValueError(
                            f"يجب توثيق سبب العجز أو التلف للصنف '{item_name}' "
                            f"(الكمية المشحونة: {disp_qty}، المستلمة: {rec_qty}) في ملاحظات الاستلام ومحضر عدم المطابقة"
                        )

                # Check if destination branch already has this SKU in stock_items
                cur = db.execute(
                    "SELECT * FROM stock_items WHERE branch_id = ? AND sku = ?",
                    (dest_branch_id, sku),
                )
                dest_item = cur.fetchone()

                if dest_item:
                    dest_item_id = dest_item["id"]
                    old_qty = float(dest_item["quantity"])
                    new_qty = old_qty + rec_qty
                    safety_stock = float(dest_item["safety_stock"] or 0.0)
                    new_level = compute_stock_level(new_qty, safety_stock)
                    db.execute(
                        """
                        UPDATE stock_items
                        SET quantity = ?, stock_level = ?, updated_at = datetime('now')
                        WHERE id = ?
                        """,
                        (new_qty, new_level, dest_item_id),
                    )
                else:
                    # Create new stock item record for destination branch
                    dest_item_id = f"stock_{dest_branch_id}_{uuid.uuid4().hex[:6]}"
                    new_qty = rec_qty
                    safety_stock = float(src_item["safety_stock"] or 20.0)
                    capacity = float(src_item["capacity"] or 100.0)
                    unit_cost = float(it["unit_cost"]) or float(src_item["unit_cost"] or 0.0)
                    location = f"مخزن {dest_branch_id} الرئيسي"
                    new_level = compute_stock_level(new_qty, safety_stock)
                    db.execute(
                        """
                        INSERT INTO stock_items (
                            id, branch_id, name, sku, category, quantity, unit,
                            unit_cost, safety_stock, capacity, location, stock_level, updated_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
                        """,
                        (
                            dest_item_id,
                            dest_branch_id,
                            src_item["name"],
                            sku,
                            src_item["category"],
                            new_qty,
                            src_item["unit"],
                            unit_cost,
                            safety_stock,
                            capacity,
                            location,
                            new_level,
                        ),
                    )

                # Record stock movement (receipt)
                mov_id = f"mov_{uuid.uuid4().hex[:8]}"
                mov_code = f"MOV-REC-{uuid.uuid4().hex[:6].upper()}"
                db.execute(
                    """
                    INSERT INTO stock_movements (
                        id, code, stock_item_id, branch_id, movement_type,
                        quantity, balance_after, description, created_by_user_id, created_at
                    ) VALUES (?, ?, ?, ?, 'receipt', ?, ?, ?, ?, datetime('now'))
                    """,
                    (
                        mov_id,
                        mov_code,
                        dest_item_id,
                        dest_branch_id,
                        rec_qty,
                        new_qty,
                        f"استلام وتوريد شحنة طلب توريد {order['order_number']}",
                        actor,
                    ),
                )

                # Record legitimate partial damaged difference as structured existing schema-compatible movement
                diff_qty = round(disp_qty - rec_qty, 3)
                if diff_qty > 0:
                    mov_adj_id = f"mov_{uuid.uuid4().hex[:8]}"
                    mov_adj_code = f"MOV-ADJ-{uuid.uuid4().hex[:6].upper()}"
                    adj_desc = (
                        f"تسوية عجز/تلف شحنة طلب توريد {order['order_number']} "
                        f"[REASON:DAMAGE_IN_TRANSIT] {mismatch_reason}".strip()
                    )
                    db.execute(
                        """
                        INSERT INTO stock_movements (
                            id, code, stock_item_id, branch_id, movement_type,
                            quantity, balance_after, description, created_by_user_id, created_at
                        ) VALUES (?, ?, ?, ?, 'adjustment', ?, ?, ?, ?, datetime('now'))
                        """,
                        (
                            mov_adj_id,
                            mov_adj_code,
                            dest_item_id,
                            dest_branch_id,
                            -diff_qty,
                            new_qty,
                            adj_desc,
                            actor,
                        ),
                    )

                # Update received quantity in supply_order_items
                db.execute(
                    """
                    UPDATE supply_order_items
                    SET received_quantity = ?
                    WHERE id = ?
                    """,
                    (rec_qty, item_id),
                )

            # 5. Update order status to 'received'
            cur_upd = db.execute(
                """
                UPDATE supply_orders
                SET status = 'received',
                    received_by_user_id = ?,
                    updated_at = datetime('now')
                WHERE id = ? AND status = 'in_transit'
                """,
                (actor, order["id"]),
            )
            if cur_upd.rowcount == 0:
                raise ValueError("فشل تأكيد الاستلام: تغيرت حالة الطلب أو تم استلامه مسبقاً (نزاع تزامني)")

            # 6. Audit log
            db.execute(
                """
                INSERT INTO audit_logs (
                    id, user_id, branch_id, action, entity_type, entity_id,
                    old_values_json, new_values_json, ip_address, user_agent, timestamp
                ) VALUES (?, ?, ?, 'SUPPLY_ORDER_RECEIVED', 'supply_order', ?, ?, ?, '127.0.0.1', 'RMS-Backend/1.0', datetime('now'))
                """,
                (
                    f"aud_{uuid.uuid4().hex[:8]}",
                    actor,
                    dest_branch_id,
                    order["id"],
                    json.dumps({"status": current_status}),
                    json.dumps({
                        "status": "received",
                        "has_shortage": data.has_shortage,
                        "shortage_notes": data.shortage_notes,
                        "notes": data.notes,
                        "temperature_celsius": data.temperature_celsius,
                    }),
                ),
            )

            return cls.get_supply_order_by_id(order["id"], conn=db)

        return cls._execute_with_conn(_op, conn)

    @classmethod
    def reject_supply_order(
        cls,
        order_id: str,
        reason: str,
        user_id: Optional[str] = "usr_bm1",
        conn: Optional[sqlite3.Connection] = None,
    ) -> SupplyOrderResponse:
        """
        Rejects a supply order.
        INVARIANTS:
        - Orders already dispatched ('in_transit') cannot be rejected directly without an approved return workflow.
          Rejection is refused with an explicit error to maintain inventory conservation.
        - Orders already received cannot be rejected.
        - Only draft, pending, or preparing orders can be rejected (where no stock was debited).
        """
        def _op(db: sqlite3.Connection):
            cur = db.execute(
                "SELECT * FROM supply_orders WHERE id = ? OR order_number = ?",
                (order_id, order_id),
            )
            order = cur.fetchone()
            if not order:
                raise ValueError(f"طلب التوريد '{order_id}' غير موجود")

            current_status = order["status"]
            if current_status == "received":
                raise ValueError("لا يمكن رفض طلب تم استلامه بالمستودع بالفعل")

            if current_status == "in_transit":
                raise ValueError(
                    "لا يمكن رفض طلب قيد الشحن مباشرة بدون مسار مرتجعات معتمد؛ "
                    "يجب معالجة الشحنة عبر إجراءات الاستلام النظامية أو دورة المرتجعات الرسمية"
                )

            if current_status not in ("draft", "pending", "preparing"):
                raise ValueError(f"لا يمكن رفض الطلب في حالته الحالية: '{current_status}'")

            actor = user_id or "usr_bm1"

            cur_upd = db.execute(
                """
                UPDATE supply_orders
                SET status = 'rejected', updated_at = datetime('now')
                WHERE id = ? AND status IN ('draft', 'pending', 'preparing')
                """,
                (order["id"],),
            )
            if cur_upd.rowcount == 0:
                raise ValueError("فشل رفض الطلب: تغيرت حالة الطلب أو تم رفضه مسبقاً (نزاع تزامني)")

            db.execute(
                """
                INSERT INTO audit_logs (
                    id, user_id, branch_id, action, entity_type, entity_id,
                    old_values_json, new_values_json, ip_address, user_agent, timestamp
                ) VALUES (?, ?, ?, 'SUPPLY_ORDER_REJECTED', 'supply_order', ?, ?, ?, '127.0.0.1', 'RMS-Backend/1.0', datetime('now'))
                """,
                (
                    f"aud_{uuid.uuid4().hex[:8]}",
                    actor,
                    order["destination_branch_id"],
                    order["id"],
                    json.dumps({"status": current_status}),
                    json.dumps({"status": "rejected", "reason": reason}),
                ),
            )

            return cls.get_supply_order_by_id(order["id"], conn=db)

        return cls._execute_with_conn(_op, conn)
