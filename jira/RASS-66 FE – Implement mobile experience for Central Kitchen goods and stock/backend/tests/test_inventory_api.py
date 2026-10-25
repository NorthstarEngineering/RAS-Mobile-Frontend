import sqlite3
import pytest
from fastapi.testclient import TestClient
from backend.main import app
from backend.config import DATABASE_PATH, API_V1_STR
from backend.database.seed_data import seed_database
from backend.routers.inventory_router import router as inventory_router
from backend.services.inventory_service import ensure_inventory_seed_data, BRANCH_ITEMS_SEED
from backend.database.connection import get_db

# Ensure inventory router is registered in app for tests
if not any(
    getattr(r, "path", None) == f"{API_V1_STR}/inventory"
    or getattr(r, "path_format", None) == f"{API_V1_STR}/inventory"
    for r in app.routes
):
    app.include_router(inventory_router, prefix=API_V1_STR)

client = TestClient(app)


def setup_module():
    """تهيئة قاعدة البيانات وإعادة ضبط أرصدة أصناف الاختبار الأولية لضمان تكرارية الاختبارات."""
    seed_database()
    with get_db() as conn:
        ensure_inventory_seed_data(conn)
        for item in BRANCH_ITEMS_SEED:
            conn.execute(
                "UPDATE stock_items SET quantity = ?, stock_level = ? WHERE id = ?",
                (item["quantity"], item["stock_level"], item["id"]),
            )


def test_get_inventory_list():
    """اختبار جرد المخزون حسب الفرع مع التحقق من الحقول الإلزامية."""
    response = client.get(f"{API_V1_STR}/inventory?branch_id=br_01")
    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    items = body["data"]
    assert len(items) >= 6

    # Verify item structure
    first = items[0]
    assert "id" in first
    assert "branchId" in first
    assert "name" in first
    assert "sku" in first
    assert "category" in first
    assert "quantity" in first
    assert "unit" in first
    assert "unitCost" in first
    assert "totalValue" in first
    assert "safetyStock" in first
    assert "capacity" in first
    assert "location" in first
    assert "stockLevel" in first
    assert "level" in first


def test_inventory_filters():
    """اختبار فلاتر المخزون: الفئة، حالة المخزون، والبحث النصي."""
    # 1. Filter by category
    res_cat = client.get(f"{API_V1_STR}/inventory?branch_id=br_01&category=مخبوزات")
    assert res_cat.status_code == 200
    items_cat = res_cat.json()["data"]
    assert len(items_cat) == 1
    assert items_cat[0]["sku"] == "BAK-BUN-01"

    # 2. Filter by stock level (critical)
    res_crit = client.get(f"{API_V1_STR}/inventory?branch_id=br_01&status=critical")
    assert res_crit.status_code == 200
    crit_items = res_crit.json()["data"]
    assert len(crit_items) >= 1
    for it in crit_items:
        assert it["stockLevel"] == "critical"

    # 3. Search query
    res_search = client.get(f"{API_V1_STR}/inventory?branch_id=br_01&q=دجاج")
    assert res_search.status_code == 200
    search_items = res_search.json()["data"]
    assert len(search_items) >= 1
    assert "دجاج" in search_items[0]["name"]


def test_get_inventory_item_details():
    """اختبار جلب تفاصيل صنف مخزون محدد والتعامل مع الأصناف غير الموجودة."""
    # Existing item
    res = client.get(f"{API_V1_STR}/inventory/raw-meat-102")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    assert body["data"]["id"] == "raw-meat-102"
    assert body["data"]["sku"] == "RAW-MEAT-102"
    assert body["data"]["unitCost"] == 320.0

    # Non-existent item (404)
    res_not_found = client.get(f"{API_V1_STR}/inventory/unknown-item-999")
    assert res_not_found.status_code == 404
    assert res_not_found.json()["detail"] is not None


def test_stock_adjustment_deficit_and_sqlite_persistence():
    """
    اختبار تسوية هالك/عجز مع خصم فوري من الرصيد وقيد في stock_movements
    والتحقق المباشر من قاعدة بيانات SQLite وديمومة التعديل بعد إعادة فتح الاتصال.
    """
    item_id = "raw-poult-204"

    # Read current balance directly from SQLite
    conn0 = sqlite3.connect(DATABASE_PATH)
    c0 = conn0.cursor()
    c0.execute("SELECT quantity, unit_cost, safety_stock FROM stock_items WHERE id = ?", (item_id,))
    row0 = c0.fetchone()
    initial_qty = float(row0[0])
    unit_cost = float(row0[1])
    conn0.close()

    deficit_qty = 4.0
    payload = {
        "itemId": item_id,
        "branchId": "br_01",
        "mode": "deficit",
        "quantity": deficit_qty,
        "reason": "هالك أثناء التحضير والتجهيز السريع",
        "notes": "استبعاد كمية بعد فحص الجودة في محطة القلي",
        "userId": "usr_bm1",
    }

    # Execute adjustment via POST /api/v1/inventory/adjust
    res = client.post(f"{API_V1_STR}/inventory/adjust", json=payload)
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    data = body["data"]

    expected_new_balance = round(initial_qty - deficit_qty, 3)
    assert data["previousBalance"] == initial_qty
    assert data["adjustedQuantity"] == -deficit_qty
    assert data["newBalance"] == expected_new_balance
    assert data["financialImpact"] == round(-deficit_qty * unit_cost, 2)
    assert data["movement"]["movementType"] == "adjustment"
    assert data["movement"]["code"].startswith("ADJ-")

    # Step 1: Direct verification in SQLite file immediately
    conn1 = sqlite3.connect(DATABASE_PATH)
    c1 = conn1.cursor()
    c1.execute("SELECT quantity, stock_level FROM stock_items WHERE id = ?", (item_id,))
    row1 = c1.fetchone()
    assert row1 is not None
    assert round(row1[0], 3) == expected_new_balance

    # Check movement record in SQLite
    mov_code = data["movement"]["code"]
    c1.execute(
        "SELECT stock_item_id, movement_type, quantity, balance_after FROM stock_movements WHERE code = ?",
        (mov_code,),
    )
    mov_row = c1.fetchone()
    assert mov_row is not None
    assert mov_row[0] == item_id
    assert mov_row[1] == "adjustment"
    assert mov_row[2] == -deficit_qty
    assert round(mov_row[3], 3) == expected_new_balance

    # Check audit log in SQLite
    c1.execute("SELECT action, entity_id FROM audit_logs WHERE entity_id = ? ORDER BY timestamp DESC LIMIT 1", (item_id,))
    aud_row = c1.fetchone()
    assert aud_row is not None
    assert aud_row[0] == "STOCK_ADJUSTMENT"
    conn1.close()  # Simulate connection shutdown

    # Step 2: Reopen SQLite connection to test persistence across reopen
    conn2 = sqlite3.connect(DATABASE_PATH)
    c2 = conn2.cursor()
    c2.execute("SELECT quantity FROM stock_items WHERE id = ?", (item_id,))
    row2 = c2.fetchone()
    assert row2 is not None
    assert round(row2[0], 3) == expected_new_balance
    conn2.close()


def test_stock_adjustment_surplus():
    """اختبار تسوية فائض مخزني مع زيادة الرصيد وقيده في SQLite."""
    item_id = "dairy-chd-08"

    conn0 = sqlite3.connect(DATABASE_PATH)
    c0 = conn0.cursor()
    c0.execute("SELECT quantity FROM stock_items WHERE id = ?", (item_id,))
    prev_qty = float(c0.fetchone()[0])
    conn0.close()

    surplus_qty = 5.0
    payload = {
        "itemId": item_id,
        "mode": "surplus",
        "quantity": surplus_qty,
        "reason": "فائض جرد دوري معتمد",
        "userId": "usr_bm1",
    }

    res = client.post(f"{API_V1_STR}/inventory/adjust", json=payload)
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["previousBalance"] == prev_qty
    assert data["adjustedQuantity"] == surplus_qty
    assert data["newBalance"] == round(prev_qty + surplus_qty, 3)

    # SQLite direct check
    conn1 = sqlite3.connect(DATABASE_PATH)
    c1 = conn1.cursor()
    c1.execute("SELECT quantity FROM stock_items WHERE id = ?", (item_id,))
    assert round(c1.fetchone()[0], 3) == round(prev_qty + surplus_qty, 3)
    conn1.close()


def test_stock_adjustment_set_balance():
    """اختبار تسوية جرد فعلي (setBalance) واحتساب الفارق التلقائي وتحديث مستوى المخزون."""
    item_id = "sauce-chd-04"

    # Set new balance to 15.0 (which is above safety stock 8.0 -> available)
    target_balance = 15.0
    payload = {
        "itemId": item_id,
        "mode": "setBalance",
        "quantity": target_balance,
        "reason": "جرد أسبوعي شامل وتحديث الرصيد الفعلي",
        "userId": "usr_bm1",
    }

    res = client.post(f"{API_V1_STR}/inventory/adjust", json=payload)
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["newBalance"] == target_balance
    assert data["item"]["stockLevel"] == "available"

    # Direct SQLite verification
    conn = sqlite3.connect(DATABASE_PATH)
    c = conn.cursor()
    c.execute("SELECT quantity, stock_level FROM stock_items WHERE id = ?", (item_id,))
    row = c.fetchone()
    assert round(row[0], 3) == target_balance
    assert row[1] == "available"
    conn.close()


def test_stock_adjustment_insufficient_balance_acid_rollback():
    """
    اختبار الحوكمة والمعاملة الذرية ACID:
    محاولة تسوية هالك/عجز يتجاوز الرصيد المتاح تفشل برمز 400،
    ويتم التأكد من التراجع الكامل (Rollback) وعدم المساس برصيد الصنف أو إدراج حركة وهمية.
    """
    item_id = "raw-meat-102"

    conn0 = sqlite3.connect(DATABASE_PATH)
    c0 = conn0.cursor()
    c0.execute("SELECT quantity FROM stock_items WHERE id = ?", (item_id,))
    exact_qty_before = float(c0.fetchone()[0])
    c0.execute("SELECT COUNT(*) FROM stock_movements WHERE stock_item_id = ?", (item_id,))
    movements_count_before = c0.fetchone()[0]
    conn0.close()

    # Attempt to deduct 999.0 (far greater than available)
    excessive_qty = 999.0
    payload = {
        "itemId": item_id,
        "mode": "deficit",
        "quantity": excessive_qty,
        "reason": "محاولة خصم غير شرعية تتجاوز الرصيد",
    }

    res = client.post(f"{API_V1_STR}/inventory/adjust", json=payload)
    assert res.status_code == 400
    assert "غير كافٍ" in res.json()["detail"]

    # Verify SQLite state is 100% UNTOUCHED (ACID Invariant)
    conn1 = sqlite3.connect(DATABASE_PATH)
    c1 = conn1.cursor()
    c1.execute("SELECT quantity FROM stock_items WHERE id = ?", (item_id,))
    exact_qty_after = float(c1.fetchone()[0])
    assert exact_qty_after == exact_qty_before, "ACID Invariant Violated: Balance changed despite 400 error!"

    c1.execute("SELECT COUNT(*) FROM stock_movements WHERE stock_item_id = ?", (item_id,))
    movements_count_after = c1.fetchone()[0]
    assert movements_count_after == movements_count_before, "Orphan movement was recorded during failed transaction!"
    conn1.close()


def test_stock_adjustment_alternative_path_route():
    """اختبار المسار البديل POST /api/v1/inventory/{id}/adjust."""
    item_id = "bak-bun-01"

    conn0 = sqlite3.connect(DATABASE_PATH)
    c0 = conn0.cursor()
    c0.execute("SELECT quantity FROM stock_items WHERE id = ?", (item_id,))
    current_qty = float(c0.fetchone()[0])
    conn0.close()

    deduct = 10.0
    payload = {
        "itemId": item_id,
        "mode": "deficit",
        "quantity": deduct,
        "reason": "استبعاد خبز تالف أثناء التغليف",
    }

    res = client.post(f"{API_V1_STR}/inventory/{item_id}/adjust", json=payload)
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["newBalance"] == round(current_qty - deduct, 3)


def test_get_inventory_movements():
    """اختبار استعراض سجل الحركات المخزنية مع الفلترة حسب الصنف ونوع الحركة."""
    res = client.get(f"{API_V1_STR}/inventory/movements?branch_id=br_01")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    movements = body["data"]
    assert len(movements) >= 5

    # Check structure
    first = movements[0]
    assert "code" in first
    assert "stockItemId" in first
    assert "movementType" in first
    assert "quantity" in first
    assert "balanceAfter" in first
    assert "description" in first

    # Filter by movement type 'adjustment'
    res_adj = client.get(f"{API_V1_STR}/inventory/movements?branch_id=br_01&type=adjustment")
    assert res_adj.status_code == 200
    adj_list = res_adj.json()["data"]
    assert len(adj_list) >= 1
    for m in adj_list:
        assert m["movementType"] == "adjustment"


def test_get_inventory_valuation_and_category_breakdown():
    """اختبار تقرير القيمة المالية الإجمالية للمخزون ومطابقة الحسابات الرياضية مع SQLite."""
    # Test both /valuation and alias /value
    res_val = client.get(f"{API_V1_STR}/inventory/valuation?branch_id=br_01")
    assert res_val.status_code == 200
    body = res_val.json()
    assert body["success"] is True
    data = body["data"]

    assert data["branchId"] == "br_01"
    assert data["totalValuation"] > 0
    assert data["totalItems"] >= 6
    assert "byCategory" in data
    assert len(data["byCategory"]) >= 3
    assert "topItems" in data
    assert len(data["topItems"]) <= 5

    # Direct SQLite cross-check of valuation formula: SUM(quantity * unit_cost)
    conn = sqlite3.connect(DATABASE_PATH)
    c = conn.cursor()
    c.execute("SELECT SUM(quantity * unit_cost) FROM stock_items WHERE branch_id = 'br_01'")
    db_sum = round(float(c.fetchone()[0]), 2)
    conn.close()

    assert abs(data["totalValuation"] - db_sum) < 0.05, f"Valuation discrepancy: API={data['totalValuation']} vs DB={db_sum}"

    # Also test /value alias
    res_value = client.get(f"{API_V1_STR}/inventory/value?branch_id=br_01")
    assert res_value.status_code == 200
    assert res_value.json()["data"]["totalValuation"] == data["totalValuation"]
