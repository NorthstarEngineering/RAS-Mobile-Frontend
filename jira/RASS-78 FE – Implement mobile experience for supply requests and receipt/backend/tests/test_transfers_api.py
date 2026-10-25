import sqlite3
import pytest
from fastapi.testclient import TestClient

from backend.main import app
from backend.config import DATABASE_PATH, API_V1_STR
from backend.database.seed_data import seed_database
from backend.routers.transfers_router import router as transfers_router
from backend.services.transfers_service import ensure_seed_data
from backend.database.connection import get_db

# Mount transfers router on app if not already present
if not any(
    getattr(r, "path", None) == f"{API_V1_STR}/transfers"
    or getattr(r, "path_format", None) == f"{API_V1_STR}/transfers"
    for r in app.routes
):
    app.include_router(transfers_router, prefix=API_V1_STR)

client = TestClient(app)


def setup_module():
    """Ensure database, schema, and baseline transfer/stock seeds exist."""
    seed_database()
    with get_db() as conn:
        ensure_seed_data(conn)


def test_sqlite_wal_and_transfers_schema():
    """Verify SQLite WAL mode and presence of transfers and transfer_items tables."""
    conn = sqlite3.connect(DATABASE_PATH)
    cur = conn.cursor()
    cur.execute("PRAGMA journal_mode")
    mode = cur.fetchone()[0]
    assert mode.lower() == "wal"

    # Verify tables
    for tbl in ["transfers", "transfer_items", "stock_items", "stock_movements", "audit_logs"]:
        cur.execute(f"SELECT COUNT(*) FROM {tbl}")
        assert cur.fetchone()[0] >= 0
    conn.close()


def test_get_transfers_list():
    """Verify GET /transfers returns baseline orders with nested items and branch names."""
    res = client.get(f"{API_V1_STR}/transfers")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    data = body["data"]
    assert len(data) >= 4

    first = data[0]
    assert "id" in first
    assert "transferCode" in first
    assert "sourceBranchId" in first
    assert "sourceBranchName" in first
    assert "destinationBranchId" in first
    assert "destinationBranchName" in first
    assert "status" in first
    assert "statusLabelAr" in first
    assert "items" in first
    assert len(first["items"]) >= 1

    item0 = first["items"][0]
    assert "stockItemId" in item0
    assert "name" in item0
    assert "quantity" in item0


def test_get_transfers_filtering_and_search():
    """Verify filtering by status, branch_id, and search query."""
    # Filter by status
    res_pending = client.get(f"{API_V1_STR}/transfers?status=pending_review")
    assert res_pending.status_code == 200
    for t in res_pending.json()["data"]:
        assert t["status"] == "pending_review"

    res_transit = client.get(f"{API_V1_STR}/transfers?status=in_transit")
    assert res_transit.status_code == 200
    for t in res_transit.json()["data"]:
        assert t["status"] == "in_transit"

    # Filter by branch
    res_br = client.get(f"{API_V1_STR}/transfers?branchId=br_01")
    assert res_br.status_code == 200
    for t in res_br.json()["data"]:
        assert t["sourceBranchId"] == "br_01" or t["destinationBranchId"] == "br_01"

    # Search by code
    res_search = client.get(f"{API_V1_STR}/transfers?search=TR-5540")
    assert res_search.status_code == 200
    assert len(res_search.json()["data"]) >= 1
    assert res_search.json()["data"][0]["transferCode"] == "TR-5540"


def test_get_transfers_metrics():
    """Verify GET /transfers/metrics returns accurate operational KPIs."""
    res = client.get(f"{API_V1_STR}/transfers/metrics")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    metrics = body["data"]
    assert "pendingReviewCount" in metrics
    assert "inTransitCount" in metrics
    assert "receivedCount" in metrics
    assert "totalTransfers" in metrics
    assert metrics["totalTransfers"] >= 4


def test_get_transfer_by_id_and_code():
    """Verify retrieving transfer by primary key ID and by transfer_code."""
    # By Code
    res_code = client.get(f"{API_V1_STR}/transfers/TR-5540")
    assert res_code.status_code == 200
    data_code = res_code.json()["data"]
    assert data_code["transferCode"] == "TR-5540"
    transfer_uuid = data_code["id"]

    # By UUID
    res_id = client.get(f"{API_V1_STR}/transfers/{transfer_uuid}")
    assert res_id.status_code == 200
    data_id = res_id.json()["data"]
    assert data_id["id"] == transfer_uuid
    assert data_id["transferCode"] == "TR-5540"

    # Non-existent
    res_404 = client.get(f"{API_V1_STR}/transfers/TR-NONEXISTENT-999")
    assert res_404.status_code == 404


def test_create_transfer_and_sqlite_persistence():
    """Verify POST /transfers creates order, validates stock, and persists to SQLite."""
    payload = {
        "sourceBranchId": "br_01",
        "destinationBranchId": "br_03",
        "items": [
            {
                "sku": "CHK-MAR-BR1",
                "quantity": 5.0,
            }
        ],
        "notes": "تحويل تجريبي لتأكيد الديمومة في قاعدة البيانات",
        "isUrgent": True,
    }

    res = client.post(f"{API_V1_STR}/transfers", json=payload)
    assert res.status_code == 201
    body = res.json()
    assert body["success"] is True
    data = body["data"]
    created_id = data["id"]
    code = data["transferCode"]
    assert data["status"] == "pending_review"
    assert data["sourceBranchId"] == "br_01"
    assert data["destinationBranchId"] == "br_03"
    assert len(data["items"]) == 1
    assert data["items"][0]["quantity"] == 5.0

    # Direct SQLite verification
    conn1 = sqlite3.connect(DATABASE_PATH)
    cur1 = conn1.cursor()
    cur1.execute(
        "SELECT id, transfer_code, source_branch_id, destination_branch_id, status FROM transfers WHERE id = ?",
        (created_id,),
    )
    row = cur1.fetchone()
    assert row is not None
    assert row[0] == created_id
    assert row[1] == code
    assert row[2] == "br_01"
    assert row[3] == "br_03"
    assert row[4] == "pending_review"

    # Verify transfer_items in SQLite
    cur1.execute("SELECT quantity FROM transfer_items WHERE transfer_id = ?", (created_id,))
    item_row = cur1.fetchone()
    assert item_row is not None
    assert item_row[0] == 5.0
    conn1.close()

    # Reopen to verify disk durability
    conn2 = sqlite3.connect(DATABASE_PATH)
    cur2 = conn2.cursor()
    cur2.execute("SELECT status FROM transfers WHERE id = ?", (created_id,))
    assert cur2.fetchone()[0] == "pending_review"
    conn2.close()


def test_create_transfer_validation_errors():
    """Verify validation logic for invalid transfers (same branch, insufficient stock)."""
    # 1. Same source and destination branch
    res_same = client.post(
        f"{API_V1_STR}/transfers",
        json={
            "sourceBranchId": "br_01",
            "destinationBranchId": "br_01",
            "items": [{"sku": "CHK-MAR-BR1", "quantity": 2.0}],
        },
    )
    assert res_same.status_code == 400
    assert "متطابقان" in res_same.json()["detail"]

    # 2. Insufficient stock requested
    res_excess = client.post(
        f"{API_V1_STR}/transfers",
        json={
            "sourceBranchId": "br_01",
            "destinationBranchId": "br_02",
            "items": [{"sku": "CHK-MAR-BR1", "quantity": 99999.0}],
        },
    )
    assert res_excess.status_code == 400
    assert "غير كافٍ" in res_excess.json()["detail"]


def test_review_transfer_approval_and_rejection():
    """Verify POST /transfers/{id}/review transitions status and allows adjusting quantities."""
    # Create transfer for review
    res_create = client.post(
        f"{API_V1_STR}/transfers",
        json={
            "sourceBranchId": "br_01",
            "destinationBranchId": "br_02",
            "items": [{"sku": "CHK-MAR-BR1", "quantity": 10.0}],
            "notes": "للمراجعة والاعتماد",
        },
    )
    assert res_create.status_code == 201
    transfer_id = res_create.json()["data"]["id"]
    item_id = res_create.json()["data"]["items"][0]["id"]

    # Approve with adjusted quantity
    res_review = client.post(
        f"{API_V1_STR}/transfers/{transfer_id}/review",
        json={
            "approved": True,
            "decision": "approved",
            "notes": "تمت الموافقة وتعديل الكمية إلى 8 كجم حسب الطاقة التشغيلية",
            "reviewedByUserId": "usr_bm1",
            "approvedQuantities": {item_id: 8.0},
        },
    )
    assert res_review.status_code == 200
    reviewed_data = res_review.json()["data"]
    assert reviewed_data["status"] == "approved"
    assert reviewed_data["items"][0]["quantity"] == 8.0

    # Verify in SQLite directly
    conn = sqlite3.connect(DATABASE_PATH)
    cur = conn.cursor()
    cur.execute("SELECT status, approved_by_user_id FROM transfers WHERE id = ?", (transfer_id,))
    t_row = cur.fetchone()
    assert t_row[0] == "approved"
    assert t_row[1] == "usr_bm1"

    cur.execute("SELECT quantity FROM transfer_items WHERE id = ?", (item_id,))
    assert cur.fetchone()[0] == 8.0
    conn.close()

    # Create another transfer to test rejection
    res_rej_create = client.post(
        f"{API_V1_STR}/transfers",
        json={
            "sourceBranchId": "br_01",
            "destinationBranchId": "br_02",
            "items": [{"sku": "CHK-MAR-BR1", "quantity": 4.0}],
        },
    )
    rej_id = res_rej_create.json()["data"]["id"]

    res_rej = client.post(
        f"{API_V1_STR}/transfers/{rej_id}/review",
        json={
            "approved": False,
            "decision": "rejected",
            "notes": "المخزون محجوز لحفلة نهاية الأسبوع",
        },
    )
    assert res_rej.status_code == 200
    assert res_rej.json()["data"]["status"] == "rejected"


def test_send_transfer_acid_stock_deduction():
    """
    Verify POST /transfers/{id}/send atomically:
    1. Deducts source branch stock.
    2. Writes negative stock_movements entry.
    3. Writes audit_logs entry.
    4. Updates status to in_transit with driver details.
    """
    # 1. Create and approve transfer
    res_create = client.post(
        f"{API_V1_STR}/transfers",
        json={
            "sourceBranchId": "br_01",
            "destinationBranchId": "br_02",
            "items": [{"sku": "RAW-BEEF-01", "quantity": 12.0}],
            "notes": "شحنة لحم بقري مفروم جاهزة للإرسال",
        },
    )
    assert res_create.status_code == 201
    transfer_data = res_create.json()["data"]
    transfer_id = transfer_data["id"]

    client.post(f"{API_V1_STR}/transfers/{transfer_id}/review", json={"approved": True})

    # Check source stock before send
    conn = sqlite3.connect(DATABASE_PATH)
    cur = conn.cursor()
    cur.execute("SELECT quantity FROM stock_items WHERE branch_id = 'br_01' AND sku = 'RAW-BEEF-01'")
    qty_before = cur.fetchone()[0]
    conn.close()

    # 2. Send transfer
    send_payload = {
        "driverName": "أحمد رضوان النجار",
        "driverPhone": "01012345678",
        "vehicle": "سيارة نقل تبريد رقم 02",
        "departureTime": "11:30 AM",
        "temperature": "3.5° مئوية",
        "notes": "تم فحص الشحنة ومطابقة الأوزان",
    }
    res_send = client.post(f"{API_V1_STR}/transfers/{transfer_id}/send", json=send_payload)
    assert res_send.status_code == 200
    send_data = res_send.json()["data"]
    assert send_data["status"] == "in_transit"
    assert send_data["driverName"] == "أحمد رضوان النجار"
    assert send_data["departureTime"] == "11:30 AM"

    # 3. Direct SQLite verification of atomic deduction
    conn = sqlite3.connect(DATABASE_PATH)
    cur = conn.cursor()
    cur.execute("SELECT quantity FROM stock_items WHERE branch_id = 'br_01' AND sku = 'RAW-BEEF-01'")
    qty_after = cur.fetchone()[0]
    assert round(qty_before - qty_after, 3) == 12.0

    # Verify stock movement record
    cur.execute(
        """
        SELECT movement_type, quantity, balance_after 
        FROM stock_movements 
        WHERE branch_id = 'br_01' 
        ORDER BY created_at DESC LIMIT 1
        """
    )
    mov = cur.fetchone()
    assert mov is not None
    assert mov[0] == "transfer"
    assert mov[1] == -12.0
    assert mov[2] == qty_after

    # Verify audit log
    cur.execute(
        "SELECT action, entity_id FROM audit_logs WHERE action = 'TRANSFER_SENT' AND entity_id = ?",
        (transfer_id,),
    )
    assert cur.fetchone() is not None
    conn.close()


def test_acid_rollback_on_send_insufficient_stock():
    """
    Verify ACID transaction rollback:
    If quantity requested exceeds source stock, the transaction MUST roll back.
    Stock remains completely unchanged, transfer remains approved, and no movement is recorded.
    """
    # 1. Create transfer with 5 kg
    res_create = client.post(
        f"{API_V1_STR}/transfers",
        json={
            "sourceBranchId": "br_01",
            "destinationBranchId": "br_02",
            "items": [{"sku": "FRIES-BR1", "quantity": 5.0}],
        },
    )
    assert res_create.status_code == 201
    transfer_id = res_create.json()["data"]["id"]
    client.post(f"{API_V1_STR}/transfers/{transfer_id}/review", json={"approved": True})

    # Read current stock
    conn = sqlite3.connect(DATABASE_PATH)
    cur = conn.cursor()
    cur.execute("SELECT quantity FROM stock_items WHERE branch_id = 'br_01' AND sku = 'FRIES-BR1'")
    initial_stock = cur.fetchone()[0]

    # Artificially alter the transfer_items quantity to 99999 to simulate stock exhaustion
    cur.execute("UPDATE transfer_items SET quantity = 99999.0 WHERE transfer_id = ?", (transfer_id,))
    conn.commit()
    conn.close()

    # 2. Attempt send -> Must fail with 400
    res_fail = client.post(
        f"{API_V1_STR}/transfers/{transfer_id}/send",
        json={"driverName": "سائق تجريبي"},
    )
    assert res_fail.status_code == 400
    assert "غير كافٍ" in res_fail.json()["detail"]

    # 3. Direct SQLite verification that rollback succeeded completely
    conn = sqlite3.connect(DATABASE_PATH)
    cur = conn.cursor()
    cur.execute("SELECT quantity FROM stock_items WHERE branch_id = 'br_01' AND sku = 'FRIES-BR1'")
    stock_after_fail = cur.fetchone()[0]
    assert stock_after_fail == initial_stock  # Untouched

    cur.execute("SELECT status FROM transfers WHERE id = ?", (transfer_id,))
    assert cur.fetchone()[0] == "approved"  # Not in_transit!
    conn.close()


def test_receive_transfer_acid_stock_deposit():
    """
    Verify POST /transfers/{id}/receive atomically:
    1. Deposits received quantity into destination branch stock.
    2. Writes positive stock_movements entry (receipt).
    3. Updates received_quantity in transfer_items.
    4. Updates status to 'received'.
    """
    # 1. Setup in_transit transfer from br_01 to br_02
    res_create = client.post(
        f"{API_V1_STR}/transfers",
        json={
            "sourceBranchId": "br_01",
            "destinationBranchId": "br_02",
            "items": [{"sku": "BUN-BRIO-01", "quantity": 30.0}],
            "notes": "شحنة خبز بريوش",
        },
    )
    t_id = res_create.json()["data"]["id"]
    client.post(f"{API_V1_STR}/transfers/{t_id}/review", json={"approved": True})
    client.post(f"{API_V1_STR}/transfers/{t_id}/send", json={"driverName": "علي حسن"})

    # Check destination branch stock before receive
    conn = sqlite3.connect(DATABASE_PATH)
    cur = conn.cursor()
    cur.execute("SELECT quantity FROM stock_items WHERE branch_id = 'br_02' AND sku = 'BUN-BRIO-01'")
    dest_qty_before = cur.fetchone()[0]
    conn.close()

    # 2. Receive transfer (with 28 accepted and 2 damaged noted)
    rec_payload = {
        "receivedByUserId": "usr_bm1",
        "arrivalTime": "01:15 PM",
        "receivedItems": [{"stockItemId": "stock_br1_bun", "receivedQuantity": 28.0}],
        "hasDamage": True,
        "damageNotes": "تم استبعاد 2 قطعة بسبب تلف التغليف الخارجي أثناء النقل",
    }
    res_rec = client.post(f"{API_V1_STR}/transfers/{t_id}/receive", json=rec_payload)
    assert res_rec.status_code == 200
    rec_data = res_rec.json()["data"]
    assert rec_data["status"] == "received"
    assert rec_data["arrivalTime"] == "01:15 PM"
    assert "تلف" in rec_data["notes"]

    # 3. Direct SQLite verification
    conn = sqlite3.connect(DATABASE_PATH)
    cur = conn.cursor()
    cur.execute("SELECT quantity FROM stock_items WHERE branch_id = 'br_02' AND sku = 'BUN-BRIO-01'")
    dest_qty_after = cur.fetchone()[0]
    assert round(dest_qty_after - dest_qty_before, 3) == 28.0

    # Verify received quantity in transfer_items
    cur.execute("SELECT received_quantity FROM transfer_items WHERE transfer_id = ?", (t_id,))
    assert cur.fetchone()[0] == 28.0

    # Verify stock movement (receipt)
    cur.execute(
        """
        SELECT movement_type, quantity, balance_after 
        FROM stock_movements 
        WHERE branch_id = 'br_02' 
        ORDER BY created_at DESC LIMIT 1
        """
    )
    mov = cur.fetchone()
    assert mov[0] == "receipt"
    assert mov[1] == 28.0
    assert mov[2] == dest_qty_after

    # Verify audit log
    cur.execute(
        "SELECT action, entity_id FROM audit_logs WHERE action = 'TRANSFER_RECEIVED' AND entity_id = ?",
        (t_id,),
    )
    assert cur.fetchone() is not None
    conn.close()


def test_full_inter_branch_transfer_lifecycle_and_sqlite_durability():
    """
    End-to-End full lifecycle test across two branches:
    Create -> Review/Approve -> Send -> Receive -> Verify SQLite WAL persistence.
    """
    src_branch = "br_01"
    dest_branch = "br_03"
    transfer_qty = 7.0

    # 1. Initial Balances
    conn = sqlite3.connect(DATABASE_PATH)
    cur = conn.cursor()
    cur.execute("SELECT quantity FROM stock_items WHERE branch_id = ? AND sku = 'CHK-MAR-BR1'", (src_branch,))
    src_initial = cur.fetchone()[0]

    cur.execute("SELECT quantity FROM stock_items WHERE branch_id = ? AND sku = 'CHK-MAR-BR1'", (dest_branch,))
    dest_initial = cur.fetchone()[0]
    conn.close()

    # 2. Create Transfer
    create_res = client.post(
        f"{API_V1_STR}/transfers",
        json={
            "sourceBranchId": src_branch,
            "destinationBranchId": dest_branch,
            "items": [{"sku": "CHK-MAR-BR1", "quantity": transfer_qty}],
            "notes": "دورة تحويل شاملة كاملة",
        },
    )
    assert create_res.status_code == 201
    transfer = create_res.json()["data"]
    t_id = transfer["id"]
    assert transfer["status"] == "pending_review"

    # 3. Review & Approve
    review_res = client.post(
        f"{API_V1_STR}/transfers/{t_id}/review",
        json={"approved": True, "notes": "معتمد بالكامل"},
    )
    assert review_res.status_code == 200
    assert review_res.json()["data"]["status"] == "approved"

    # 4. Send Transfer (Deducts Source)
    send_res = client.post(
        f"{API_V1_STR}/transfers/{t_id}/send",
        json={
            "driverName": "عصام المنصور",
            "driverPhone": "01234567890",
            "departureTime": "02:00 PM",
        },
    )
    assert send_res.status_code == 200
    assert send_res.json()["data"]["status"] == "in_transit"

    # Verify source deducted immediately
    conn = sqlite3.connect(DATABASE_PATH)
    cur = conn.cursor()
    cur.execute("SELECT quantity FROM stock_items WHERE branch_id = ? AND sku = 'CHK-MAR-BR1'", (src_branch,))
    assert round(src_initial - cur.fetchone()[0], 3) == transfer_qty
    conn.close()

    # 5. Receive Transfer (Deposits Destination)
    receive_res = client.post(
        f"{API_V1_STR}/transfers/{t_id}/receive",
        json={
            "receivedByUserId": "usr_bm1",
            "arrivalTime": "03:15 PM",
        },
    )
    assert receive_res.status_code == 200
    assert receive_res.json()["data"]["status"] == "received"

    # Verify destination increased immediately
    conn = sqlite3.connect(DATABASE_PATH)
    cur = conn.cursor()
    cur.execute("SELECT quantity FROM stock_items WHERE branch_id = ? AND sku = 'CHK-MAR-BR1'", (dest_branch,))
    assert round(cur.fetchone()[0] - dest_initial, 3) == transfer_qty
    conn.close()

    # 6. Verify durability across freshly opened connection
    fresh_conn = sqlite3.connect(DATABASE_PATH)
    fcur = fresh_conn.cursor()
    fcur.execute("SELECT status, driver_name, arrival_time FROM transfers WHERE id = ?", (t_id,))
    final_row = fcur.fetchone()
    assert final_row[0] == "received"
    assert final_row[1] == "عصام المنصور"
    assert final_row[2] == "03:15 PM"
    fresh_conn.close()
