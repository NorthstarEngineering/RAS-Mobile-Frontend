import json
import sqlite3
import uuid
import pytest
from fastapi.testclient import TestClient
from backend.main import app
from backend.config import DATABASE_PATH, API_V1_STR
from backend.database.seed_data import seed_database
from backend.routers.branches_router import router as branches_router

# Ensure branches router is registered on app for testing
if not any(r.path.startswith(f"{API_V1_STR}/branches") for r in app.routes):
    app.include_router(branches_router, prefix=API_V1_STR)

client = TestClient(app)


def setup_module():
    seed_database()


def test_get_branches_list_and_filtering():
    # 1. Fetch all branches
    response = client.get("/api/v1/branches")
    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert "data" in body
    branches = body["data"]
    assert len(branches) >= 4

    # 2. Filter by type=dining
    res_dining = client.get("/api/v1/branches?type=dining")
    assert res_dining.status_code == 200
    dining_branches = res_dining.json()["data"]
    assert len(dining_branches) >= 3
    assert all(b["type"] == "dining" for b in dining_branches)

    # 3. Filter by type=kitchen
    res_kitchen = client.get("/api/v1/branches?type=kitchen")
    assert res_kitchen.status_code == 200
    kitchen_branches = res_kitchen.json()["data"]
    assert len(kitchen_branches) >= 1
    assert all(b["type"] == "kitchen" for b in kitchen_branches)

    # 4. Filter by search
    res_search = client.get("/api/v1/branches?search=المعادي")
    assert res_search.status_code == 200
    search_results = res_search.json()["data"]
    assert len(search_results) >= 1
    assert any("المعادي" in b["name"] for b in search_results)


def test_get_branch_by_id_and_code():
    # Fetch by ID (br_01)
    res_id = client.get("/api/v1/branches/br_01")
    assert res_id.status_code == 200
    data = res_id.json()["data"]
    assert data["id"] == "br_01"
    assert data["code"] == "BR-01"

    # Fetch by Code (BR-02)
    res_code = client.get("/api/v1/branches/BR-02")
    assert res_code.status_code == 200
    assert res_code.json()["data"]["id"] == "br_02"

    # Fetch non-existent
    res_none = client.get("/api/v1/branches/br_non_existent_9999")
    assert res_none.status_code == 404


def test_crud_branch_and_sqlite_persistence_across_reopen():
    unique_suffix = uuid.uuid4().hex[:6].upper()
    test_code = f"BR-V-{unique_suffix}"
    new_branch_payload = {
        "code": test_code,
        "nameAr": f"فرع الشروق التجريبي {unique_suffix}",
        "nameEn": f"Shorouk Live Audit Branch {unique_suffix}",
        "address": "المنطقة الأولى، مدينة الشروق، القاهرة",
        "phone": "0228765432",
        "managerName": "م. حازم الصاوي",
        "type": "dining",
        "isActive": True,
        "isMain": False,
        "employeeCount": 16,
        "posTerminalsCount": 4,
    }

    # 1. CREATE via POST
    create_res = client.post("/api/v1/branches", json=new_branch_payload)
    assert create_res.status_code == 201
    created_data = create_res.json()["data"]
    branch_id = created_data["id"]
    assert created_data["code"] == test_code
    assert created_data["name"] == new_branch_payload["nameAr"]
    assert created_data["managerName"] == new_branch_payload["managerName"]

    # 2. VERIFY DIRECTLY IN SQLITE DB FILE
    conn1 = sqlite3.connect(DATABASE_PATH)
    c1 = conn1.cursor()
    c1.execute(
        "SELECT code, name_ar, phone, manager_name, is_active FROM branches WHERE id = ?",
        (branch_id,),
    )
    row1 = c1.fetchone()
    assert row1 is not None
    assert row1[0] == test_code
    assert row1[1] == new_branch_payload["nameAr"]
    assert row1[2] == new_branch_payload["phone"]
    assert row1[3] == new_branch_payload["managerName"]
    assert row1[4] == 1
    conn1.close()  # Simulate connection close / process finish

    # 3. REOPEN & VERIFY PERSISTENCE (Simulate fresh restart / reopen)
    conn2 = sqlite3.connect(DATABASE_PATH)
    c2 = conn2.cursor()
    c2.execute(
        "SELECT code, name_ar, phone, manager_name FROM branches WHERE id = ?",
        (branch_id,),
    )
    row2 = c2.fetchone()
    assert row2 is not None
    assert row2[0] == test_code
    assert row2[1] == new_branch_payload["nameAr"]
    conn2.close()

    # Verify via API endpoint
    fetch_res = client.get(f"/api/v1/branches/{branch_id}")
    assert fetch_res.status_code == 200
    assert fetch_res.json()["data"]["code"] == test_code

    # 4. AUDIT LOG VERIFICATION FOR CREATE
    conn_audit = sqlite3.connect(DATABASE_PATH)
    ca = conn_audit.cursor()
    ca.execute(
        "SELECT action, entity_type, entity_id, new_values_json FROM audit_logs WHERE entity_id = ? AND action = 'CREATE_BRANCH'",
        (branch_id,),
    )
    audit_row = ca.fetchone()
    assert audit_row is not None
    assert audit_row[0] == "CREATE_BRANCH"
    assert audit_row[1] == "branches"
    assert audit_row[2] == branch_id
    new_vals = json.loads(audit_row[3])
    assert new_vals["code"] == test_code
    assert new_vals["name_ar"] == new_branch_payload["nameAr"]
    conn_audit.close()

    # 5. UPDATE via PUT
    update_payload = {
        "nameAr": f"فرع الشروق التجريبي المحدث {unique_suffix}",
        "phone": "0229999888",
        "managerName": "د. حازم الصاوي (مدير إقليمي)",
    }
    update_res = client.put(f"/api/v1/branches/{branch_id}", json=update_payload)
    assert update_res.status_code == 200
    updated_data = update_res.json()["data"]
    assert updated_data["name"] == update_payload["nameAr"]
    assert updated_data["phone"] == update_payload["phone"]
    assert updated_data["managerName"] == update_payload["managerName"]

    # 6. VERIFY UPDATE IN SQLITE DIRECTLY
    conn3 = sqlite3.connect(DATABASE_PATH)
    c3 = conn3.cursor()
    c3.execute(
        "SELECT name_ar, phone, manager_name FROM branches WHERE id = ?",
        (branch_id,),
    )
    row3 = c3.fetchone()
    assert row3[0] == update_payload["nameAr"]
    assert row3[1] == update_payload["phone"]
    assert row3[2] == update_payload["managerName"]

    # 7. AUDIT LOG VERIFICATION FOR UPDATE
    c3.execute(
        "SELECT action, entity_type, entity_id, old_values_json, new_values_json FROM audit_logs WHERE entity_id = ? AND action = 'UPDATE_BRANCH'",
        (branch_id,),
    )
    up_audit = c3.fetchone()
    assert up_audit is not None
    assert up_audit[0] == "UPDATE_BRANCH"
    old_vals = json.loads(up_audit[3])
    new_vals_up = json.loads(up_audit[4])
    assert old_vals["name_ar"] == new_branch_payload["nameAr"]
    assert new_vals_up["name_ar"] == update_payload["nameAr"]

    # 8. DELETE via DELETE
    del_res = client.delete(f"/api/v1/branches/{branch_id}")
    assert del_res.status_code == 200

    # 9. AUDIT LOG VERIFICATION FOR DELETE
    c3.execute(
        "SELECT action, entity_type, entity_id FROM audit_logs WHERE entity_id = ? AND action = 'DELETE_BRANCH'",
        (branch_id,),
    )
    del_audit = c3.fetchone()
    assert del_audit is not None
    assert del_audit[0] == "DELETE_BRANCH"

    # Verify branch removed from branches table
    c3.execute("SELECT COUNT(*) FROM branches WHERE id = ?", (branch_id,))
    assert c3.fetchone()[0] == 0
    conn3.close()


def test_duplicate_branch_code_rejected():
    duplicate_payload = {
        "code": "BR-01",  # Pre-existing code
        "nameAr": "محاولة فرع مكرر",
        "address": "القاهرة",
        "phone": "0100000000",
        "type": "dining",
    }
    response = client.post("/api/v1/branches", json=duplicate_payload)
    assert response.status_code == 400
    assert "مستخدم بالفعل" in response.json()["detail"]


def test_central_kitchen_summary_endpoints():
    # 1. Primary path /central-kitchen/summary
    res = client.get("/api/v1/branches/central-kitchen/summary")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    data = body["data"]

    assert data["capacityDescription"] == "142 طن مبرد"
    assert data["crewDescription"] == "24 شيف وفني"
    assert data["fleetDescription"] == "6 شاحنات مبردة"
    assert data["readinessRate"] == 99.8
    assert len(data["criticalAlerts"]) >= 2
    assert len(data["activeDeliveries"]) >= 2

    # 2. Alias path /kitchen
    res_alias = client.get("/api/v1/branches/kitchen")
    assert res_alias.status_code == 200
    assert res_alias.json()["data"]["capacityDescription"] == "142 طن مبرد"
