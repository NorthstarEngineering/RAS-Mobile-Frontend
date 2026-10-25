import sqlite3
import pytest
from fastapi.testclient import TestClient
from backend.main import app
from backend.config import DATABASE_PATH, API_V1_STR
from backend.database.seed_data import seed_database

client = TestClient(app)

def setup_module():
    seed_database()

def test_get_employees_list():
    res = client.get(f"{API_V1_STR}/employees")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    employees = body["data"]
    assert len(employees) >= 4

    # Verify first employee structure
    emp = employees[0]
    assert "id" in emp
    assert "code" in emp
    assert "name" in emp
    assert "role" in emp
    assert "wageType" in emp
    assert "baseSalary" in emp
    assert "overtimeRate" in emp
    assert "branchName" in emp
    assert "branchCode" in emp
    assert "status" in emp
    assert "department" in emp

def test_filter_and_search_employees():
    # Filter by wageType monthly
    res_monthly = client.get(f"{API_V1_STR}/employees?wageType=monthly")
    assert res_monthly.status_code == 200
    for emp in res_monthly.json()["data"]:
        assert emp["wageType"] == "monthly"

    # Filter by wageType hourly
    res_hourly = client.get(f"{API_V1_STR}/employees?wageType=hourly")
    assert res_hourly.status_code == 200
    hourly_emps = res_hourly.json()["data"]
    assert len(hourly_emps) >= 1
    assert any(e["wageType"] == "hourly" for e in hourly_emps)

    # Search by code
    res_code = client.get(f"{API_V1_STR}/employees?search=1048")
    assert res_code.status_code == 200
    data = res_code.json()["data"]
    assert len(data) >= 1
    assert data[0]["code"] == "1048"

    # Search by Arabic name
    res_name = client.get(f"{API_V1_STR}/employees?search=كريم")
    assert res_name.status_code == 200
    assert len(res_name.json()["data"]) >= 1

def test_crud_employee_and_sqlite_persistence_across_reopen():
    import time
    ts = int(time.time() * 1000)
    test_id = f"test_emp_{ts}"
    test_code = f"C{ts % 100000}"
    new_employee_payload = {
        "id": test_id,
        "code": test_code,
        "name": "محمود عصام النجار",
        "role": "طاهي مقبلات وسلطات",
        "branchId": "br_01",
        "phone": "01055556666",
        "nationalId": f"NAT-{test_id}",
        "wageType": "monthly",
        "baseSalary": 5600.0,
        "overtimeRate": 42.0,
        "housingAllowance": 500.0,
        "transportAllowance": 300.0,
        "insuranceDeduction": 200.0,
        "status": "active",
        "department": "BOH",
    }

    # 1. CREATE via POST
    create_res = client.post(f"{API_V1_STR}/employees", json=new_employee_payload)
    assert create_res.status_code == 201
    created_data = create_res.json()["data"]
    assert created_data["id"] == test_id
    assert created_data["code"] == test_code
    assert "محمود" in created_data["name"]
    assert created_data["baseSalary"] == 5600.0
    assert created_data["overtimeRate"] == 42.0

    # Verify directly in SQLite DB file
    conn1 = sqlite3.connect(DATABASE_PATH)
    conn1.row_factory = sqlite3.Row
    c1 = conn1.cursor()
    c1.execute("SELECT * FROM employees WHERE id = ?", (test_id,))
    row1 = c1.fetchone()
    assert row1 is not None
    assert row1["code"] == test_code
    assert row1["base_salary"] == 5600.0
    assert row1["overtime_rate"] == 42.0
    conn1.close()  # CLOSED CONNECTION (Simulate server stop / exit)

    # 2. REOPEN & VERIFY PERSISTENCE (Simulate fresh restart / reopen)
    conn2 = sqlite3.connect(DATABASE_PATH)
    conn2.row_factory = sqlite3.Row
    c2 = conn2.cursor()
    c2.execute("SELECT * FROM employees WHERE id = ?", (test_id,))
    row2 = c2.fetchone()
    assert row2 is not None
    assert row2["code"] == test_code
    assert row2["base_salary"] == 5600.0
    conn2.close()

    # 3. GET BY ID & GET BY CODE
    get_res_id = client.get(f"{API_V1_STR}/employees/{test_id}")
    assert get_res_id.status_code == 200
    assert get_res_id.json()["data"]["id"] == test_id

    get_res_code = client.get(f"{API_V1_STR}/employees/{test_code}")
    assert get_res_code.status_code == 200
    assert get_res_code.json()["data"]["id"] == test_id

    # 4. UPDATE via PUT
    update_payload = {
        "baseSalary": 6200.0,
        "role": "رئيس طهاة الخط الساخن (Sous Chef)",
        "status": "activeOnShift",
    }
    put_res = client.put(f"{API_V1_STR}/employees/{test_id}", json=update_payload)
    assert put_res.status_code == 200
    updated_data = put_res.json()["data"]
    assert updated_data["baseSalary"] == 6200.0
    assert updated_data["role"] == "رئيس طهاة الخط الساخن (Sous Chef)"
    assert updated_data["status"] == "activeOnShift"

    # Verify update directly in SQLite
    conn3 = sqlite3.connect(DATABASE_PATH)
    conn3.row_factory = sqlite3.Row
    c3 = conn3.cursor()
    c3.execute("SELECT base_salary, job_title, status FROM employees WHERE id = ?", (test_id,))
    row3 = c3.fetchone()
    assert row3["base_salary"] == 6200.0
    assert row3["job_title"] == "رئيس طهاة الخط الساخن (Sous Chef)"
    assert row3["status"] == "activeOnShift"
    conn3.close()

def test_employee_compensation_calculation():
    # Test seeded employee 1 (Karim)
    res = client.get(f"{API_V1_STR}/employees/1/compensation")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    comp = body["data"]
    assert comp["employeeId"] == "1"
    assert comp["baseSalary"] == 4500.0
    assert comp["housingAllowance"] == 400.0
    assert comp["transportAllowance"] == 200.0
    assert comp["insuranceDeduction"] == 150.0

    # Verify arithmetic calculations
    # totalAllowances = 400 + 200 = 600
    assert comp["totalAllowances"] == 600.0
    # totalDeductions = 150
    assert comp["totalDeductions"] == 150.0
    # grossPay = 4500 + 600 = 5100
    assert comp["grossPay"] == 5100.0
    # netEstimatedPay = 5100 - 150 = 4950
    assert comp["netEstimatedPay"] == 4950.0
    assert comp["status"] == "نشط بالخدمة"

def test_employee_pay_history():
    # Test seeded employee 1 (Karim) pay history
    res = client.get(f"{API_V1_STR}/employees/1/pay-history")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    records = body["data"]
    assert len(records) >= 4

    # Verify first record (March 2024)
    r0 = records[0]
    assert r0["employeeId"] == "1"
    assert r0["periodMonth"] == 3
    assert r0["periodYear"] == 2024
    assert r0["monthLabel"] == "مارس 2024"
    assert "مارس 2024" in r0["dateLabel"]
    assert r0["baseAmount"] == 4500.0
    assert r0["netPayout"] == 4650.0
    assert "مسدد" in r0["status"]
    assert r0["referenceNo"] == "PAY-2024-03-1048"

def test_employee_not_found_errors():
    res_emp = client.get(f"{API_V1_STR}/employees/non_existent_9999")
    assert res_emp.status_code == 404

    res_comp = client.get(f"{API_V1_STR}/employees/non_existent_9999/compensation")
    assert res_comp.status_code == 404

    res_pay = client.get(f"{API_V1_STR}/employees/non_existent_9999/pay-history")
    assert res_pay.status_code == 404


def test_delete_employee_success_and_audit():
    import time
    from backend.utils.security import create_access_token
    token = create_access_token({"sub": "usr_ceo", "id": "usr_ceo", "role": "ceo", "branch_id": None})
    headers = {"Authorization": f"Bearer {token}"}

    ts = int(time.time() * 1000)
    test_id = f"test_del_emp_{ts}"
    test_code = f"CD{ts % 100000}"
    create_payload = {
        "id": test_id,
        "code": test_code,
        "name": "موظف اختبار حذف",
        "role": "كاشير مؤقت",
        "nationalId": f"NAT-DEL-{ts}",
        "branchId": "br_01",
        "phone": "01099998888",
        "wageType": "monthly",
        "baseSalary": 4000.0,
        "overtimeRate": 30.0,
        "department": "FOH",
        "status": "active",
    }
    c_res = client.post(f"{API_V1_STR}/employees", json=create_payload, headers=headers)
    assert c_res.status_code == 201

    # Verify present in list
    list_res = client.get(f"{API_V1_STR}/employees", headers=headers)
    assert any(e["id"] == test_id for e in list_res.json()["data"])

    # Delete
    del_res = client.delete(f"{API_V1_STR}/employees/{test_id}", headers=headers)
    assert del_res.status_code == 200
    assert del_res.json()["success"] is True

    # Verify not in active list
    list_res2 = client.get(f"{API_V1_STR}/employees", headers=headers)
    assert not any(e["id"] == test_id for e in list_res2.json()["data"])

