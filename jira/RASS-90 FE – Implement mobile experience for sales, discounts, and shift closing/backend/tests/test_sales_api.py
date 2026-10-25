"""
Automated Pytest Suite for RMS Sales & Shift Management Backend.
Verifies all endpoints, SQLite transactions, cash variance (surplus/deficit/exact),
channel breakdown, discounts lifecycle, and audit_logs persistence.
"""

import sqlite3
import json
import pytest
from fastapi.testclient import TestClient
from backend.main import app
from backend.config import API_V1_STR, DATABASE_PATH
from backend.database.seed_data import seed_database
from backend.database.connection import get_db
from backend.routers.sales_router import router as sales_router
from backend.services.sales_service import ensure_sales_schema_and_seed, SalesService

# Ensure sales router is registered in app for tests
if not any(
    getattr(r, "path", None) == f"{API_V1_STR}/sales"
    or getattr(r, "path_format", None) == f"{API_V1_STR}/sales"
    for r in app.routes
):
    app.include_router(sales_router, prefix=API_V1_STR)

client = TestClient(app)


def get_db_cursor():
    conn = sqlite3.connect(DATABASE_PATH, timeout=20.0, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn, conn.cursor()


def setup_module():
    """Ensure database is seeded before running sales tests."""
    seed_database()
    with get_db() as conn:
        ensure_sales_schema_and_seed(conn)


# ---------------------------------------------------------------------------
# Test 1: Dashboard Overview
# ---------------------------------------------------------------------------

def test_sales_dashboard_overview():
    """Verify GET /api/v1/sales/dashboard returns comprehensive channel and shift metrics."""
    res = client.get(f"{API_V1_STR}/sales/dashboard")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    data = body["data"]

    assert "shiftStatus" in data
    assert "totalSales" in data
    assert "netSales" in data
    assert "totalDiscounts" in data
    assert "totalOrders" in data
    assert "dineInRatio" in data
    assert "deliveryRatio" in data
    assert "channels" in data

    assert data["totalSales"] > 0
    assert data["totalOrders"] > 0
    assert len(data["channels"]) == 4

    # Verify channel keys
    keys = [c["channelKey"] for c in data["channels"]]
    assert "dine_in" in keys
    assert "takeaway" in keys
    assert "delivery_apps" in keys
    assert "direct_delivery" in keys


# ---------------------------------------------------------------------------
# Test 2: Restaurant Channel Sales
# ---------------------------------------------------------------------------

def test_restaurant_sales_and_category_filter():
    """Verify GET /api/v1/sales/restaurant with items list, filtering and search."""
    # 1. Fetch all items
    res = client.get(f"{API_V1_STR}/sales/restaurant")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    data = body["data"]
    assert data["totalSales"] > 0
    assert len(data["items"]) >= 3
    assert "الكل" in data["categories"]

    first_item = data["items"][0]
    assert "name" in first_item
    assert "sku" in first_item
    assert "category" in first_item
    assert "unitPrice" in first_item
    assert "totalAmount" in first_item

    # 2. Filter by category
    res_filtered = client.get(f"{API_V1_STR}/sales/restaurant?category=البرجر")
    assert res_filtered.status_code == 200
    f_data = res_filtered.json()["data"]
    for item in f_data["items"]:
        assert item["category"] == "البرجر"

    # 3. Search query
    res_search = client.get(f"{API_V1_STR}/sales/restaurant?query=كلاسيك")
    assert res_search.status_code == 200
    s_data = res_search.json()["data"]
    assert len(s_data["items"]) >= 1
    assert "كلاسيك" in s_data["items"][0]["name"]


# ---------------------------------------------------------------------------
# Test 3: Delivery Channel Sales & Commission Reconciliation
# ---------------------------------------------------------------------------

def test_delivery_sales_and_reconciliation():
    """Verify GET /api/v1/sales/delivery returns delivery platforms and reconciliation."""
    res = client.get(f"{API_V1_STR}/sales/delivery")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    data = body["data"]

    assert data["totalRevenue"] > 0
    assert "reconciliation" in data
    reconcil = data["reconciliation"]
    assert "grossRevenue" in reconcil
    assert "platformCommissions" in reconcil
    assert "netCollected" in reconcil
    assert reconcil["netCollected"] < reconcil["grossRevenue"]


# ---------------------------------------------------------------------------
# Test 4: Open Shift Lifecycle & SQLite Audit Persistence
# ---------------------------------------------------------------------------

def test_open_shift_and_audit_logging():
    """
    Test opening a new shift via POST /api/v1/sales/shift/open:
    Verifies insertion into shifts table and audit_logs entry.
    """
    shift_payload = {
        "branchId": "br_02",
        "cashierUserId": "usr_cashier1",
        "supervisorUserId": "usr_bm1",
        "openingCash": 2500.0,
        "notes": "وردية اختبارية جديدة لفرع المعادي",
    }

    res = client.post(f"{API_V1_STR}/sales/shift/open", json=shift_payload)
    assert res.status_code == 201
    body = res.json()
    assert body["success"] is True
    data = body["data"]
    shift_id = data["id"]
    assert data["status"] == "open"
    assert data["openingCash"] == 2500.0

    # Verify directly in SQLite
    conn, cur = get_db_cursor()
    cur.execute("SELECT * FROM shifts WHERE id = ?", (shift_id,))
    row = cur.fetchone()
    assert row is not None
    assert row["branch_id"] == "br_02"
    assert row["opening_cash"] == 2500.0
    assert row["status"] == "open"

    # Verify audit_logs
    cur.execute(
        "SELECT * FROM audit_logs WHERE action = 'OPEN_SHIFT' AND entity_id = ? ORDER BY timestamp DESC LIMIT 1",
        (shift_id,),
    )
    audit = cur.fetchone()
    assert audit is not None
    assert audit["entity_type"] == "shifts"
    conn.close()


# ---------------------------------------------------------------------------
# Test 5: Shift Sales Entry & Totals Recalculation
# ---------------------------------------------------------------------------

def test_shift_sales_entry_and_totals():
    """
    Test recording shift sales entries via POST /api/v1/sales/shift/entry:
    Verifies shift_sales_entries insertion, total_sales recalculation, and sold items.
    """
    # Open dedicated shift for this test
    open_res = client.post(
        f"{API_V1_STR}/sales/shift/open",
        json={
            "branchId": "br_01",
            "cashierUserId": "usr_cashier1",
            "openingCash": 1000.0,
            "notes": "وردية اختبار تسجيل المبيعات",
        },
    )
    shift_id = open_res.json()["data"]["id"]

    # Entry 1: Cash Dine-In with item breakdown
    entry_payload = {
        "shiftId": shift_id,
        "channel": "dine_in",
        "paymentMethod": "cash",
        "discountAmount": 50.0,
        "orderCount": 2,
        "items": [
            {
                "name": "وجبة دبل برجر كلاسيك",
                "sku": "TST-BRG-99",
                "category": "البرجر",
                "quantity": 2,
                "unitPrice": 200.0,
            }
        ],
    }

    entry_res = client.post(f"{API_V1_STR}/sales/shift/entry", json=entry_payload)
    assert entry_res.status_code == 201
    entry_data = entry_res.json()["data"]
    assert entry_data["shiftId"] == shift_id
    assert entry_data["grossAmount"] == 400.0
    assert entry_data["netAmount"] == 350.0
    assert entry_data["shiftTotalSales"] >= 400.0
    assert entry_data["shiftTotalDiscounts"] >= 50.0

    # Verify in SQLite shift_sales_entries and shift_sold_items
    conn, cur = get_db_cursor()
    cur.execute("SELECT * FROM shift_sales_entries WHERE shift_id = ?", (shift_id,))
    entries = cur.fetchall()
    assert len(entries) >= 1

    cur.execute("SELECT * FROM shift_sold_items WHERE shift_id = ? AND sku = 'TST-BRG-99'", (shift_id,))
    sold_item = cur.fetchone()
    assert sold_item is not None
    assert sold_item["quantity"] == 2
    assert sold_item["total_amount"] == 400.0
    conn.close()


# ---------------------------------------------------------------------------
# Test 6: Shift Closure with Exact Cash Matching
# ---------------------------------------------------------------------------

def test_shift_close_exact_cash_match():
    """
    Test closing a shift with exact cash match (variance = 0.0).
    Opening cash = 1000.0, Cash sales = 500.0 -> System cash = 1500.0.
    Actual closing cash = 1500.0 -> variance = 0.0.
    """
    # 1. Open shift
    open_res = client.post(
        f"{API_V1_STR}/sales/shift/open",
        json={
            "branchId": "br_03",
            "cashierUserId": "usr_cashier1",
            "openingCash": 1000.0,
            "notes": "وردية اختبار المطابقة التامة",
        },
    )
    shift_id = open_res.json()["data"]["id"]

    # 2. Add cash entry of 500.0 net
    client.post(
        f"{API_V1_STR}/sales/shift/entry",
        json={
            "shiftId": shift_id,
            "channel": "takeaway",
            "grossAmount": 500.0,
            "discountAmount": 0.0,
            "netAmount": 500.0,
            "paymentMethod": "cash",
            "orderCount": 4,
        },
    )

    # 3. Close shift with actual cash 1500.0
    close_res = client.post(
        f"{API_V1_STR}/sales/shift/close",
        json={
            "shiftId": shift_id,
            "closingCashActual": 1500.0,
            "supervisorUserId": "usr_bm1",
            "notes": "إغلاق مطابق تماماً دون عجز أو زيادة",
        },
    )
    assert close_res.status_code == 200
    close_data = close_res.json()["data"]
    assert close_data["status"] == "closed"
    assert close_data["closingCashSystem"] == 1500.0
    assert close_data["closingCashActual"] == 1500.0
    assert close_data["cashVariance"] == 0.0

    # Verify SQLite shifts table
    conn, cur = get_db_cursor()
    cur.execute("SELECT * FROM shifts WHERE id = ?", (shift_id,))
    row = cur.fetchone()
    assert row["status"] == "closed"
    assert row["cash_variance"] == 0.0

    # Verify audit_logs
    cur.execute("SELECT * FROM audit_logs WHERE action = 'CLOSE_SHIFT' AND entity_id = ?", (shift_id,))
    audit = cur.fetchone()
    assert audit is not None
    conn.close()


# ---------------------------------------------------------------------------
# Test 7: Shift Closure with Deficit (Shortage / عجز)
# ---------------------------------------------------------------------------

def test_shift_close_deficit_shortage():
    """
    Test closing a shift with shortage/deficit (actual < system).
    Opening cash = 1000.0, Cash sales = 800.0 -> System cash = 1800.0.
    Actual closing cash = 1650.0 -> Variance = -150.0.
    """
    # 1. Open shift
    open_res = client.post(
        f"{API_V1_STR}/sales/shift/open",
        json={
            "branchId": "br_01",
            "cashierUserId": "usr_cashier1",
            "openingCash": 1000.0,
            "notes": "وردية اختبار العجز النقدي",
        },
    )
    shift_id = open_res.json()["data"]["id"]

    # 2. Add cash entry
    client.post(
        f"{API_V1_STR}/sales/shift/entry",
        json={
            "shiftId": shift_id,
            "channel": "dine_in",
            "grossAmount": 800.0,
            "discountAmount": 0.0,
            "netAmount": 800.0,
            "paymentMethod": "cash",
            "orderCount": 5,
        },
    )

    # 3. Close shift with 1650.0 actual cash
    close_res = client.post(
        f"{API_V1_STR}/sales/shift/close",
        json={
            "shiftId": shift_id,
            "closingCashActual": 1650.0,
            "supervisorUserId": "usr_bm1",
            "notes": "عجز بقيمة 150 ج.م قيد التحقيق مع الكاشير",
        },
    )
    assert close_res.status_code == 200
    close_data = close_res.json()["data"]
    assert close_data["closingCashSystem"] == 1800.0
    assert close_data["closingCashActual"] == 1650.0
    assert close_data["cashVariance"] == -150.0

    # Verify SQLite persistence
    conn, cur = get_db_cursor()
    cur.execute("SELECT cash_variance FROM shifts WHERE id = ?", (shift_id,))
    assert cur.fetchone()["cash_variance"] == -150.0
    conn.close()


# ---------------------------------------------------------------------------
# Test 8: Shift Closure with Surplus (زيادة)
# ---------------------------------------------------------------------------

def test_shift_close_surplus():
    """
    Test closing a shift with surplus (actual > system).
    Opening cash = 500.0, Cash sales = 500.0 -> System cash = 1000.0.
    Actual closing cash = 1080.0 -> Variance = +80.0.
    """
    open_res = client.post(
        f"{API_V1_STR}/sales/shift/open",
        json={
            "branchId": "br_02",
            "cashierUserId": "usr_cashier1",
            "openingCash": 500.0,
            "notes": "وردية اختبار الزيادة النقدية",
        },
    )
    shift_id = open_res.json()["data"]["id"]

    client.post(
        f"{API_V1_STR}/sales/shift/entry",
        json={
            "shiftId": shift_id,
            "channel": "takeaway",
            "grossAmount": 500.0,
            "discountAmount": 0.0,
            "netAmount": 500.0,
            "paymentMethod": "cash",
            "orderCount": 3,
        },
    )

    close_res = client.post(
        f"{API_V1_STR}/sales/shift/close",
        json={
            "shiftId": shift_id,
            "closingCashActual": 1080.0,
            "supervisorUserId": "usr_bm1",
            "notes": "زيادة نقدية بقيمة 80 ج.م",
        },
    )
    assert close_res.status_code == 200
    close_data = close_res.json()["data"]
    assert close_data["cashVariance"] == 80.0


# ---------------------------------------------------------------------------
# Test 9: Discounts List and Creation
# ---------------------------------------------------------------------------

def test_discounts_list_and_creation():
    """Test GET /api/v1/sales/discounts and POST /api/v1/sales/discounts."""
    # 1. Get initial discounts
    res = client.get(f"{API_V1_STR}/sales/discounts")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    discounts = body["data"]
    assert len(discounts) >= 1

    first = discounts[0]
    assert "id" in first
    assert "discountCode" in first
    assert "amount" in first
    assert "status" in first

    # 2. Create new discount
    create_res = client.post(
        f"{API_V1_STR}/sales/discounts",
        json={
            "shiftId": "shift_01",
            "discountCode": "AUTOTEST-25",
            "type": "promotional",
            "amount": 75.0,
            "reason": "خصم ترويجي للاختبار الآلي",
            "authorizedByUserId": "usr_bm1",
        },
    )
    assert create_res.status_code == 201
    created = create_res.json()["data"]
    assert created["discountCode"] == "AUTOTEST-25"
    assert created["amount"] == 75.0
    assert created["status"] == "applied"

    # Verify in SQLite
    conn, cur = get_db_cursor()
    cur.execute("SELECT * FROM discounts WHERE id = ?", (created["id"],))
    row = cur.fetchone()
    assert row is not None
    assert row["amount"] == 75.0
    conn.close()


# ---------------------------------------------------------------------------
# Test 10: Discount Cancellation, Reversal & Audit Logging
# ---------------------------------------------------------------------------

def test_discount_cancellation_and_audit():
    """
    Test POST /api/v1/sales/discounts/{id}/cancel:
    Verifies discount status updated to 'cancelled', shift discount reversed,
    and audit log record in audit_logs.
    """
    # Create discount to cancel
    disc_res = client.post(
        f"{API_V1_STR}/sales/discounts",
        json={
            "shiftId": "shift_01",
            "discountCode": "CANCEL-TEST",
            "type": "fixed_amount",
            "amount": 150.0,
            "reason": "خصم تجريبي للإلغاء",
            "authorizedByUserId": "usr_bm1",
        },
    )
    disc_id = disc_res.json()["data"]["id"]

    # Initial shift discounts
    conn, cur = get_db_cursor()
    cur.execute("SELECT total_discounts FROM shifts WHERE id = 'shift_01'")
    initial_shift_discounts = cur.fetchone()["total_discounts"]
    conn.close()

    # Cancel discount
    cancel_res = client.post(
        f"{API_V1_STR}/sales/discounts/{disc_id}/cancel",
        json={
            "reason": "سوء استخدام صلاحية",
            "cancelledByUserId": "usr_bm1",
            "note": "تم إلغاء الخصم لعدم إرفاق بطاقة صلاحية العميل.",
        },
    )
    assert cancel_res.status_code == 200
    cancel_data = cancel_res.json()["data"]
    assert cancel_data["status"] == "cancelled"
    assert "سوء استخدام صلاحية" in cancel_data["cancelReason"]

    # Verify in SQLite discounts table
    conn, cur = get_db_cursor()
    cur.execute("SELECT status, cancel_reason, cancelled_by_user_id FROM discounts WHERE id = ?", (disc_id,))
    d_row = cur.fetchone()
    assert d_row["status"] == "cancelled"
    assert d_row["cancelled_by_user_id"] == "usr_bm1"

    # Verify shift total_discounts decreased by 150.0
    cur.execute("SELECT total_discounts FROM shifts WHERE id = 'shift_01'")
    new_shift_discounts = cur.fetchone()["total_discounts"]
    assert new_shift_discounts == initial_shift_discounts - 150.0

    # Verify audit_logs table
    cur.execute(
        "SELECT * FROM audit_logs WHERE action = 'CANCEL_DISCOUNT' AND entity_id = ? ORDER BY timestamp DESC LIMIT 1",
        (disc_id,),
    )
    audit_row = cur.fetchone()
    assert audit_row is not None
    assert audit_row["entity_type"] == "discounts"
    new_vals = json.loads(audit_row["new_values_json"])
    assert new_vals["status"] == "cancelled"
    conn.close()


# ---------------------------------------------------------------------------
# Test 11: Shift Review and Closed Summary
# ---------------------------------------------------------------------------

def test_shift_review_and_closed_summary():
    """Verify GET /api/v1/sales/shift/review and GET /api/v1/sales/shift/closed."""
    review_res = client.get(f"{API_V1_STR}/sales/shift/review?shiftId=shift_01")
    assert review_res.status_code == 200
    r_body = review_res.json()
    assert r_body["success"] is True
    assert "shiftId" in r_body["data"]
    assert "expectedSystemCash" in r_body["data"]

    closed_res = client.get(f"{API_V1_STR}/sales/shift/closed?shiftId=shift_01")
    assert closed_res.status_code == 200
    c_body = closed_res.json()
    assert c_body["success"] is True


# ---------------------------------------------------------------------------
# Test 12: Error Handling & Invariant Enforcement
# ---------------------------------------------------------------------------

def test_sales_error_handling():
    """Test error handling for non-existent shifts, closed shifts, and double cancellation."""
    # 1. Closing non-existent shift
    bad_close = client.post(
        f"{API_V1_STR}/sales/shift/close",
        json={"shiftId": "non_existent_sft", "closingCashActual": 500.0},
    )
    assert bad_close.status_code in (400, 404)

    # 2. Cancelling non-existent discount
    bad_cancel = client.post(
        f"{API_V1_STR}/sales/discounts/NON_EXISTENT_DISC/cancel",
        json={"reason": "خطأ"},
    )
    assert bad_cancel.status_code in (400, 404)

    # 3. Double cancellation of discount (create fresh discount first)
    fresh_disc = client.post(
        f"{API_V1_STR}/sales/discounts",
        json={
            "shiftId": "shift_01",
            "discountCode": "DOUBLE-CANCEL-TEST",
            "type": "fixed_amount",
            "amount": 50.0,
            "reason": "خصم لاختبار الإلغاء المزدوج",
            "authorizedByUserId": "usr_bm1",
        },
    )
    fresh_id = fresh_disc.json()["data"]["id"]

    first_cancel = client.post(
        f"{API_V1_STR}/sales/discounts/{fresh_id}/cancel",
        json={"reason": "سوء استخدام صلاحية"},
    )
    assert first_cancel.status_code == 200

    second_cancel = client.post(
        f"{API_V1_STR}/sales/discounts/{fresh_id}/cancel",
        json={"reason": "محاولة إلغاء ثانية"},
    )
    assert second_cancel.status_code == 400
    assert "مسبقاً" in second_cancel.json()["detail"]


# ---------------------------------------------------------------------------
# Test 13: Route Plural Aliases Compatibility
# ---------------------------------------------------------------------------

def test_route_plural_aliases():
    """Verify that plural endpoint aliases match the specification and function identically."""
    # 1. Plural open: /api/v1/sales/shifts/open
    open_res = client.post(
        f"{API_V1_STR}/sales/shifts/open",
        json={
            "branchId": "br_03",
            "cashierUserId": "usr_cashier1",
            "openingCash": 3000.0,
            "notes": "اختبار المسار الجمع shifts/open",
        },
    )
    assert open_res.status_code == 201
    shift_id = open_res.json()["data"]["id"]

    # 2. Plural entry with path parameter: /api/v1/sales/shifts/{id}/entries
    entry_res = client.post(
        f"{API_V1_STR}/sales/shifts/{shift_id}/entries",
        json={
            "channel": "takeaway",
            "grossAmount": 600.0,
            "discountAmount": 0.0,
            "paymentMethod": "cash",
            "orderCount": 2,
        },
    )
    assert entry_res.status_code == 201

    # 3. Plural review: /api/v1/sales/shifts/review
    rev_res = client.get(f"{API_V1_STR}/sales/shifts/review?shiftId={shift_id}")
    assert rev_res.status_code == 200
    assert rev_res.json()["data"]["shiftId"] == shift_id

    # 4. Plural close: /api/v1/sales/shifts/{id}/close
    close_res = client.post(
        f"{API_V1_STR}/sales/shifts/{shift_id}/close",
        json={
            "closingCashActual": 3600.0,
            "supervisorUserId": "usr_bm1",
            "notes": "إغلاق عبر المسار الجمع",
        },
    )
    assert close_res.status_code == 200
    assert close_res.json()["data"]["cashVariance"] == 0.0
    assert close_res.json()["data"]["status"] == "closed"

    # 5. Plural closed summary: /api/v1/sales/shifts/closed
    closed_res = client.get(f"{API_V1_STR}/sales/shifts/closed?shiftId={shift_id}")
    assert closed_res.status_code == 200
    assert closed_res.json()["data"]["status"] == "closed"


# ---------------------------------------------------------------------------
# Test 14: Discounts Filtering by Status
# ---------------------------------------------------------------------------

def test_discounts_filter_by_status():
    """Verify GET /api/v1/sales/discounts?status=applied and ?status=cancelled."""
    # Applied discounts
    res_app = client.get(f"{API_V1_STR}/sales/discounts?status=applied")
    assert res_app.status_code == 200
    for d in res_app.json()["data"]:
        assert d["status"] == "applied"

    # Cancelled discounts
    res_canc = client.get(f"{API_V1_STR}/sales/discounts?status=cancelled")
    assert res_canc.status_code == 200
    for d in res_canc.json()["data"]:
        assert d["status"] == "cancelled"


# ---------------------------------------------------------------------------
# Test 15: Full Audit Trail and ACID Integrity Verification
# ---------------------------------------------------------------------------

def test_audit_trail_and_acid_integrity():
    """Verify complete audit trail actions are persisted in audit_logs table."""
    conn, cur = get_db_cursor()
    cur.execute(
        """
        SELECT action, entity_type, COUNT(*) as count
        FROM audit_logs
        WHERE entity_type IN ('shifts', 'shift_sales_entries', 'discounts')
        GROUP BY action, entity_type
        """
    )
    actions = {f"{r['action']}_{r['entity_type']}": r["count"] for r in cur.fetchall()}
    conn.close()

    # Ensure key sales actions are documented in SQLite audit_logs
    assert "OPEN_SHIFT_shifts" in actions
    assert "CLOSE_SHIFT_shifts" in actions
    assert "RECORD_SALES_ENTRY_shift_sales_entries" in actions
    assert "APPLY_DISCOUNT_discounts" in actions
    assert "CANCEL_DISCOUNT_discounts" in actions

