import uuid
import json
import time
from datetime import datetime
from typing import List, Optional, Tuple, Dict, Any
from ..database.connection import get_db
from ..schemas.central_kitchen_schemas import (
    KitchenItemResponse,
    KitchenItemCreate,
    KitchenItemUpdate,
    KitchenMovementResponse,
)

DEFAULT_KITCHEN_ITEMS = [
    {
        "id": "ck-raw-meat-102",
        "branch_id": "br_04",
        "name": "لحم بقري مفروم (خام)",
        "sku": "RAW-MEAT-102",
        "category": "لحوم ودواجن",
        "quantity": 12.0,
        "unit": "كجم",
        "unit_cost": 320.0,
        "safety_stock": 50.0,
        "capacity": 200.0,
        "location": "ثلاجة التجميد المركزية 02",
        "stock_level": "critical",
    },
    {
        "id": "ck-raw-poult-204",
        "branch_id": "br_04",
        "name": "صدور دجاج فيليه طازج",
        "sku": "RAW-POULT-204",
        "category": "لحوم ودواجن",
        "quantity": 145.0,
        "unit": "كجم",
        "unit_cost": 185.0,
        "safety_stock": 40.0,
        "capacity": 220.0,
        "location": "مبرد اللحوم الطازجة 01",
        "stock_level": "available",
    },
    {
        "id": "ck-oil-veg-05",
        "branch_id": "br_04",
        "name": "زيت قلي نباتي نقي",
        "sku": "OIL-VEG-05",
        "category": "زيوت ودهون",
        "quantity": 18.0,
        "unit": "لتر",
        "unit_cost": 65.0,
        "safety_stock": 25.0,
        "capacity": 100.0,
        "location": "ممر الزيوت A",
        "stock_level": "critical",
    },
    {
        "id": "ck-sauce-bbq-12",
        "branch_id": "br_04",
        "name": "صوص باربكيو مدخن مركز",
        "sku": "SAUCE-BBQ-12",
        "category": "صوصات مركزية",
        "quantity": 80.0,
        "unit": "لتر",
        "unit_cost": 95.0,
        "safety_stock": 20.0,
        "capacity": 120.0,
        "location": "مخزن الصوصات",
        "stock_level": "available",
    },
    {
        "id": "ck-dairy-chd-08",
        "branch_id": "br_04",
        "name": "جبن شيدر طبيعي مبشور",
        "sku": "DAIRY-CHD-08",
        "category": "ألبان وخامات",
        "quantity": 35.0,
        "unit": "كجم",
        "unit_cost": 240.0,
        "safety_stock": 40.0,
        "capacity": 120.0,
        "location": "ثلاجة الألبان",
        "stock_level": "low",
    },
    {
        "id": "ck-bak-bun-01",
        "branch_id": "br_04",
        "name": "خبز بريوش طازج كبير",
        "sku": "BAK-BUN-01",
        "category": "مخبوزات",
        "quantity": 420.0,
        "unit": "قطعة",
        "unit_cost": 4.5,
        "safety_stock": 100.0,
        "capacity": 600.0,
        "location": "المخزن الجاف",
        "stock_level": "available",
    },
]

DEFAULT_KITCHEN_MOVEMENTS = [
    {
        "id": "mov_ck_01",
        "code": "DSP-8821",
        "sku": "RAW-MEAT-102",
        "movement_type": "issue",
        "quantity": -40.0,
        "balance_after": 12.0,
        "description": "صرف إلى فرع وسط البلد — سيارة مبردة 01",
        "created_at": "2026-10-24 11:30:00",
    },
    {
        "id": "mov_ck_02",
        "code": "REC-4109",
        "sku": "OIL-VEG-05",
        "movement_type": "receipt",
        "quantity": 250.0,
        "balance_after": 268.0,
        "description": "توريد خارجي من مزارع الدلتا للزيوت",
        "created_at": "2026-10-24 10:15:00",
    },
    {
        "id": "mov_ck_03",
        "code": "TR-1092",
        "sku": "SAUCE-BBQ-12",
        "movement_type": "transfer",
        "quantity": -30.0,
        "balance_after": 50.0,
        "description": "تحويل إلى فرع التجمع الخامس (#02)",
        "created_at": "2026-10-24 09:00:00",
    },
    {
        "id": "mov_ck_04",
        "code": "ADJ-302",
        "sku": "BAK-BUN-01",
        "movement_type": "adjustment",
        "quantity": -15.0,
        "balance_after": 420.0,
        "description": "هالك فحص عينات الجودة أثناء التغليف",
        "created_at": "2026-10-24 08:30:00",
    },
    {
        "id": "mov_ck_05",
        "code": "DSP-8818",
        "sku": "RAW-POULT-204",
        "movement_type": "issue",
        "quantity": -50.0,
        "balance_after": 145.0,
        "description": "صرف معتمد إلى فرع المعادي (#03)",
        "created_at": "2026-10-24 07:45:00",
    },
]


def format_arabic_time(created_at_str: Optional[str]) -> str:
    """تحويل التاريخ أو الوقت إلى التنسيق العربي المتوافق مع واجهات RMS (مثل: 11:30 ص)."""
    if not created_at_str:
        return "12:00 م"
    try:
        # Check if already formatted
        if "ص" in created_at_str or "م" in created_at_str:
            return created_at_str
        dt = datetime.fromisoformat(created_at_str.replace(" ", "T"))
        hour = dt.hour
        minute = dt.minute
        period = "م" if hour >= 12 else "ص"
        h12 = hour % 12
        if h12 == 0:
            h12 = 12
        return f"{h12:02d}:{minute:02d} {period}"
    except Exception:
        return created_at_str


class CentralKitchenService:
    @staticmethod
    def get_kitchen_branch_id(conn) -> str:
        """جلب معرف فرع المطبخ المركزي الأساسي في النظام."""
        cur = conn.execute("SELECT id FROM branches WHERE type = 'kitchen' LIMIT 1")
        row = cur.fetchone()
        if row and row["id"]:
            return str(row["id"])
        return "br_04"

    @classmethod
    def ensure_kitchen_seed_data(cls, conn=None) -> None:
        """ضمان وجود الأصناف الخام للمطبخ المركزي والحركات في قاعدة بيانات SQLite."""
        if conn is None:
            with get_db() as c:
                cls._seed_internal(c)
        else:
            cls._seed_internal(conn)

    @classmethod
    def _seed_internal(cls, conn) -> None:
        kitchen_id = cls.get_kitchen_branch_id(conn)

        # 1. Ensure kitchen items exist
        for item in DEFAULT_KITCHEN_ITEMS:
            # Check by sku and branch_id
            cur = conn.execute(
                "SELECT id FROM stock_items WHERE branch_id = ? AND UPPER(sku) = UPPER(?)",
                (kitchen_id, item["sku"]),
            )
            existing = cur.fetchone()
            if not existing:
                # Check if item.id is free
                id_cur = conn.execute("SELECT id FROM stock_items WHERE id = ?", (item["id"],))
                target_id = item["id"] if not id_cur.fetchone() else f"ck_{uuid.uuid4().hex[:8]}"

                conn.execute(
                    """
                    INSERT INTO stock_items (
                        id, branch_id, name, sku, category, quantity, unit, unit_cost,
                        safety_stock, capacity, location, stock_level, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
                    """,
                    (
                        target_id,
                        kitchen_id,
                        item["name"],
                        item["sku"],
                        item["category"],
                        item["quantity"],
                        item["unit"],
                        item["unit_cost"],
                        item["safety_stock"],
                        item["capacity"],
                        item["location"],
                        item["stock_level"],
                    ),
                )

        # 2. Ensure default movements exist
        for mov in DEFAULT_KITCHEN_MOVEMENTS:
            code_cur = conn.execute("SELECT id FROM stock_movements WHERE code = ?", (mov["code"],))
            if not code_cur.fetchone():
                # Find matching stock item id
                it_cur = conn.execute(
                    "SELECT id FROM stock_items WHERE branch_id = ? AND UPPER(sku) = UPPER(?) LIMIT 1",
                    (kitchen_id, mov["sku"]),
                )
                it_row = it_cur.fetchone()
                stock_item_id = it_row["id"] if it_row else None
                if not stock_item_id:
                    # Fallback to any item in kitchen
                    fb_cur = conn.execute(
                        "SELECT id FROM stock_items WHERE branch_id = ? LIMIT 1",
                        (kitchen_id,),
                    )
                    fb_row = fb_cur.fetchone()
                    stock_item_id = fb_row["id"] if fb_row else "stock_ck_01"

                # Check if movement id is free
                m_id_cur = conn.execute("SELECT id FROM stock_movements WHERE id = ?", (mov["id"],))
                target_m_id = mov["id"] if not m_id_cur.fetchone() else f"mov_{uuid.uuid4().hex[:8]}"

                conn.execute(
                    """
                    INSERT INTO stock_movements (
                        id, code, stock_item_id, branch_id, movement_type, quantity,
                        balance_after, description, created_by_user_id, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'usr_ceo', ?)
                    """,
                    (
                        target_m_id,
                        mov["code"],
                        stock_item_id,
                        kitchen_id,
                        mov["movement_type"],
                        mov["quantity"],
                        mov["balance_after"],
                        mov["description"],
                        mov["created_at"],
                    ),
                )

    @staticmethod
    def calculate_stock_level(quantity: float, safety_stock: float) -> str:
        """احتساب مستوى المخزون (حرج، منخفض، متوفر) بناءً على الرصيد وحد الأمان."""
        if quantity <= 0.0:
            return "critical"
        if safety_stock > 0.0:
            if quantity <= safety_stock * 0.5:
                return "critical"
            elif quantity <= safety_stock:
                return "low"
            else:
                return "available"
        if quantity < 5.0:
            return "low"
        return "available"

    @classmethod
    def _row_to_item_response(cls, row: Any) -> KitchenItemResponse:
        qty = float(row["quantity"])
        unit_cost = float(row["unit_cost"])
        safety = float(row["safety_stock"])
        cap = float(row["capacity"])
        stock_lvl = str(row["stock_level"])
        total_val = round(qty * unit_cost, 2)

        return KitchenItemResponse(
            id=str(row["id"]),
            branch_id=str(row["branch_id"]),
            name=str(row["name"]),
            sku=str(row["sku"]),
            category=str(row["category"]),
            quantity=qty,
            unit=str(row["unit"]),
            unit_cost=unit_cost,
            total_value=total_val,
            safety_stock=safety,
            capacity=cap,
            location=str(row["location"]),
            stock_level=stock_lvl,
            level=stock_lvl,
            updated_at=str(row["updated_at"]) if row["updated_at"] else None,
        )

    @classmethod
    def _row_to_movement_response(cls, row: Any) -> KitchenMovementResponse:
        qty = float(row["quantity"])
        unit = str(row["item_unit"] or "كجم") if "item_unit" in row.keys() else "كجم"
        qty_abs = int(abs(qty)) if abs(qty).is_integer() else abs(qty)
        if qty < 0:
            qty_label = f"-{qty_abs} {unit}"
        elif qty > 0:
            qty_label = f"+{qty_abs} {unit}"
        else:
            qty_label = f"0 {unit}"

        created_at_val = str(row["created_at"]) if row["created_at"] else None
        time_label = format_arabic_time(created_at_val)

        return KitchenMovementResponse(
            id=str(row["id"]),
            code=str(row["code"]),
            stock_item_id=str(row["stock_item_id"]),
            branch_id=str(row["branch_id"]),
            item_name=row["item_name"] if "item_name" in row.keys() else None,
            sku=row["item_sku"] if "item_sku" in row.keys() else None,
            movement_type=str(row["movement_type"]),
            type=str(row["movement_type"]),
            quantity=qty,
            quantity_label=qty_label,
            balance_after=float(row["balance_after"]),
            description=str(row["description"]),
            time=time_label,
            created_by_user_id=str(row["created_by_user_id"]) if row["created_by_user_id"] else None,
            created_at=created_at_val,
        )

    @classmethod
    def get_kitchen_items(
        cls,
        category: Optional[str] = None,
        status: Optional[str] = None,
        search: Optional[str] = None,
        branch_id: Optional[str] = None,
    ) -> Tuple[List[KitchenItemResponse], Dict[str, Any]]:
        """
        استعراض قائمة خامات المطبخ المركزي مع دعم الفلاتر والبحث والمؤشرات الإحصائية.
        """
        with get_db() as conn:
            kitchen_id = cls.get_kitchen_branch_id(conn)
            target_branch = branch_id or kitchen_id

            query = """
                SELECT * FROM stock_items
                WHERE (branch_id = ? OR branch_id IN (SELECT id FROM branches WHERE type = 'kitchen'))
            """
            params: List[Any] = [target_branch]

            # Category filter
            if category and category.strip() and category.strip() != "الكل":
                query += " AND category = ?"
                params.append(category.strip())

            # Stock level filter
            if status and status.strip() and status.strip() != "الكل":
                status_clean = status.strip()
                status_map = {
                    "متوفر": "available",
                    "مخزون منخفض": "low",
                    "حرج": "critical",
                    "حرج ونفاد": "critical",
                    "تحت الطلب": "low",
                }
                mapped_status = status_map.get(status_clean, status_clean.lower())
                query += " AND stock_level = ?"
                params.append(mapped_status)

            # Search filter
            if search and search.strip():
                s_param = f"%{search.strip()}%"
                query += " AND (name LIKE ? OR sku LIKE ? OR location LIKE ?)"
                params.extend([s_param, s_param, s_param])

            query += " ORDER BY updated_at DESC, name ASC"

            cursor = conn.execute(query, params)
            rows = cursor.fetchall()

            # Calculate overall metrics for all kitchen items before filter
            meta_cur = conn.execute(
                """
                SELECT
                    COUNT(*) as total,
                    SUM(CASE WHEN stock_level = 'critical' THEN 1 ELSE 0 END) as critical_count,
                    SUM(CASE WHEN stock_level = 'low' THEN 1 ELSE 0 END) as low_count,
                    SUM(CASE WHEN stock_level = 'available' THEN 1 ELSE 0 END) as available_count,
                    SUM(quantity * unit_cost) as total_val
                FROM stock_items
                WHERE (branch_id = ? OR branch_id IN (SELECT id FROM branches WHERE type = 'kitchen'))
                """,
                (target_branch,),
            )
            meta_row = meta_cur.fetchone()
            meta = {
                "total": meta_row["total"] if meta_row else len(rows),
                "criticalCount": meta_row["critical_count"] if meta_row and meta_row["critical_count"] is not None else 0,
                "lowCount": meta_row["low_count"] if meta_row and meta_row["low_count"] is not None else 0,
                "availableCount": meta_row["available_count"] if meta_row and meta_row["available_count"] is not None else 0,
                "totalValuation": round(float(meta_row["total_val"] or 0.0), 2) if meta_row else 0.0,
            }

            items = [cls._row_to_item_response(r) for r in rows]
            return items, meta

    @classmethod
    def get_kitchen_item_by_id(
        cls,
        item_id: str,
        branch_id: Optional[str] = None,
    ) -> Optional[KitchenItemResponse]:
        """جلب تفاصيل صنف خام محدد بالمعرف ID أو كود SKU من المطبخ المركزي."""
        clean_id = item_id.strip()
        with get_db() as conn:
            kitchen_id = cls.get_kitchen_branch_id(conn)
            target_branch = branch_id or kitchen_id

            # 1. Flexible search within kitchen branch
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
                (target_branch, clean_id, clean_id, clean_id, clean_id, clean_id, clean_id),
            )
            row = cursor.fetchone()

            # 2. Global fallback across stock_items if not found
            if not row:
                cursor = conn.execute(
                    """
                    SELECT * FROM stock_items
                    WHERE id = ? OR UPPER(sku) = UPPER(?)
                    LIMIT 1
                    """,
                    (clean_id, clean_id),
                )
                row = cursor.fetchone()

            if not row:
                return None

            return cls._row_to_item_response(row)

    @classmethod
    def create_kitchen_item(
        cls,
        payload: KitchenItemCreate,
        actor_user_id: Optional[str] = None,
    ) -> KitchenItemResponse:
        """
        إضافة صنف خام جديد في قاعدة بيانات SQLite WAL مع توثيق العملية في audit_logs.
        """
        with get_db() as conn:
            kitchen_id = cls.get_kitchen_branch_id(conn)
            target_branch = payload.branch_id or kitchen_id

            # Verify branch exists
            b_cur = conn.execute("SELECT id FROM branches WHERE id = ?", (target_branch,))
            if not b_cur.fetchone():
                raise ValueError(f"فرع المطبخ المركزي '{target_branch}' غير موجود في النظام")

            # Check for duplicate SKU in this branch
            clean_sku = payload.sku.strip()
            dup_cur = conn.execute(
                "SELECT id FROM stock_items WHERE branch_id = ? AND UPPER(sku) = UPPER(?)",
                (target_branch, clean_sku),
            )
            if dup_cur.fetchone():
                raise ValueError(f"كود الصنف المخزني '{clean_sku}' مسجل مسبقاً في المستودع المركزي")

            # Determine item id
            item_id = (payload.id or f"ck_{uuid.uuid4().hex[:8]}").strip()
            id_cur = conn.execute("SELECT id FROM stock_items WHERE id = ?", (item_id,))
            if id_cur.fetchone():
                item_id = f"ck_{uuid.uuid4().hex[:8]}"

            # Parse fields
            name = payload.name.strip()
            category = payload.category.strip()
            quantity = float(payload.quantity)
            unit = payload.unit.strip()
            unit_cost = float(payload.unit_cost)
            safety_stock = float(payload.safety_stock)
            if quantity < 0:
                raise ValueError("لا يمكن أن تكون كمية المخزون سالبة")
            if unit_cost < 0:
                raise ValueError("لا يمكن أن تكون تكلفة الوحدة سالبة")
            if safety_stock < 0:
                raise ValueError("لا يمكن أن يكون حد الأمان سالباً")
            capacity = float(payload.capacity) if payload.capacity is not None else max(quantity, safety_stock, 50.0) * 2.0
            location = (payload.location or "المستودع الرئيسي للمطبخ المركزي").strip()

            stock_level = cls.calculate_stock_level(quantity, safety_stock)

            conn.execute(
                """
                INSERT INTO stock_items (
                    id, branch_id, name, sku, category, quantity, unit, unit_cost,
                    safety_stock, capacity, location, stock_level, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
                """,
                (
                    item_id,
                    target_branch,
                    name,
                    clean_sku,
                    category,
                    quantity,
                    unit,
                    unit_cost,
                    safety_stock,
                    capacity,
                    location,
                    stock_level,
                ),
            )

            # Record in audit_logs
            audit_id = f"aud_{int(time.time() * 1000)}_{uuid.uuid4().hex[:6]}"
            new_values = {
                "id": item_id,
                "branch_id": target_branch,
                "name": name,
                "sku": clean_sku,
                "category": category,
                "quantity": quantity,
                "unit": unit,
                "unit_cost": unit_cost,
                "total_value": round(quantity * unit_cost, 2),
                "safety_stock": safety_stock,
                "capacity": capacity,
                "location": location,
                "stock_level": stock_level,
            }
            user_id = actor_user_id or payload.user_id or "usr_ceo"
            conn.execute(
                """
                INSERT INTO audit_logs (
                    id, user_id, branch_id, action, entity_type, entity_id,
                    old_values_json, new_values_json, ip_address, user_agent, timestamp
                ) VALUES (?, ?, ?, 'CREATE_KITCHEN_ITEM', 'stock_items', ?, NULL, ?, '127.0.0.1', 'RMS-FastAPI-Server', datetime('now'))
                """,
                (
                    audit_id,
                    user_id,
                    target_branch,
                    item_id,
                    json.dumps(new_values, ensure_ascii=False),
                ),
            )

            # Record initial receipt movement if quantity > 0
            if quantity > 0:
                mov_id = f"mov_ck_init_{uuid.uuid4().hex[:8]}"
                timestamp_str = datetime.now().strftime("%Y%m%d%H%M%S")
                mov_code = f"REC-INIT-{timestamp_str}-{uuid.uuid4().hex[:4].upper()}"
                conn.execute(
                    """
                    INSERT INTO stock_movements (
                        id, code, stock_item_id, branch_id, movement_type,
                        quantity, balance_after, description, created_by_user_id, created_at
                    ) VALUES (?, ?, ?, ?, 'receipt', ?, ?, ?, ?, datetime('now'))
                    """,
                    (
                        mov_id,
                        mov_code,
                        item_id,
                        target_branch,
                        quantity,
                        quantity,
                        f"رصيد افتتاحي لصنف المطبخ المركزي ({name})",
                        user_id,
                    ),
                )

            # Fetch created item
            cur = conn.execute("SELECT * FROM stock_items WHERE id = ?", (item_id,))
            row = cur.fetchone()
            return cls._row_to_item_response(row)

    @classmethod
    def update_kitchen_item(
        cls,
        item_id: str,
        payload: KitchenItemUpdate,
        actor_user_id: Optional[str] = None,
    ) -> Optional[KitchenItemResponse]:
        """
        تحديث بيانات صنف خام في SQLite وتوثيق التغييرات بالقيم السابقة والجديدة في audit_logs.
        """
        with get_db() as conn:
            kitchen_id = cls.get_kitchen_branch_id(conn)
            target_branch = payload.branch_id or kitchen_id

            # Find existing row
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
                (target_branch, item_id, item_id, item_id, item_id, item_id, item_id),
            )
            row = cursor.fetchone()
            if not row:
                cursor = conn.execute(
                    "SELECT * FROM stock_items WHERE id = ? OR UPPER(sku) = UPPER(?) LIMIT 1",
                    (item_id, item_id),
                )
                row = cursor.fetchone()

            if not row:
                return None

            real_id = row["id"]
            current_branch_id = row["branch_id"]
            old_values = dict(row)

            # Resolve updated values
            new_name = payload.name.strip() if payload.name is not None else row["name"]
            new_sku = payload.sku.strip() if payload.sku is not None else row["sku"]
            new_category = payload.category.strip() if payload.category is not None else row["category"]
            new_quantity = float(payload.quantity) if payload.quantity is not None else float(row["quantity"])
            new_unit = payload.unit.strip() if payload.unit is not None else row["unit"]
            new_unit_cost = float(payload.unit_cost) if payload.unit_cost is not None else float(row["unit_cost"])
            new_safety_stock = float(payload.safety_stock) if payload.safety_stock is not None else float(row["safety_stock"])
            if new_quantity < 0:
                raise ValueError("لا يمكن أن تكون كمية المخزون سالبة")
            if new_unit_cost < 0:
                raise ValueError("لا يمكن أن تكون تكلفة الوحدة سالبة")
            if new_safety_stock < 0:
                raise ValueError("لا يمكن أن يكون حد الأمان سالباً")
            new_capacity = float(payload.capacity) if payload.capacity is not None else float(row["capacity"])
            new_location = payload.location.strip() if payload.location is not None else row["location"]

            # Validate SKU uniqueness if updated
            if new_sku.upper() != row["sku"].upper():
                dup_cur = conn.execute(
                    "SELECT id FROM stock_items WHERE branch_id = ? AND UPPER(sku) = UPPER(?) AND id != ?",
                    (current_branch_id, new_sku, real_id),
                )
                if dup_cur.fetchone():
                    raise ValueError(f"كود الصنف المخزني '{new_sku}' مسجل مسبقاً لصنف آخر في المستودع")

            new_stock_level = cls.calculate_stock_level(new_quantity, new_safety_stock)

            conn.execute(
                """
                UPDATE stock_items
                SET name = ?, sku = ?, category = ?, quantity = ?, unit = ?,
                    unit_cost = ?, safety_stock = ?, capacity = ?, location = ?,
                    stock_level = ?, updated_at = datetime('now')
                WHERE id = ?
                """,
                (
                    new_name,
                    new_sku,
                    new_category,
                    new_quantity,
                    new_unit,
                    new_unit_cost,
                    new_safety_stock,
                    new_capacity,
                    new_location,
                    new_stock_level,
                    real_id,
                ),
            )

            # Record update in audit_logs
            audit_id = f"aud_{int(time.time() * 1000)}_{uuid.uuid4().hex[:6]}"
            new_values = {
                "id": real_id,
                "branch_id": current_branch_id,
                "name": new_name,
                "sku": new_sku,
                "category": new_category,
                "quantity": new_quantity,
                "unit": new_unit,
                "unit_cost": new_unit_cost,
                "total_value": round(new_quantity * new_unit_cost, 2),
                "safety_stock": new_safety_stock,
                "capacity": new_capacity,
                "location": new_location,
                "stock_level": new_stock_level,
            }
            user_id = actor_user_id or payload.user_id or "usr_ceo"
            conn.execute(
                """
                INSERT INTO audit_logs (
                    id, user_id, branch_id, action, entity_type, entity_id,
                    old_values_json, new_values_json, ip_address, user_agent, timestamp
                ) VALUES (?, ?, ?, 'UPDATE_KITCHEN_ITEM', 'stock_items', ?, ?, ?, '127.0.0.1', 'RMS-FastAPI-Server', datetime('now'))
                """,
                (
                    audit_id,
                    user_id,
                    current_branch_id,
                    real_id,
                    json.dumps({k: str(v) for k, v in old_values.items()}, ensure_ascii=False),
                    json.dumps(new_values, ensure_ascii=False),
                ),
            )

            # Record movement if quantity changed
            old_qty = float(old_values.get("quantity") or 0.0)
            delta = new_quantity - old_qty
            if abs(delta) > 1e-6:
                mov_id = f"mov_ck_adj_{uuid.uuid4().hex[:8]}"
                timestamp_str = datetime.now().strftime("%Y%m%d%H%M%S")
                mov_code = f"ADJ-CK-{timestamp_str}-{uuid.uuid4().hex[:4].upper()}"
                conn.execute(
                    """
                    INSERT INTO stock_movements (
                        id, code, stock_item_id, branch_id, movement_type,
                        quantity, balance_after, description, created_by_user_id, created_at
                    ) VALUES (?, ?, ?, ?, 'adjustment', ?, ?, ?, ?, datetime('now'))
                    """,
                    (
                        mov_id,
                        mov_code,
                        real_id,
                        current_branch_id,
                        round(delta, 3),
                        round(new_quantity, 3),
                        f"تعديل رصيد الصنف ({new_name}) بالمستودع المركزي",
                        user_id,
                    ),
                )

            # Fetch updated row
            cur = conn.execute("SELECT * FROM stock_items WHERE id = ?", (real_id,))
            row = cur.fetchone()
            return cls._row_to_item_response(row)

    @classmethod
    def get_kitchen_movements(
        cls,
        movement_type: Optional[str] = None,
        search: Optional[str] = None,
        item_id: Optional[str] = None,
        branch_id: Optional[str] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> Tuple[List[KitchenMovementResponse], Dict[str, Any]]:
        """
        استعراض سجل الحركات المخزنية للمطبخ المركزي (صرف، توريد، تحويل، تسوية)
        مع ربط بيانات الصنف وحساب الإحصائيات.
        """
        with get_db() as conn:
            kitchen_id = cls.get_kitchen_branch_id(conn)
            target_branch = branch_id or kitchen_id

            query = """
                SELECT
                    m.*,
                    s.name as item_name,
                    s.sku as item_sku,
                    s.unit as item_unit
                FROM stock_movements m
                LEFT JOIN stock_items s ON m.stock_item_id = s.id
                WHERE (m.branch_id = ? OR m.branch_id IN (SELECT id FROM branches WHERE type = 'kitchen'))
            """
            params: List[Any] = [target_branch]

            # Filter by movement type
            if movement_type and movement_type.strip() and movement_type.strip() != "الكل":
                type_clean = movement_type.strip()
                type_map = {
                    "صرف": "issue",
                    "توريد": "receipt",
                    "تحويل": "transfer",
                    "تسوية": "adjustment",
                }
                mapped_type = type_map.get(type_clean, type_clean.lower())
                query += " AND m.movement_type = ?"
                params.append(mapped_type)

            # Filter by search
            if search and search.strip():
                s_term = f"%{search.strip()}%"
                query += " AND (m.code LIKE ? OR m.description LIKE ? OR s.name LIKE ? OR s.sku LIKE ?)"
                params.extend([s_term, s_term, s_term, s_term])

            # Filter by item_id
            if item_id and item_id.strip():
                clean_it = item_id.strip()
                query += " AND (m.stock_item_id = ? OR s.id = ? OR UPPER(s.sku) = UPPER(?))"
                params.extend([clean_it, clean_it, clean_it])

            query += " ORDER BY m.created_at DESC, m.id DESC"

            cursor = conn.execute(query, params)
            rows = cursor.fetchall()

            # Compute overall stats before pagination
            total = len(rows)
            issue_count = sum(1 for r in rows if r["movement_type"] == "issue")
            receipt_count = sum(1 for r in rows if r["movement_type"] == "receipt")
            transfer_count = sum(1 for r in rows if r["movement_type"] == "transfer")
            adjustment_count = sum(1 for r in rows if r["movement_type"] == "adjustment")

            if limit > 0:
                rows = rows[offset : offset + limit]

            movements = [cls._row_to_movement_response(r) for r in rows]
            meta = {
                "total": total,
                "issueCount": issue_count,
                "receiptCount": receipt_count,
                "transferCount": transfer_count,
                "adjustmentCount": adjustment_count,
            }
            return movements, meta

    @classmethod
    def get_kitchen_dashboard(cls, branch_id: Optional[str] = None) -> Dict[str, Any]:
        """
        احتساب وعرض مؤشرات أداء لوحة تحكم المطبخ المركزي:
        - قيمة المخزون الكلية
        - عدد الأصناف
        - الأصناف الحرجة
        - آخر حركات المخزون
        - بيانات وهوية المستودع
        """
        with get_db() as conn:
            kitchen_id = cls.get_kitchen_branch_id(conn)
            target_branch = branch_id or kitchen_id

            # 1. Branch info
            b_cur = conn.execute("SELECT * FROM branches WHERE id = ? LIMIT 1", (target_branch,))
            b_row = b_cur.fetchone()
            depot_code = b_row["code"] if b_row and b_row["code"] else "CK-01"
            depot_name = b_row["name_ar"] if b_row and b_row["name_ar"] else "موقع التصنيع والتوريد المركزي"

            # 2. Aggregated metrics
            m_cur = conn.execute("""
                SELECT 
                    COUNT(*) as total_items,
                    COALESCE(SUM(quantity * unit_cost), 0.0) as total_val
                FROM stock_items
                WHERE branch_id = ? OR branch_id IN (SELECT id FROM branches WHERE type = 'kitchen')
            """, (target_branch,))
            m_row = m_cur.fetchone()
            total_items = int(m_row["total_items"] or 0)
            total_val = float(m_row["total_val"] or 0.0)

            # 3. Critical items
            crit_cur = conn.execute("""
                SELECT * FROM stock_items
                WHERE (branch_id = ? OR branch_id IN (SELECT id FROM branches WHERE type = 'kitchen'))
                  AND (stock_level = 'critical' OR quantity <= safety_stock)
                ORDER BY quantity ASC
                LIMIT 5
            """, (target_branch,))
            crit_rows = crit_cur.fetchall()
            critical_items = [cls._row_to_item_response(r).model_dump(by_alias=True) for r in crit_rows]

            # 4. Recent movements
            movs, _ = cls.get_kitchen_movements(branch_id=target_branch, limit=5)
            recent_movements = [m.model_dump(by_alias=True) for m in movs]

            return {
                "totalStockValue": round(total_val, 2),
                "total_stock_value": round(total_val, 2),
                "totalItemsCount": total_items,
                "total_items_count": total_items,
                "criticalItems": critical_items,
                "critical_items": critical_items,
                "recentMovements": recent_movements,
                "recent_movements": recent_movements,
                "depotCode": depot_code,
                "depot_code": depot_code,
                "depotStatus": "تشغيل نشط",
                "depot_status": "تشغيل نشط",
                "depotName": depot_name,
                "depot_name": depot_name,
                "depotSubtitle": "مخزون وتشغيل فقط • لا توجد مبيعات مباشرة",
                "depot_subtitle": "مخزون وتشغيل فقط • لا توجد مبيعات مباشرة",
                "lastAuditTime": "اليوم • 06:00 ص",
                "last_audit_time": "اليوم • 06:00 ص",
            }
