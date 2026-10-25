import sqlite3
import pytest
from fastapi.testclient import TestClient
from backend.main import app
from backend.config import DATABASE_PATH, API_V1_STR
from backend.database.seed_data import seed_database
from backend.routers.attendance_router import router as attendance_router
from backend.services.attendance_service import ensure_seed_data
from backend.database.connection import get_db

# Ensure attendance router is registered in app for tests
if not any(
    getattr(r, "path", None) == f"{API_V1_STR}/attendance"
    or getattr(r, "path_format", None) == f"{API_V1_STR}/attendance"
    for r in app.routes
):
    app.include_router(attendance_router, prefix=API_V1_STR)

client = TestClient(app)


def setup_module():
    seed_database()
    with get_db() as conn:
        ensure_seed_data(conn)


def test_get_attendance_records():
    response = client.get(f"{API_V1_STR}/attendance")
    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    data = body["data"]
    assert len(data) >= 4

    # Check structure
    first = data[0]
    assert "id" in first
    assert "employeeName" in first
    assert "employeeCode" in first
    assert "status" in first
    assert "checkInTime" in first


def test_check_in_and_sqlite_persistence():
    payload = {
        "employeeId": "emp_01",
        "branchId": "br_01",
        "date": "2024-04-20",
        "checkInTime": "09:15 ص",
        "shiftName": "الوردية الصباحية",
        "lateMinutes": 15,
    }

    res = client.post(f"{API_V1_STR}/attendance/check-in", json=payload)
    assert res.status_code == 201
    body = res.json()
    assert body["success"] is True
    rec = body["data"]
    att_id = rec["id"]
    assert rec["status"] == "late"
    assert rec["delayMinutes"] == 15

    # Direct SQLite verification
    conn1 = sqlite3.connect(DATABASE_PATH)
    c1 = conn1.cursor()
    c1.execute(
        "SELECT employee_id, date, check_in_time, status, late_minutes FROM attendance_records WHERE id = ?",
        (att_id,),
    )
    row = c1.fetchone()
    assert row is not None
    assert row[0] == "emp_01"
    assert row[1] == "2024-04-20"
    assert row[2] == "09:15 ص"
    assert row[3] == "late"
    assert row[4] == 15
    conn1.close()  # Simulate close

    # Reopen and re-verify persistence
    conn2 = sqlite3.connect(DATABASE_PATH)
    c2 = conn2.cursor()
    c2.execute("SELECT id, status FROM attendance_records WHERE id = ?", (att_id,))
    row2 = c2.fetchone()
    assert row2 is not None
    assert row2[0] == att_id
    assert row2[1] == "late"
    conn2.close()


def test_check_out_and_sqlite_persistence():
    # First create a record to check out
    check_in_res = client.post(
        f"{API_V1_STR}/attendance/check-in",
        json={
            "employeeId": "emp_03",
            "branchId": "br_01",
            "date": "2024-04-21",
            "checkInTime": "08:50 ص",
            "lateMinutes": 0,
        },
    )
    assert check_in_res.status_code == 201
    att_id = check_in_res.json()["data"]["id"]

    # Now checkout
    checkout_res = client.post(
        f"{API_V1_STR}/attendance/check-out",
        json={
            "attendanceId": att_id,
            "checkOutTime": "17:15 م",
        },
    )
    assert checkout_res.status_code == 200
    updated_rec = checkout_res.json()["data"]
    assert updated_rec["checkOutTime"] == "17:15 م"

    # Verify in SQLite directly
    conn = sqlite3.connect(DATABASE_PATH)
    c = conn.cursor()
    c.execute("SELECT check_out_time FROM attendance_records WHERE id = ?", (att_id,))
    row = c.fetchone()
    assert row is not None
    assert row[0] == "17:15 م"
    conn.close()


def test_adjust_deduction_and_sqlite_table_persistence():
    """
    Test deduction adjustment for late employee and verify row is saved
    in SQLite table 'attendance_adjustments' and persists across connection close/reopen.
    """
    att_id = "att_02"  # Mostafa Khaled, 28 minutes late
    reason_text = "عذر مروري معتمد بسبب إغلاق كوبري 6 أكتوبر"
    adjusted_amount = 22.5
    waived_mins = 14

    adjust_payload = {
        "attendanceId": att_id,
        "adjustedByUserId": "usr_bm1",
        "waivedMinutes": waived_mins,
        "deductionAmount": adjusted_amount,
        "reason": reason_text,
        "originalLateMinutes": 28,
    }

    # Execute adjustment via POST /api/v1/attendance/adjust-deduction
    res = client.post(f"{API_V1_STR}/attendance/adjust-deduction", json=adjust_payload)
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    data = body["data"]

    # Check response payload
    assert "adjustment" in data
    assert "record" in data
    adj_info = data["adjustment"]
    rec_info = data["record"]

    assert adj_info["attendanceId"] == att_id
    assert adj_info["deductionAmount"] == adjusted_amount
    assert adj_info["waivedMinutes"] == waived_mins
    assert adj_info["reason"] == reason_text
    assert rec_info["isDeductionAdjusted"] is True
    assert rec_info["deductionAmount"] == adjusted_amount

    # 1. Direct SQLite table verification in attendance_adjustments
    conn1 = sqlite3.connect(DATABASE_PATH)
    c1 = conn1.cursor()
    c1.execute(
        """
        SELECT id, attendance_id, adjusted_by_user_id, original_late_minutes,
               waived_minutes, deduction_amount, reason, created_at
        FROM attendance_adjustments
        WHERE attendance_id = ?
        """,
        (att_id,),
    )
    adj_row = c1.fetchone()
    assert adj_row is not None, "Adjustment row must exist in attendance_adjustments table"
    assert adj_row[1] == att_id
    assert adj_row[2] == "usr_bm1"
    assert adj_row[3] == 28
    assert adj_row[4] == waived_mins
    assert adj_row[5] == adjusted_amount
    assert adj_row[6] == reason_text
    conn1.close()  # CLOSE CONNECTION (Simulate application close / restart)

    # 2. REOPEN & VERIFY PERSISTENCE ACROSS SESSIONS
    conn2 = sqlite3.connect(DATABASE_PATH)
    c2 = conn2.cursor()
    c2.execute(
        """
        SELECT attendance_id, deduction_amount, reason 
        FROM attendance_adjustments 
        WHERE attendance_id = ?
        """,
        (att_id,),
    )
    persisted_row = c2.fetchone()
    assert persisted_row is not None
    assert persisted_row[0] == att_id
    assert persisted_row[1] == adjusted_amount
    assert persisted_row[2] == reason_text
    conn2.close()

    # 3. Verify via GET /api/v1/attendance reflects the adjusted deduction
    list_res = client.get(f"{API_V1_STR}/attendance")
    assert list_res.status_code == 200
    matching = [r for r in list_res.json()["data"] if r["id"] == att_id]
    assert len(matching) == 1
    assert matching[0]["isDeductionAdjusted"] is True
    assert matching[0]["deductionAmount"] == adjusted_amount
    assert matching[0]["adjustmentReason"] == reason_text


def test_adjust_deduction_path_alias():
    att_id = "att_02"
    payload = {
        "attendanceId": att_id,
        "adjustedByUserId": "usr_bm1",
        "waivedMinutes": 28,
        "deductionAmount": 0.0,
        "reason": "إعفاء كامل بقرار الإدارة",
    }
    res = client.post(f"{API_V1_STR}/attendance/{att_id}/adjust", json=payload)
    assert res.status_code == 200
    assert res.json()["data"]["adjustment"]["deductionAmount"] == 0.0
    assert res.json()["data"]["record"]["deductionAmount"] == 0.0


def test_get_employee_attendance_history():
    res = client.get(f"{API_V1_STR}/attendance/history/emp_02")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    history = body["data"]
    assert history["employeeId"] == "emp_02"
    assert "records" in history
    assert history["totalDays"] >= 1
    assert history["employeeName"] != ""


def test_get_attendance_by_id():
    res = client.get(f"{API_V1_STR}/attendance/att_01")
    assert res.status_code == 200
    assert res.json()["data"]["id"] == "att_01"

    # Test 404 for invalid id
    not_found_res = client.get(f"{API_V1_STR}/attendance/nonexistent_id_999")
    assert not_found_res.status_code == 404


def test_sync_biometric_devices():
    res = client.post(f"{API_V1_STR}/attendance/sync-devices")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    assert body["data"]["status"] == "active"
