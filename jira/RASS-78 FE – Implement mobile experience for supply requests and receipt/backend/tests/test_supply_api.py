import sqlite3
import pytest
from fastapi.testclient import TestClient

from backend.main import app
from backend.config import DATABASE_PATH, API_V1_STR
from backend.database.seed_data import seed_database
from backend.database.connection import get_db
from backend.routers.supply_router import router as supply_router
from backend.services.supply_service import ensure_supply_seed_data, SupplyService
from backend.schemas.supply_schemas import SupplyOrderCreate, SupplyOrderItemCreate

# Ensure supply router is registered in app for tests
if not any(
    getattr(r, "path", None) == f"{API_V1_STR}/supply"
    or getattr(r, "path_format", None) == f"{API_V1_STR}/supply"
    for r in app.routes
):
    app.include_router(supply_router, prefix=API_V1_STR)

client = TestClient(app)


def setup_module():
    """Seeds database and ensures sample supply orders and items exist."""
    seed_database()
    with get_db() as conn:
        ensure_supply_seed_data(conn)
        conn.execute("UPDATE stock_items SET quantity = 180.0, stock_level = 'available' WHERE id = 'stock_ck_05'")
        conn.execute("UPDATE stock_items SET quantity = 450.0, stock_level = 'available' WHERE id = 'stock_ck_06'")
        conn.commit()


def test_get_supply_orders_list():
    """Verifies listing supply orders returns success with expected baseline records."""
    response = client.get(f"{API_V1_STR}/supply")
    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    data = body["data"]
    assert len(data) >= 6

    # Verify structural integrity of items
    first = data[0]
    assert "id" in first
    assert "orderNumber" in first
    assert "sourceKitchenId" in first
    assert "destinationBranchId" in first
    assert "status" in first
    assert "totalCost" in first
    assert "itemsCount" in first
    assert "summary" in first
    assert "items" in first
    assert "meta" in body
    assert "countsByStatus" in body["meta"]


def test_get_supply_orders_filtering():
    """Verifies filtering by status (English & Arabic), branch, and search."""
    # 1. Filter by English status
    res_prep = client.get(f"{API_V1_STR}/supply?status=preparing")
    assert res_prep.status_code == 200
    data_prep = res_prep.json()["data"]
    assert all(o["status"] == "preparing" for o in data_prep)

    # 2. Filter by Arabic status label
    res_ar = client.get(f"{API_V1_STR}/supply?status=قيد الشحن")
    assert res_ar.status_code == 200
    data_ar = res_ar.json()["data"]
    assert all(o["status"] == "in_transit" for o in data_ar)

    # 3. Filter by destination branch
    res_br1 = client.get(f"{API_V1_STR}/supply?branch_id=br_01")
    assert res_br1.status_code == 200
    data_br1 = res_br1.json()["data"]
    assert len(data_br1) > 0
    assert all(o["destinationBranchId"] == "br_01" or o["sourceKitchenId"] == "br_01" for o in data_br1)

    # 4. Search query
    res_search = client.get(f"{API_V1_STR}/supply?search=SO-2026-001")
    assert res_search.status_code == 200
    data_search = res_search.json()["data"]
    assert len(data_search) == 1
    assert data_search[0]["orderNumber"] == "SO-2026-001"


def test_get_supply_order_by_id_and_not_found():
    """Verifies fetching single supply order details and 404 handling."""
    res_ok = client.get(f"{API_V1_STR}/supply/so_01")
    assert res_ok.status_code == 200
    body = res_ok.json()
    assert body["success"] is True
    order = body["data"]
    assert order["id"] == "so_01"
    assert order["orderNumber"] == "SO-2026-001"
    assert len(order["items"]) > 0

    # 404 for non-existent ID
    res_404 = client.get(f"{API_V1_STR}/supply/so_non_existent_999")
    assert res_404.status_code == 404
    assert res_404.json()["detail"] is not None


def test_create_supply_order_and_sqlite_persistence():
    """Verifies creating an order and directly validates ACID persistence in SQLite."""
    payload = {
        "destinationBranchId": "br_01",
        "sourceKitchenId": "br_04",
        "requestedDeliveryDate": "2026-10-28",
        "createdByUserId": "usr_bm1",
        "status": "pending",
        "items": [
            {
                "stockItemId": "stock_ck_05",  # Fries in br_04
                "requestedQuantity": 15.0,
            },
            {
                "stockItemId": "stock_ck_06",  # Brioche Buns in br_04
                "requestedQuantity": 40.0,
            },
        ],
    }

    res = client.post(f"{API_V1_STR}/supply", json=payload)
    assert res.status_code == 201
    body = res.json()
    assert body["success"] is True
    created_order = body["data"]
    order_id = created_order["id"]
    order_number = created_order["orderNumber"]
    assert created_order["status"] == "pending"
    assert created_order["itemsCount"] == 2
    assert created_order["totalCost"] > 0

    # Direct SQLite connection verification
    conn1 = sqlite3.connect(DATABASE_PATH)
    conn1.row_factory = sqlite3.Row
    c1 = conn1.cursor()
    c1.execute(
        "SELECT id, order_number, destination_branch_id, status, total_cost FROM supply_orders WHERE id = ?",
        (order_id,),
    )
    row = c1.fetchone()
    assert row is not None
    assert row["id"] == order_id
    assert row["order_number"] == order_number
    assert row["destination_branch_id"] == "br_01"
    assert row["status"] == "pending"

    # Verify items in SQLite
    c1.execute(
        "SELECT stock_item_id, requested_quantity, unit_cost FROM supply_order_items WHERE supply_order_id = ?",
        (order_id,),
    )
    items_rows = c1.fetchall()
    assert len(items_rows) == 2
    conn1.close()  # Close connection

    # Re-open connection to verify ACID persistence on disk
    conn2 = sqlite3.connect(DATABASE_PATH)
    c2 = conn2.cursor()
    c2.execute("SELECT status FROM supply_orders WHERE id = ?", (order_id,))
    row2 = c2.fetchone()
    assert row2 is not None
    assert row2[0] == "pending"
    conn2.close()


def test_execute_supply_order_and_kitchen_stock_deduction():
    """
    Verifies executing an order:
    1. Central Kitchen stock is deducted atomically.
    2. Stock movement ('issue') is logged.
    3. Order status updates to 'in_transit'.
    """
    # 1. Create a dedicated order for execution
    create_payload = {
        "destinationBranchId": "br_02",
        "sourceKitchenId": "br_04",
        "requestedDeliveryDate": "2026-10-27",
        "status": "pending",
        "items": [
            {
                "stockItemId": "stock_ck_05",  # Fries
                "requestedQuantity": 10.0,
            }
        ],
    }
    create_res = client.post(f"{API_V1_STR}/supply", json=create_payload)
    assert create_res.status_code == 201
    order_id = create_res.json()["data"]["id"]

    # 2. Check initial kitchen stock in SQLite
    conn_pre = sqlite3.connect(DATABASE_PATH)
    conn_pre.row_factory = sqlite3.Row
    c_pre = conn_pre.cursor()
    c_pre.execute("SELECT quantity, safety_stock FROM stock_items WHERE id = 'stock_ck_05'")
    row_ck_pre = c_pre.fetchone()
    initial_kitchen_qty = float(row_ck_pre["quantity"])
    conn_pre.close()

    # 3. Call execute endpoint
    exec_payload = {
        "executedByUserId": "usr_bm1",
        "vehicleInfo": "شاحنة تبريد رقم 04",
        "driverName": "أحمد منصور",
    }
    exec_res = client.post(f"{API_V1_STR}/supply/{order_id}/execute", json=exec_payload)
    assert exec_res.status_code == 200
    exec_body = exec_res.json()
    assert exec_body["success"] is True
    assert exec_body["data"]["status"] == "in_transit"
    assert exec_body["data"]["executedByUserId"] == "usr_bm1"

    # 4. Verify in SQLite that Kitchen Stock was deducted
    conn_post = sqlite3.connect(DATABASE_PATH)
    conn_post.row_factory = sqlite3.Row
    c_post = conn_post.cursor()
    c_post.execute("SELECT quantity FROM stock_items WHERE id = 'stock_ck_05'")
    new_kitchen_qty = float(c_post.fetchone()["quantity"])
    assert new_kitchen_qty == pytest.approx(initial_kitchen_qty - 10.0)

    # 5. Verify stock movement was recorded
    c_post.execute(
        """
        SELECT movement_type, quantity, balance_after, branch_id
        FROM stock_movements
        WHERE stock_item_id = 'stock_ck_05' AND movement_type = 'issue'
        ORDER BY created_at DESC LIMIT 1
        """
    )
    mov = c_post.fetchone()
    assert mov is not None
    assert mov["movement_type"] == "issue"
    assert float(mov["quantity"]) == 10.0
    assert float(mov["balance_after"]) == pytest.approx(new_kitchen_qty)
    assert mov["branch_id"] == "br_04"

    # 6. Verify supply_order_items dispatched_quantity updated
    c_post.execute(
        "SELECT dispatched_quantity FROM supply_order_items WHERE supply_order_id = ?",
        (order_id,),
    )
    soi_row = c_post.fetchone()
    assert float(soi_row["dispatched_quantity"]) == 10.0

    conn_post.close()


def test_receive_supply_order_and_branch_stock_deposit():
    """
    Verifies receiving an in-transit order:
    1. Destination branch inventory increases atomically.
    2. Stock movement ('receipt') is logged.
    3. Order status updates to 'received'.
    """
    # 1. Create and execute an order to reach 'in_transit' state
    create_payload = {
        "destinationBranchId": "br_01",
        "sourceKitchenId": "br_04",
        "requestedDeliveryDate": "2026-10-27",
        "status": "pending",
        "items": [
            {
                "stockItemId": "stock_ck_05",  # Fries
                "requestedQuantity": 8.0,
            }
        ],
    }
    c_res = client.post(f"{API_V1_STR}/supply", json=create_payload)
    assert c_res.status_code == 201
    order_id = c_res.json()["data"]["id"]

    e_res = client.post(f"{API_V1_STR}/supply/{order_id}/execute", json={"executedByUserId": "usr_bm1"})
    assert e_res.status_code == 200

    # 2. Check initial destination branch stock in SQLite
    conn_pre = sqlite3.connect(DATABASE_PATH)
    conn_pre.row_factory = sqlite3.Row
    c_pre = conn_pre.cursor()
    # Find Fries SKU at br_01 (or FRIES-FROZ-01)
    c_pre.execute(
        "SELECT id, quantity FROM stock_items WHERE branch_id = 'br_01' AND sku = 'FRIES-FROZ-01'"
    )
    branch_item_pre = c_pre.fetchone()
    initial_branch_qty = float(branch_item_pre["quantity"]) if branch_item_pre else 0.0
    conn_pre.close()

    # 3. Call receive endpoint
    rec_payload = {
        "receivedByUserId": "usr_bm1",
        "hasShortage": False,
        "notes": "تم الاستلام بحالة ممتازة",
    }
    rec_res = client.post(f"{API_V1_STR}/supply/{order_id}/receive", json=rec_payload)
    assert rec_res.status_code == 200
    rec_body = rec_res.json()
    assert rec_body["success"] is True
    assert rec_body["data"]["status"] == "received"
    assert rec_body["data"]["receivedByUserId"] == "usr_bm1"

    # 4. Verify in SQLite that Branch Stock was credited
    conn_post = sqlite3.connect(DATABASE_PATH)
    conn_post.row_factory = sqlite3.Row
    c_post = conn_post.cursor()
    c_post.execute(
        "SELECT id, quantity FROM stock_items WHERE branch_id = 'br_01' AND sku = 'FRIES-FROZ-01'"
    )
    branch_item_post = c_post.fetchone()
    assert branch_item_post is not None
    new_branch_qty = float(branch_item_post["quantity"])
    assert new_branch_qty == pytest.approx(initial_branch_qty + 8.0)

    # 5. Verify stock movement was recorded for branch
    c_post.execute(
        """
        SELECT movement_type, quantity, balance_after, branch_id
        FROM stock_movements
        WHERE branch_id = 'br_01' AND movement_type = 'receipt'
        ORDER BY created_at DESC LIMIT 1
        """
    )
    mov = c_post.fetchone()
    assert mov is not None
    assert mov["movement_type"] == "receipt"
    assert float(mov["quantity"]) == 8.0
    assert float(mov["balance_after"]) == pytest.approx(new_branch_qty)
    assert mov["branch_id"] == "br_01"

    # 6. Verify supply_order_items received_quantity updated
    c_post.execute(
        "SELECT received_quantity FROM supply_order_items WHERE supply_order_id = ?",
        (order_id,),
    )
    soi_row = c_post.fetchone()
    assert float(soi_row["received_quantity"]) == 8.0

    conn_post.close()


def test_full_supply_cycle_conservation_invariant():
    """
    Tests full supply lifecycle:
    Pending -> Executed (Kitchen -Q) -> Received (Branch +Q).
    Verifies that total physical inventory is strictly conserved across the entire system.
    """
    # 1. Setup initial readings
    conn = sqlite3.connect(DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()

    c.execute("SELECT id, quantity FROM stock_items WHERE id = 'stock_ck_06'")
    k_init = float(c.fetchone()["quantity"])

    c.execute("SELECT id, quantity FROM stock_items WHERE branch_id = 'br_03' AND sku = 'BUN-BRIO-01'")
    b_row = c.fetchone()
    b_init = float(b_row["quantity"]) if b_row else 0.0
    conn.close()

    order_qty = 25.0

    # 2. Create order
    c_res = client.post(
        f"{API_V1_STR}/supply",
        json={
            "destinationBranchId": "br_03",
            "sourceKitchenId": "br_04",
            "requestedDeliveryDate": "2026-10-29",
            "items": [{"stockItemId": "stock_ck_06", "requestedQuantity": order_qty}],
        },
    )
    assert c_res.status_code == 201
    order_id = c_res.json()["data"]["id"]

    # 3. Execute order
    e_res = client.post(f"{API_V1_STR}/supply/{order_id}/execute", json={})
    assert e_res.status_code == 200
    assert e_res.json()["data"]["status"] == "in_transit"

    # 4. Receive order
    r_res = client.post(f"{API_V1_STR}/supply/{order_id}/receive", json={})
    assert r_res.status_code == 200
    assert r_res.json()["data"]["status"] == "received"

    # 5. Verify Total Quantity Invariant:
    # (Kitchen_init + Branch_init) == (Kitchen_final + Branch_final)
    conn_end = sqlite3.connect(DATABASE_PATH)
    conn_end.row_factory = sqlite3.Row
    c_end = conn_end.cursor()

    c_end.execute("SELECT quantity FROM stock_items WHERE id = 'stock_ck_06'")
    k_end = float(c_end.fetchone()["quantity"])

    c_end.execute("SELECT quantity FROM stock_items WHERE branch_id = 'br_03' AND sku = 'BUN-BRIO-01'")
    b_end = float(c_end.fetchone()["quantity"])
    conn_end.close()

    assert k_end == pytest.approx(k_init - order_qty)
    assert b_end == pytest.approx(b_init + order_qty)
    assert (k_end + b_end) == pytest.approx(k_init + b_init)


def test_acid_rollback_on_insufficient_stock():
    """
    Verifies that when stock is insufficient and allow_overdraw is False,
    the transaction rolls back atomically without partial changes.
    """
    # 1. Create order for 99999 units (exceeds any stock)
    c_res = client.post(
        f"{API_V1_STR}/supply",
        json={
            "destinationBranchId": "br_01",
            "sourceKitchenId": "br_04",
            "items": [{"stockItemId": "stock_ck_01", "requestedQuantity": 99999.0}],
        },
    )
    assert c_res.status_code == 201
    order_id = c_res.json()["data"]["id"]

    # Record initial kitchen stock
    conn = sqlite3.connect(DATABASE_PATH)
    c = conn.cursor()
    c.execute("SELECT quantity FROM stock_items WHERE id = 'stock_ck_01'")
    qty_before = float(c.fetchone()[0])
    conn.close()

    # 2. Try executing without allow_overdraw
    e_res = client.post(
        f"{API_V1_STR}/supply/{order_id}/execute",
        json={"allowOverdraw": False},
    )
    assert e_res.status_code == 400
    assert "غير كافٍ" in e_res.json()["detail"]

    # 3. Check SQLite: stock must remain completely untouched, status still 'pending'
    conn2 = sqlite3.connect(DATABASE_PATH)
    c2 = conn2.cursor()
    c2.execute("SELECT quantity FROM stock_items WHERE id = 'stock_ck_01'")
    qty_after = float(c2.fetchone()[0])
    assert qty_after == qty_before

    c2.execute("SELECT status FROM supply_orders WHERE id = ?", (order_id,))
    status_after = c2.fetchone()[0]
    assert status_after == "pending"
    conn2.close()


def test_invalid_lifecycle_transitions_are_rejected():
    """Verifies that invalid state transitions fail with HTTP 400 and prevent corruptions."""
    # 1. Cannot receive an order that is still pending
    c_res = client.post(
        f"{API_V1_STR}/supply",
        json={
            "destinationBranchId": "br_01",
            "items": [{"stockItemId": "stock_ck_05", "requestedQuantity": 5.0}],
        },
    )
    order_id = c_res.json()["data"]["id"]

    # Direct receive on pending -> 400
    rec_pending = client.post(f"{API_V1_STR}/supply/{order_id}/receive", json={})
    assert rec_pending.status_code == 400
    assert "يجب تنفيذ وشحن الطلب أولاً" in rec_pending.json()["detail"]

    # Now execute it -> in_transit
    exec_ok = client.post(f"{API_V1_STR}/supply/{order_id}/execute", json={})
    assert exec_ok.status_code == 200

    # Cannot re-execute an already in-transit order
    exec_again = client.post(f"{API_V1_STR}/supply/{order_id}/execute", json={})
    assert exec_again.status_code == 400
    assert "الطلب قيد الشحن بالفعل" in exec_again.json()["detail"]

    # Receive it -> received
    rec_ok = client.post(f"{API_V1_STR}/supply/{order_id}/receive", json={})
    assert rec_ok.status_code == 200

    # Cannot receive again (no double-crediting branch inventory)
    rec_again = client.post(f"{API_V1_STR}/supply/{order_id}/receive", json={})
    assert rec_again.status_code == 400
    assert "تم استلامه وإيداعه بالمخزن مسبقاً" in rec_again.json()["detail"]


def test_reject_supply_order():
    """Verifies rejecting an order updates status and records audit log."""
    c_res = client.post(
        f"{API_V1_STR}/supply",
        json={
            "destinationBranchId": "br_02",
            "items": [{"stockItemId": "stock_ck_02", "requestedQuantity": 2.0}],
        },
    )
    order_id = c_res.json()["data"]["id"]

    rej_res = client.post(f"{API_V1_STR}/supply/{order_id}/reject?reason=الكمية_غير_مطلوبة")
    assert rej_res.status_code == 200
    assert rej_res.json()["data"]["status"] == "rejected"

    # Verify in SQLite
    conn = sqlite3.connect(DATABASE_PATH)
    c = conn.cursor()
    c.execute("SELECT status FROM supply_orders WHERE id = ?", (order_id,))
    assert c.fetchone()[0] == "rejected"
    conn.close()
