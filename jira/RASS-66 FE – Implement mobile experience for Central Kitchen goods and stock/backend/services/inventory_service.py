import uuid
import json
from datetime import datetime
from typing import List, Optional, Tuple, Dict, Any
from ..database.connection import get_db
from ..schemas.inventory_schemas import (
    StockItemResponse,
    StockMovementResponse,
    StockAdjustmentRequest,
    StockAdjustmentResult,
    CategoryValuation,
    StockValuationResponse,
)

BRANCH_ITEMS_SEED = [
    {
        "id": "raw-meat-102",
        "branch_id": "br_01",
        "name": "لحم بقري مفروم (متبل جاهز)",
        "sku": "RAW-MEAT-102",
        "category": "لحوم ودواجن",
        "quantity": 8.0,
        "unit": "كجم",
        "unit_cost": 320.0,
        "safety_stock": 20.0,
        "capacity": 60.0,
        "location": "ثلاجة التجهيز الرئيسية BOH-01",
        "stock_level": "critical",
    },
    {
        "id": "raw-poult-204",
        "branch_id": "br_01",
        "name": "صدور دجاج فيليه متبلة",
        "sku": "RAW-POULT-204",
        "category": "لحوم ودواجن",
        "quantity": 28.0,
        "unit": "كجم",
        "unit_cost": 185.0,
        "safety_stock": 10.0,
        "capacity": 50.0,
        "location": "ثلاجة التجهيز الرئيسية BOH-01",
        "stock_level": "available",
    },
    {
        "id": "sauce-chd-04",
        "branch_id": "br_01",
        "name": "صوص شيدر مدخن جاهز",
        "sku": "SAUCE-CHD-04",
        "category": "صلصات وزيوت",
        "quantity": 4.0,
        "unit": "لتر",
        "unit_cost": 95.0,
        "safety_stock": 8.0,
        "capacity": 20.0,
        "location": "ثلاجة الصوصات BOH-02",
        "stock_level": "critical",
    },
    {
        "id": "bak-bun-01",
        "branch_id": "br_01",
        "name": "خبز بريوش طازج",
        "sku": "BAK-BUN-01",
        "category": "مخبوزات",
        "quantity": 110.0,
        "unit": "قطعة",
        "unit_cost": 4.5,
        "safety_stock": 80.0,
        "capacity": 300.0,
        "location": "رف المخبوزات BOH-04",
        "stock_level": "low",
    },
    {
        "id": "dairy-chd-08",
        "branch_id": "br_01",
        "name": "جبن شيدر أحمر شرائح",
        "sku": "DAIRY-CHD-08",
        "category": "أجبان وألبان",
        "quantity": 15.0,
        "unit": "كجم",
        "unit_cost": 240.0,
        "safety_stock": 10.0,
        "capacity": 40.0,
        "location": "ثلاجة الألبان BOH-03",
        "stock_level": "available",
    },
    {
        "id": "oil-veg-05",
        "branch_id": "br_01",
        "name": "زيت تحمير نباتي نقي",
        "sku": "OIL-VEG-05",
        "category": "صلصات وزيوت",
        "quantity": 35.0,
        "unit": "لتر",
        "unit_cost": 65.0,
        "safety_stock": 20.0,
        "capacity": 80.0,
        "location": "مخزن الزيوت BOH-05",
        "stock_level": "available",
    },
]

BRANCH_MOVEMENTS_SEED = [
    {
        "id": "mov_branch_1",
        "code": "KCH-4102",
        "stock_item_id": "raw-meat-102",
        "branch_id": "br_01",
        "movement_type": "issue",
        "quantity": -5.0,
        "balance_after": 8.0,
        "description": "صرف لخط البرجر الساخن — الرصيد 8 كجم",
        "created_by_user_id": "usr_bm1",
    },
    {
        "id": "mov_branch_2",
        "code": "REC-5510",
        "stock_item_id": "bak-bun-01",
        "branch_id": "br_01",
        "movement_type": "receipt",
        "quantity": 100.0,
        "balance_after": 110.0,
        "description": "استلام من المطبخ المركزي — سيارة 02",
        "created_by_user_id": "usr_bm1",
    },
    {
        "id": "mov_branch_3",
        "code": "ADJ-094",
        "stock_item_id": "sauce-chd-04",
        "branch_id": "br_01",
        "movement_type": "adjustment",
        "quantity": -1.5,
        "balance_after": 4.0,
        "description": "تلف عبوة أثناء النقل — اعتماد مدير الفرع",
        "created_by_user_id": "usr_bm1",
    },
    {
        "id": "mov_branch_4",
        "code": "KCH-4098",
        "stock_item_id": "raw-poult-204",
        "branch_id": "br_01",
        "movement_type": "issue",
        "quantity": -12.0,
        "balance_after": 28.0,
        "description": "صرف لمحطة القلي والتجهيز السريع",
        "created_by_user_id": "usr_bm1",
    },
    {
        "id": "mov_branch_5",
        "code": "REC-5502",
        "stock_item_id": "raw-meat-102",
        "branch_id": "br_01",
        "movement_type": "receipt",
        "quantity": 15.0,
        "balance_after": 13.0,
        "description": "شحنة الصباح المعتمدة من المطبخ المركزي",
        "created_by_user_id": "usr_bm1",
    },
]


def ensure_inventory_seed_data(conn) -> None:
    """تأكيد وجود البيانات الأولية لمخزون الفرع وحركاته في قاعدة بيانات SQLite."""
    # Ensure default user usr_bm1 exists
    conn.execute(
        """
        INSERT OR IGNORE INTO users (id, branch_id, identifier, full_name_ar, password_hash, role, is_active)
        VALUES ('usr_bm1', 'br_01', 'manager.downtown@rms-stitch.com', 'م. ألفاريز', 'sha256_placeholder', 'branch_manager', 1)
        """
    )

    # Seed stock items
    for item in BRANCH_ITEMS_SEED:
        conn.execute(
            """
            INSERT OR IGNORE INTO stock_items (
                id, branch_id, name, sku, category, quantity,
                unit, unit_cost, safety_stock, capacity, location, stock_level
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                item["id"],
                item["branch_id"],
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

    # Seed stock movements
    for mov in BRANCH_MOVEMENTS_SEED:
        conn.execute(
            """
            INSERT OR IGNORE INTO stock_movements (
                id, code, stock_item_id, branch_id, movement_type,
                quantity, balance_after, description, created_by_user_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                mov["id"],
                mov["code"],
                mov["stock_item_id"],
                mov["branch_id"],
                mov["movement_type"],
                mov["quantity"],
                mov["balance_after"],
                mov["description"],
                mov["created_by_user_id"],
            ),
        )

    # Normalize category for transfer items to avoid duplicate categories in branch br_01
    conn.execute(
        """
        UPDATE stock_items
        SET category = 'المخبوزات والجاف'
        WHERE id = 'stock_br1_bun' AND category = 'مخبوزات'
        """
    )


def _row_to_stock_item(row) -> StockItemResponse:
    qty = float(row["quantity"])
    cost = float(row["unit_cost"])
    level_val = str(row["stock_level"])
    return StockItemResponse(
        id=str(row["id"]),
        branch_id=str(row["branch_id"]),
        name=str(row["name"]),
        sku=str(row["sku"]),
        category=str(row["category"]),
        quantity=qty,
        unit=str(row["unit"]),
        unit_cost=cost,
        total_value=round(qty * cost, 2),
        safety_stock=float(row["safety_stock"]),
        capacity=float(row["capacity"]),
        location=str(row["location"]),
        stock_level=level_val,
        level=level_val,
        updated_at=str(row["updated_at"]) if row["updated_at"] else None,
    )


def _row_to_stock_movement(row) -> StockMovementResponse:
    qty = float(row["quantity"])
    unit = row["unit"] if "unit" in row.keys() and row["unit"] else ""
    qty_label = f"{qty:+.1f} {unit}".strip() if unit else f"{qty:+.1f}"
    created_at_val = str(row["created_at"]) if row["created_at"] else ""
    return StockMovementResponse(
        id=str(row["id"]),
        code=str(row["code"]),
        stock_item_id=str(row["stock_item_id"]),
        branch_id=str(row["branch_id"]),
        item_name=str(row["name"]) if "name" in row.keys() and row["name"] else None,
        sku=str(row["sku"]) if "sku" in row.keys() and row["sku"] else None,
        movement_type=str(row["movement_type"]),
        type=str(row["movement_type"]),
        quantity=qty,
        quantity_label=qty_label,
        balance_after=float(row["balance_after"]),
        description=str(row["description"]),
        time=created_at_val[11:16] if len(created_at_val) >= 16 else "12:00",
        created_by_user_id=str(row["created_by_user_id"]) if row["created_by_user_id"] else None,
        created_at=created_at_val,
    )


class InventoryService:
    @classmethod
    def get_inventory_list(
        cls,
        branch_id: Optional[str] = None,
        category: Optional[str] = None,
        stock_level: Optional[str] = None,
        search: Optional[str] = None,
    ) -> List[StockItemResponse]:
        """استعراض أرصدة المخزون وجرد الأصناف مع دعم التصفية والبحث."""
        with get_db() as conn:
            query = "SELECT * FROM stock_items WHERE 1=1"
            params: List[Any] = []

            if branch_id and branch_id != "all":
                query += " AND branch_id = ?"
                params.append(branch_id)

            if category and str(category).strip() and str(category).strip() != "الكل":
                query += " AND category = ?"
                params.append(str(category).strip())

            if stock_level and stock_level != "الكل":
                # Map Arabic terms to enum values if passed
                level_map = {
                    "حرج": "critical",
                    "مخزون منخفض": "low",
                    "منخفض": "low",
                    "متوفر": "available",
                    "critical": "critical",
                    "low": "low",
                    "available": "available",
                }
                normalized_level = level_map.get(stock_level, stock_level)
                query += " AND stock_level = ?"
                params.append(normalized_level)

            if search and search.strip():
                query += " AND (name LIKE ? OR sku LIKE ? OR category LIKE ?)"
                pattern = f"%{search.strip()}%"
                params.extend([pattern, pattern, pattern])

            query += " ORDER BY name ASC"

            cursor = conn.cursor()
            cursor.execute(query, params)
            rows = cursor.fetchall()
            return [_row_to_stock_item(r) for r in rows]

    @classmethod
    def get_inventory_item(cls, item_id: str, branch_id: Optional[str] = None) -> StockItemResponse:
        """جلب تفاصيل صنف مخزون محدد بمعرفه."""
        with get_db() as conn:
            query = "SELECT * FROM stock_items WHERE id = ?"
            params: List[Any] = [item_id]

            if branch_id and branch_id != "all":
                query += " AND branch_id = ?"
                params.append(branch_id)

            cursor = conn.cursor()
            cursor.execute(query, params)
            row = cursor.fetchone()
            if not row:
                raise ValueError(f"صنف المخزون بالمعرف '{item_id}' غير موجود")
            return _row_to_stock_item(row)

    @classmethod
    def adjust_stock(
        cls,
        payload: StockAdjustmentRequest,
        actor_user_id: Optional[str] = None,
    ) -> StockAdjustmentResult:
        """
        إجراء تسوية مخزنية (هالك، عجز، فائض، أو جرد فعلي) بمعاملة ذرية ACID.
        - فحص الرصيد والحوكمة
        - خصم أو إضافة الكمية فورياً في stock_items
        - إعادة حساب stock_level تلقائياً
        - تسجيل حركة رسمية موثقة في stock_movements
        - تسجيل أثر التدقيق في audit_logs
        """
        with get_db() as conn:
            # 1. Fetch current item with lock
            cursor = conn.cursor()
            cursor.execute(
                "SELECT * FROM stock_items WHERE id = ?",
                (payload.item_id,),
            )
            item_row = cursor.fetchone()
            if not item_row:
                raise ValueError(f"صنف المخزون بالمعرف '{payload.item_id}' غير موجود")

            current_qty = float(item_row["quantity"])
            unit_cost = float(item_row["unit_cost"])
            safety_stock = float(item_row["safety_stock"])
            actual_branch = str(item_row["branch_id"])
            if payload.branch_id and payload.branch_id != actual_branch:
                raise ValueError(
                    f"صنف المخزون بالمعرف '{payload.item_id}' يتبع للفرع '{actual_branch}' وليس الفرع '{payload.branch_id}'"
                )
            branch_id = actual_branch
            item_name = str(item_row["name"])
            sku = str(item_row["sku"])
            unit = str(item_row["unit"])

            # 2. Determine signed delta & validate balance invariants
            mode = (payload.mode or "deficit").lower()
            raw_qty = float(payload.quantity)

            if raw_qty <= 0:
                raise ValueError("الكمية المحددة للتسوية يجب أن تكون قيمة موجبة أكبر من الصفر")

            if mode in ("deficit", "waste", "عجز", "هالك"):
                delta = -abs(raw_qty)
                new_qty = current_qty + delta
                if new_qty < 0:
                    raise ValueError(
                        f"رصيد المخزون الحالي ({current_qty} {unit}) غير كافٍ لتسوية هالك/عجز قدره ({raw_qty} {unit})"
                    )
            elif mode in ("surplus", "فائض"):
                delta = abs(raw_qty)
                new_qty = current_qty + delta
            elif mode in ("setbalance", "set_balance", "balance", "جرد_فعلي"):
                if raw_qty < 0:
                    raise ValueError("لا يمكن تحديد رصيد فعلي سالب للمخزون")
                new_qty = raw_qty
                delta = new_qty - current_qty
            else:
                raise ValueError(f"نمط التسوية غير معروف: '{payload.mode}' (المتاح: deficit, surplus, setBalance)")

            if new_qty < 0:
                raise ValueError(
                    f"رصيد المخزون الحالي ({current_qty} {unit}) غير كافٍ للعملية ولا يمكن أن يصبح سالباً ({new_qty} {unit})"
                )

            # 3. Recompute stock_level based on safety stock
            if new_qty <= safety_stock * 0.5:
                new_level = "critical"
            elif new_qty <= safety_stock:
                new_level = "low"
            else:
                new_level = "available"

            # 4. Update stock_items atomically
            cursor.execute(
                """
                UPDATE stock_items
                SET quantity = ?, stock_level = ?, updated_at = datetime('now')
                WHERE id = ?
                """,
                (round(new_qty, 3), new_level, payload.item_id),
            )

            # 5. Insert movement into stock_movements
            mov_id = f"mov_adj_{uuid.uuid4().hex[:10]}"
            timestamp_str = datetime.now().strftime("%Y%m%d%H%M%S")
            mov_code = f"ADJ-{timestamp_str}-{uuid.uuid4().hex[:4].upper()}"
            description = f"تسوية مخزنية ({payload.reason})"
            if payload.notes and payload.notes.strip():
                description += f" — {payload.notes.strip()}"

            user_id = actor_user_id or payload.user_id or "usr_bm1"

            cursor.execute(
                """
                INSERT INTO stock_movements (
                    id, code, stock_item_id, branch_id, movement_type,
                    quantity, balance_after, description, created_by_user_id, created_at
                ) VALUES (?, ?, ?, ?, 'adjustment', ?, ?, ?, ?, datetime('now'))
                """,
                (
                    mov_id,
                    mov_code,
                    payload.item_id,
                    branch_id,
                    round(delta, 3),
                    round(new_qty, 3),
                    description,
                    user_id,
                ),
            )

            # 6. Insert audit trail into audit_logs
            audit_id = f"aud_{uuid.uuid4().hex[:10]}"
            cursor.execute(
                """
                INSERT INTO audit_logs (
                    id, user_id, branch_id, action, entity_type, entity_id,
                    old_values_json, new_values_json, timestamp
                ) VALUES (?, ?, ?, 'STOCK_ADJUSTMENT', 'stock_items', ?, ?, ?, datetime('now'))
                """,
                (
                    audit_id,
                    user_id,
                    branch_id,
                    payload.item_id,
                    json.dumps({"quantity": current_qty, "stock_level": item_row["stock_level"]}, ensure_ascii=False),
                    json.dumps({"quantity": round(new_qty, 3), "stock_level": new_level, "delta": delta, "reason": payload.reason}, ensure_ascii=False),
                ),
            )

            # 7. Fetch updated item state and movement
            cursor.execute("SELECT * FROM stock_items WHERE id = ?", (payload.item_id,))
            updated_item_row = cursor.fetchone()

            cursor.execute(
                """
                SELECT m.*, s.name, s.sku, s.unit
                FROM stock_movements m
                LEFT JOIN stock_items s ON m.stock_item_id = s.id
                WHERE m.id = ?
                """,
                (mov_id,),
            )
            movement_row = cursor.fetchone()

            item_res = _row_to_stock_item(updated_item_row)
            mov_res = _row_to_stock_movement(movement_row)
            financial_impact = round(delta * unit_cost, 2)

            return StockAdjustmentResult(
                item=item_res,
                movement=mov_res,
                previous_balance=round(current_qty, 3),
                adjusted_quantity=round(delta, 3),
                new_balance=round(new_qty, 3),
                financial_impact=financial_impact,
            )

    @classmethod
    def get_movements(
        cls,
        branch_id: Optional[str] = "br_01",
        stock_item_id: Optional[str] = None,
        movement_type: Optional[str] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> List[StockMovementResponse]:
        """جلب التسلسل الزمني للحركات المخزنية للفرع."""
        with get_db() as conn:
            query = """
                SELECT m.*, s.name, s.sku, s.unit
                FROM stock_movements m
                LEFT JOIN stock_items s ON m.stock_item_id = s.id
                WHERE 1=1
            """
            params: List[Any] = []

            if branch_id and branch_id != "all":
                query += " AND m.branch_id = ?"
                params.append(branch_id)

            if stock_item_id:
                query += " AND m.stock_item_id = ?"
                params.append(stock_item_id)

            if movement_type and movement_type != "الكل":
                type_map = {
                    "توريد": "receipt",
                    "صرف": "issue",
                    "تسويات": "adjustment",
                    "تسوية": "adjustment",
                    "تحويل": "transfer",
                    "receipt": "receipt",
                    "issue": "issue",
                    "adjustment": "adjustment",
                    "transfer": "transfer",
                }
                norm_type = type_map.get(movement_type, movement_type)
                query += " AND m.movement_type = ?"
                params.append(norm_type)

            query += " ORDER BY m.created_at DESC LIMIT ? OFFSET ?"
            params.extend([limit, offset])

            cursor = conn.cursor()
            cursor.execute(query, params)
            rows = cursor.fetchall()
            return [_row_to_stock_movement(r) for r in rows]

    @classmethod
    def get_valuation(cls, branch_id: Optional[str] = None) -> StockValuationResponse:
        """حساب تقرير القيمة المالية الإجمالية للمخزون وتحليل الفئات والأصناف الأعلى قيمة."""
        if not branch_id or not str(branch_id).strip():
            raise ValueError("معرف الفرع مطلوب لحساب تقييم المخزون")
        branch_id = str(branch_id).strip()
        with get_db() as conn:
            cursor = conn.cursor()

            # 1. Branch info
            cursor.execute("SELECT name_ar FROM branches WHERE id = ?", (branch_id,))
            branch_row = cursor.fetchone()
            branch_name = branch_row["name_ar"] if branch_row else "الفرع الرئيسي"

            # 2. Overall totals
            cursor.execute(
                """
                SELECT
                    COALESCE(SUM(quantity * unit_cost), 0.0) as total_val,
                    COUNT(*) as total_items,
                    COALESCE(SUM(CASE WHEN stock_level = 'critical' THEN 1 ELSE 0 END), 0) as crit_cnt,
                    COALESCE(SUM(CASE WHEN stock_level = 'low' THEN 1 ELSE 0 END), 0) as low_cnt,
                    COALESCE(SUM(CASE WHEN stock_level = 'available' THEN 1 ELSE 0 END), 0) as avail_cnt
                FROM stock_items
                WHERE branch_id = ?
                """,
                (branch_id,),
            )
            agg = cursor.fetchone()
            total_val = round(float(agg["total_val"]), 2)
            total_items = int(agg["total_items"])
            crit_cnt = int(agg["crit_cnt"])
            low_cnt = int(agg["low_cnt"])
            avail_cnt = int(agg["avail_cnt"])

            # 3. Group by category
            cursor.execute(
                """
                SELECT
                    category,
                    COALESCE(SUM(quantity * unit_cost), 0.0) as cat_val,
                    COUNT(*) as cat_items,
                    COALESCE(SUM(quantity), 0.0) as cat_qty
                FROM stock_items
                WHERE branch_id = ?
                GROUP BY category
                ORDER BY cat_val DESC
                """,
                (branch_id,),
            )
            cat_rows = cursor.fetchall()
            by_category: List[CategoryValuation] = []
            for cr in cat_rows:
                c_val = round(float(cr["cat_val"]), 2)
                pct = round((c_val / total_val * 100.0), 2) if total_val > 0 else 0.0
                by_category.append(
                    CategoryValuation(
                        category=str(cr["category"]),
                        total_value=c_val,
                        item_count=int(cr["cat_items"]),
                        total_quantity=round(float(cr["cat_qty"]), 2),
                        percentage=pct,
                    )
                )

            # 4. Top valuable items (limit 5)
            cursor.execute(
                """
                SELECT * FROM stock_items
                WHERE branch_id = ?
                ORDER BY (quantity * unit_cost) DESC
                LIMIT 5
                """,
                (branch_id,),
            )
            top_rows = cursor.fetchall()
            top_items = [_row_to_stock_item(r) for r in top_rows]

            return StockValuationResponse(
                branch_id=branch_id,
                branch_name=branch_name,
                total_valuation=total_val,
                total_items=total_items,
                critical_count=crit_cnt,
                low_count=low_cnt,
                available_count=avail_cnt,
                by_category=by_category,
                top_items=top_items,
            )
