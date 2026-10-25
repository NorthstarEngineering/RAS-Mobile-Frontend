import json
import sqlite3
import pytest
from fastapi.testclient import TestClient

from backend.main import app
from backend.config import DATABASE_PATH, API_V1_STR
from backend.database.seed_data import seed_database
from backend.routers.overtime_router import router as overtime_router
from backend.services.overtime_service import ensure_seed_data
from backend.database.connection import get_db

# Ensure overtime router is registered in app for tests
if not any(
    getattr(r, "path", None) == f"{API_V1_STR}/overtime"
    or getattr(r, "path_format", None) == f"{API_V1_STR}/overtime"
    for r in app.routes
):
    app.include_router(overtime_router, prefix=API_V1_STR)

client = TestClient(app)


def setup_module():
    seed_database()
    with get_db() as conn:
        ensure_seed_data(conn)


def test_get_overtime_records():
    response = client.get(f"{API_V1_STR}/overtime")
    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    data = body["data"]
    assert len(data) >= 3

    # Verify structure of first record
    first = data[0]
    assert "id" in first
    assert "employeeName" in first
    assert "employeeCode" in first
    assert "role" in first
    assert "hours" in first
    assert "rateMultiplier" in first
    assert "calculatedAmount" in first
    assert "overtimePay" in first
    assert "status" in first
    assert "reason" in first


def test_get_overtime_by_id():
    response = client.get(f"{API_V1_STR}/overtime/ot_01")
    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["data"]["id"] == "ot_01"
    assert "أحمد محمود" in body["data"]["employeeName"] or "مصطفى خالد" in body["data"]["employeeName"]

    # Test non-existent id
    notFound = client.get(f"{API_V1_STR}/overtime/ot_non_existent_9999")
    assert notFound.status_code == 404


def test_create_overtime_and_sqlite_persistence():
    payload = {
        "employeeId": "emp_02",
        "branchId": "br_01",
        "date": "2024-04-25",
        "hours": 4.0,
        "rateMultiplier": 1.5,
        "hourlyRate": 42.0,
        "reason": "تغطية وردية مسائية استثنائية لحفل زفاف",
    }

    res = client.post(f"{API_V1_STR}/overtime", json=payload)
    assert res.status_code == 201
    body = res.json()
    assert body["success"] is True
    data = body["data"]
    record_id = data["id"]
    assert data["hours"] == 4.0
    assert data["calculatedAmount"] == 252.0  # 4 * 42 * 1.5
    assert data["status"] == "pending_review"

    # 1. Direct SQLite database verification
    conn1 = sqlite3.connect(DATABASE_PATH)
    c1 = conn1.cursor()
    c1.execute(
        """
        SELECT employee_id, branch_id, date, hours, rate_multiplier, calculated_amount, reason, status
        FROM overtime_records WHERE id = ?
        """,
        (record_id,),
    )
    row = c1.fetchone()
    assert row is not None
    assert row[0] == "emp_02"
    assert row[1] == "br_01"
    assert row[2] == "2024-04-25"
    assert row[3] == 4.0
    assert row[4] == 1.5
    assert row[5] == 252.0
    assert row[6] == payload["reason"]
    assert row[7] == "pending_review"

    # 2. Verify Audit Log entry in SQLite
    c1.execute(
        """
        SELECT action, entity_type, entity_id, new_values_json
        FROM audit_logs WHERE entity_id = ? AND action = 'CREATE'
        """,
        (record_id,),
    )
    audit_row = c1.fetchone()
    assert audit_row is not None
    assert audit_row[0] == "CREATE"
    assert audit_row[1] == "overtime_record"
    assert audit_row[2] == record_id
    conn1.close()  # Simulate close

    # 3. Reopen & Re-verify persistence across connection closures
    conn2 = sqlite3.connect(DATABASE_PATH)
    c2 = conn2.cursor()
    c2.execute("SELECT id, status FROM overtime_records WHERE id = ?", (record_id,))
    row2 = c2.fetchone()
    assert row2 is not None
    assert row2[0] == record_id
    assert row2[1] == "pending_review"
    conn2.close()


def test_review_overtime_record():
    # Create record to review
    create_res = client.post(
        f"{API_V1_STR}/overtime",
        json={
            "employeeId": "emp_01",
            "branchId": "br_01",
            "date": "2024-04-26",
            "hours": 3.0,
            "rateMultiplier": 1.5,
            "hourlyRate": 45.0,
            "reason": "مساعدة في إعداد بوفيه خارجي",
        },
    )
    assert create_res.status_code == 201
    record_id = create_res.json()["data"]["id"]

    # Review with PATCH
    review_payload = {
        "reviewerId": "usr_bm1",
        "decisionReason": "تمت مراجعة الساعات وتعديلها لتصبح ساعتين وفق جدول العمل",
        "hours": 2.0,
    }
    review_res = client.patch(f"{API_V1_STR}/overtime/{record_id}/review", json=review_payload)
    assert review_res.status_code == 200
    body = review_res.json()
    assert body["success"] is True
    data = body["data"]
    assert data["hours"] == 2.0
    assert data["calculatedAmount"] == 135.0  # 2.0 * 45 * 1.5
    assert data["decisionReason"] == review_payload["decisionReason"]

    # Verify audit log in SQLite
    conn = sqlite3.connect(DATABASE_PATH)
    c = conn.cursor()
    c.execute(
        """
        SELECT action, entity_id, old_values_json, new_values_json
        FROM audit_logs WHERE entity_id = ? AND action = 'REVIEW'
        """,
        (record_id,),
    )
    audit_row = c.fetchone()
    assert audit_row is not None
    assert audit_row[0] == "REVIEW"
    assert audit_row[1] == record_id
    conn.close()


def test_approve_overtime_and_financial_impact_in_sqlite():
    # 1. Create fresh overtime record
    create_res = client.post(
        f"{API_V1_STR}/overtime",
        json={
            "employeeId": "emp_02",
            "branchId": "br_01",
            "date": "2024-05-10",
            "hours": 3.0,
            "rateMultiplier": 1.5,
            "hourlyRate": 42.0,
            "reason": "تغطية ذروة عطلة نهاية الأسبوع",
        },
    )
    assert create_res.status_code == 201
    record_id = create_res.json()["data"]["id"]
    expected_amount = 189.0  # 3 * 42 * 1.5

    # 2. Approve record via PATCH /api/v1/overtime/{id}/approve
    approve_payload = {
        "isApproved": True,
        "approvedByUserId": "usr_ceo",
        "decisionReason": "معتمد للصرف النهائي من الإدارة التنفيذية",
    }
    approve_res = client.patch(f"{API_V1_STR}/overtime/{record_id}/approve", json=approve_payload)
    assert approve_res.status_code == 200
    body = approve_res.json()
    assert body["success"] is True
    assert body["data"]["status"] == "approved"
    assert body["data"]["approvedByUserId"] == "usr_ceo"

    meta = body.get("meta", {})
    assert "financial_impact" in meta
    impact = meta["financial_impact"]
    assert impact["periodMonth"] == 5
    assert impact["periodYear"] == 2024
    assert impact["addedOvertimeAmount"] == expected_amount
    assert impact["newOvertimeAmount"] >= expected_amount

    # 3. Direct SQLite verification on overtime_records
    conn1 = sqlite3.connect(DATABASE_PATH)
    c1 = conn1.cursor()
    c1.execute(
        "SELECT status, approved_by_user_id, decision_reason FROM overtime_records WHERE id = ?",
        (record_id,),
    )
    ot_row = c1.fetchone()
    assert ot_row is not None
    assert ot_row[0] == "approved"
    assert ot_row[1] == "usr_ceo"
    assert ot_row[2] == "معتمد للصرف النهائي من الإدارة التنفيذية"

    # 4. Direct SQLite verification on employee_pay_history (حساب الأثر المالي)
    c1.execute(
        """
        SELECT period_month, period_year, base_amount, overtime_amount, net_payout, status
        FROM employee_pay_history
        WHERE employee_id = 'emp_02' AND period_month = 5 AND period_year = 2024
        """,
    )
    pay_row = c1.fetchone()
    assert pay_row is not None, "employee_pay_history row must exist for the approved period"
    assert pay_row[0] == 5
    assert pay_row[1] == 2024
    assert pay_row[3] >= expected_amount
    # net_payout = base_amount + overtime_amount - deductions
    assert pay_row[4] == pay_row[2] + pay_row[3]

    # 5. Direct SQLite verification on audit_logs
    c1.execute(
        """
        SELECT action, entity_id, user_id, new_values_json
        FROM audit_logs
        WHERE entity_id = ? AND action = 'APPROVE'
        """,
        (record_id,),
    )
    audit_row = c1.fetchone()
    assert audit_row is not None
    assert audit_row[0] == "APPROVE"
    assert audit_row[1] == record_id
    assert audit_row[2] == "usr_ceo"
    conn1.close()  # Simulate close

    # 6. Reopen & Re-verify persistence
    conn2 = sqlite3.connect(DATABASE_PATH)
    c2 = conn2.cursor()
    c2.execute(
        "SELECT overtime_amount, net_payout FROM employee_pay_history WHERE employee_id = 'emp_02' AND period_month = 5 AND period_year = 2024",
    )
    persisted_pay = c2.fetchone()
    assert persisted_pay is not None
    assert persisted_pay[0] >= expected_amount
    conn2.close()


def test_reject_overtime_record():
    create_res = client.post(
        f"{API_V1_STR}/overtime",
        json={
            "employeeId": "emp_03",
            "branchId": "br_01",
            "date": "2024-05-11",
            "hours": 1.0,
            "rateMultiplier": 1.5,
            "hourlyRate": 35.0,
            "reason": "ساعات إضافية بدون تكليف مسبق",
        },
    )
    assert create_res.status_code == 201
    record_id = create_res.json()["data"]["id"]

    reject_payload = {
        "isApproved": False,
        "approvedByUserId": "usr_bm1",
        "decisionReason": "مرفوض لعدم الحصول على إذن كتابي مسبق من المشرف",
    }
    reject_res = client.patch(f"{API_V1_STR}/overtime/{record_id}/approve", json=reject_payload)
    assert reject_res.status_code == 200
    assert reject_res.json()["data"]["status"] == "rejected"

    # Verify in SQLite
    conn = sqlite3.connect(DATABASE_PATH)
    c = conn.cursor()
    c.execute("SELECT status, decision_reason FROM overtime_records WHERE id = ?", (record_id,))
    row = c.fetchone()
    assert row[0] == "rejected"
    assert row[1] == reject_payload["decisionReason"]

    # Verify audit log
    c.execute("SELECT action FROM audit_logs WHERE entity_id = ? AND action = 'REJECT'", (record_id,))
    assert c.fetchone() is not None
    conn.close()


def test_cumulative_financial_impact():
    """Verify multiple approved overtimes accumulate accurately in SQLite payroll."""
    # Add second overtime in May 2024 for emp_02
    create_res = client.post(
        f"{API_V1_STR}/overtime",
        json={
            "employeeId": "emp_02",
            "branchId": "br_01",
            "date": "2024-05-20",
            "hours": 2.0,
            "rateMultiplier": 1.5,
            "hourlyRate": 42.0,
            "reason": "جرد المنتجات نصف المصنعة",
        },
    )
    assert create_res.status_code == 201
    record_id2 = create_res.json()["data"]["id"]
    second_amount = 126.0  # 2 * 42 * 1.5

    # Fetch initial pay history
    conn = sqlite3.connect(DATABASE_PATH)
    c = conn.cursor()
    c.execute(
        "SELECT overtime_amount FROM employee_pay_history WHERE employee_id = 'emp_02' AND period_month = 5 AND period_year = 2024",
    )
    init_pay = c.fetchone()
    initial_ot = init_pay[0] if init_pay else 0.0
    conn.close()

    # Approve second record
    client.patch(
        f"{API_V1_STR}/overtime/{record_id2}/approve",
        json={"isApproved": True, "approvedByUserId": "usr_ceo", "decisionReason": "معتمد"},
    )

    # Check updated cumulative pay history in SQLite
    conn2 = sqlite3.connect(DATABASE_PATH)
    c2 = conn2.cursor()
    c2.execute(
        "SELECT overtime_amount, net_payout, base_amount FROM employee_pay_history WHERE employee_id = 'emp_02' AND period_month = 5 AND period_year = 2024",
    )
    updated_pay = c2.fetchone()
    assert updated_pay is not None
    expected_cumulative = round(initial_ot + second_amount, 2)
    assert round(updated_pay[0], 2) == expected_cumulative
    assert round(updated_pay[1], 2) == round(updated_pay[2] + expected_cumulative, 2)
    conn2.close()
