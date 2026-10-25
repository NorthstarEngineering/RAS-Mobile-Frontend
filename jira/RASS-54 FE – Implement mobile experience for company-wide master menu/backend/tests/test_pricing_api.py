import sqlite3
import pytest
from fastapi.testclient import TestClient
from backend.main import app
from backend.config import DATABASE_PATH
from backend.database.seed_data import seed_database
from backend.services.pricing_service import PricingService

client = TestClient(app)

def setup_module():
    seed_database()
    with sqlite3.connect(DATABASE_PATH) as conn:
        conn.row_factory = sqlite3.Row
        PricingService.ensure_seed_data(conn)

def test_get_price_change_requests_list():
    response = client.get("/api/v1/pricing/requests")
    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    requests = body["data"]
    assert len(requests) >= 5

    # Check structure of the first item
    first = requests[0]
    assert "id" in first
    assert "requestNumber" in first
    assert "itemId" in first
    assert "itemNameAr" in first
    assert "currentPrice" in first
    assert "proposedPrice" in first
    assert "status" in first
    assert "reason" in first
    assert "difference" in first
    assert "percentageChange" in first

def test_get_price_change_requests_filter_status():
    res_pending = client.get("/api/v1/pricing/requests?status=pending")
    assert res_pending.status_code == 200
    for req in res_pending.json()["data"]:
        assert req["status"] == "pending"

    res_approved = client.get("/api/v1/pricing/requests?status=approved")
    assert res_approved.status_code == 200
    for req in res_approved.json()["data"]:
        assert req["status"] == "approved"

    res_rejected = client.get("/api/v1/pricing/requests?status=rejected")
    assert res_rejected.status_code == 200
    for req in res_rejected.json()["data"]:
        assert req["status"] == "rejected"

def test_get_price_request_by_id():
    response = client.get("/api/v1/pricing/requests/pcr_1")
    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    data = body["data"]
    assert data["id"] == "pcr_1"
    assert data["itemId"] == "item_1"
    assert data["currentPrice"] == 120.0
    assert data["proposedPrice"] == 135.0

    res_404 = client.get("/api/v1/pricing/requests/non_existent_pcr_99999")
    assert res_404.status_code == 404

def test_create_price_change_request():
    payload = {
        "itemId": "item_2",
        "proposedPrice": 175.0,
        "reason": "زيادة أسعار الدواجن الطازجة والبهارات بنسبة 10%",
        "effectiveDate": "2024-06-01",
    }
    response = client.post("/api/v1/pricing/requests", json=payload)
    assert response.status_code == 201
    body = response.json()
    assert body["success"] is True
    data = body["data"]
    assert data["itemId"] == "item_2"
    assert data["proposedPrice"] == 175.0
    assert data["status"] == "pending"
    assert data["reason"] == payload["reason"]

    # Verify directly in SQLite database
    conn = sqlite3.connect(DATABASE_PATH)
    cur = conn.cursor()
    cur.execute("SELECT status, proposed_price FROM price_change_requests WHERE id = ?", (data["id"],))
    row = cur.fetchone()
    conn.close()
    assert row is not None
    assert row[0] == "pending"
    assert row[1] == 175.0

def test_approve_price_change_request_acid_transaction():
    """
    اختبار الذرية المحاسبية الصارمة (ACID Transaction):
    تأكيد تحديث جدول menu_items وإدراج سجل جديد في price_history معاً.
    """
    target_item_id = "item_1"

    # 1. Read initial state of the item from menu_items
    conn = sqlite3.connect(DATABASE_PATH)
    cur = conn.cursor()
    cur.execute("SELECT price, cost FROM menu_items WHERE id = ?", (target_item_id,))
    item_row = cur.fetchone()
    initial_price = float(item_row[0])
    item_cost = float(item_row[1])

    cur.execute("SELECT COUNT(*) FROM price_history WHERE menu_item_id = ?", (target_item_id,))
    initial_history_count = cur.fetchone()[0]
    conn.close()

    # 2. Create a pending price request
    new_proposed_price = initial_price + 25.0
    create_payload = {
        "itemId": target_item_id,
        "proposedPrice": new_proposed_price,
        "reason": "تعديل ربع سنوي لتكلفة التشغيل بالفرع الرئيسي",
        "effectiveDate": "2024-07-01",
    }
    create_res = client.post("/api/v1/pricing/requests", json=create_payload)
    assert create_res.status_code == 201
    request_id = create_res.json()["data"]["id"]

    # 3. Approve the price change request
    approve_payload = {
        "approvedByUserId": "usr_ceo",
        "effectiveDate": "2024-07-01",
        "reviewNotes": "معتمد من الإدارة التنفيذية",
    }
    approve_res = client.post(f"/api/v1/pricing/requests/{request_id}/approve", json=approve_payload)
    assert approve_res.status_code == 200
    approved_data = approve_res.json()["data"]
    assert approved_data["status"] == "approved"
    assert approved_data["proposedPrice"] == new_proposed_price

    # 4. ACID Verification 1: Verify menu_items was updated in SQLite
    conn = sqlite3.connect(DATABASE_PATH)
    cur = conn.cursor()
    cur.execute("SELECT price, margin_percent FROM menu_items WHERE id = ?", (target_item_id,))
    updated_item_row = cur.fetchone()
    updated_price = float(updated_item_row[0])
    updated_margin = float(updated_item_row[1])

    assert updated_price == new_proposed_price, f"Expected {new_proposed_price}, got {updated_price}"
    expected_margin = round(((new_proposed_price - item_cost) / new_proposed_price) * 100, 2)
    assert abs(updated_margin - expected_margin) < 0.1

    # 5. ACID Verification 2: Verify price_history has the new historical record
    cur.execute(
        """
        SELECT old_price, new_price, effective_date, approved_by_user_id, reason
        FROM price_history
        WHERE menu_item_id = ?
        ORDER BY created_at DESC
        LIMIT 1
        """,
        (target_item_id,),
    )
    latest_hist = cur.fetchone()
    assert latest_hist is not None
    assert float(latest_hist[0]) == initial_price
    assert float(latest_hist[1]) == new_proposed_price
    assert latest_hist[2] == "2024-07-01"
    assert latest_hist[3] == "usr_ceo"
    assert latest_hist[4] == create_payload["reason"]

    # 6. Verify total history count incremented by exactly 1
    cur.execute("SELECT COUNT(*) FROM price_history WHERE menu_item_id = ?", (target_item_id,))
    new_history_count = cur.fetchone()[0]
    assert new_history_count == initial_history_count + 1

    # 7. ACID Verification 3: Verify audit_logs entry was inserted
    cur.execute(
        "SELECT action, entity_id FROM audit_logs WHERE action = 'APPROVE_PRICE_CHANGE' AND entity_id = ?",
        (request_id,),
    )
    audit_row = cur.fetchone()
    assert audit_row is not None
    conn.close()

    # 8. Repeat approval must fail with 400 Bad Request
    repeat_res = client.post(f"/api/v1/pricing/requests/{request_id}/approve", json=approve_payload)
    assert repeat_res.status_code == 400

def test_reject_price_change_request():
    # 1. Create a request
    create_payload = {
        "itemId": "item_3",
        "proposedPrice": 250.0,
        "reason": "طلب زيادة غير مبررة",
    }
    create_res = client.post("/api/v1/pricing/requests", json=create_payload)
    assert create_res.status_code == 201
    request_id = create_res.json()["data"]["id"]

    # Record item price before rejection
    conn = sqlite3.connect(DATABASE_PATH)
    cur = conn.cursor()
    cur.execute("SELECT price FROM menu_items WHERE id = 'item_3'")
    price_before = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM price_history WHERE menu_item_id = 'item_3'")
    hist_before = cur.fetchone()[0]
    conn.close()

    # 2. Reject request
    reject_res = client.post(
        f"/api/v1/pricing/requests/{request_id}/reject",
        json={"reviewedByUserId": "usr_ceo", "reviewNotes": "مرفوض لتجاوز السقف السعري"},
    )
    assert reject_res.status_code == 200
    assert reject_res.json()["data"]["status"] == "rejected"

    # 3. Verify menu_items price was NOT changed and no history was added
    conn = sqlite3.connect(DATABASE_PATH)
    cur = conn.cursor()
    cur.execute("SELECT price FROM menu_items WHERE id = 'item_3'")
    price_after = cur.fetchone()[0]
    assert price_after == price_before

    cur.execute("SELECT COUNT(*) FROM price_history WHERE menu_item_id = 'item_3'")
    hist_after = cur.fetchone()[0]
    assert hist_after == hist_before
    conn.close()

def test_get_price_history_endpoint():
    response = client.get("/api/v1/pricing/history/item_1")
    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    history = body["data"]
    assert len(history) >= 1

    first = history[0]
    assert "id" in first
    assert "itemId" in first
    assert first["itemId"] == "item_1"
    assert "oldPrice" in first
    assert "newPrice" in first
    assert "effectiveDate" in first
    assert "approvedByName" in first
    assert "reason" in first
    assert "difference" in first
    assert "percentageChange" in first
