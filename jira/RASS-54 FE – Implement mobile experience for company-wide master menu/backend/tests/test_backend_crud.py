import os
import sqlite3
import pytest
from fastapi.testclient import TestClient
from backend.main import app
from backend.config import DATABASE_PATH
from backend.database.seed_data import seed_database

client = TestClient(app)

def setup_module():
    seed_database()

def test_health_check():
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["database"] == "sqlite_wal"

def test_database_wal_and_tables():
    from backend.database.connection import get_raw_connection
    conn = get_raw_connection()
    c = conn.cursor()
    c.execute("PRAGMA journal_mode")
    assert c.fetchone()[0].lower() == "wal"
    c.execute("PRAGMA foreign_keys")
    assert c.fetchone()[0] == 1
    c.execute("SELECT COUNT(*) FROM menu_categories")
    assert c.fetchone()[0] >= 5
    c.execute("SELECT COUNT(*) FROM menu_items")
    assert c.fetchone()[0] >= 5
    conn.close()

def test_get_categories():
    response = client.get("/api/v1/menu/categories")
    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert len(body["data"]) >= 5

def test_crud_menu_item_and_persistence_across_reopen():
    test_sku = "VERIFY-AUTO-999"
    new_item = {
        "sku": test_sku,
        "barcode": "6229998881112",
        "nameAr": "ساندوتش فاهيتا التحقق الحي",
        "nameEn": "Live Verification Fajita",
        "categoryId": "cat_burgers",
        "categoryName": "برجر وسندوتشات",
        "price": 165.0,
        "cost": 80.0,
        "marginPercent": 51.52,
        "kitchenStation": "محطة اللحوم الساخنة",
        "isActive": True,
        "description": "صنف تجريبي لاختبار التخزين الحي واستمرارية البيانات عبر الإغلاق وإعادة الفتح",
        "branches": ["كافة الفروع"],
        "allergens": ["جلوتين"],
    }

    # 1. CREATE
    create_res = client.post("/api/v1/menu/items", json=new_item)
    assert create_res.status_code == 201
    created_data = create_res.json()["data"]
    item_id = created_data["id"]
    assert created_data["sku"] == test_sku
    assert created_data["nameAr"] == new_item["nameAr"]

    # Verify directly in SQLite DB file
    conn1 = sqlite3.connect(DATABASE_PATH)
    c1 = conn1.cursor()
    c1.execute("SELECT name_ar, price, cost FROM menu_items WHERE id = ?", (item_id,))
    row1 = c1.fetchone()
    assert row1 is not None
    assert row1[0] == new_item["nameAr"]
    assert row1[1] == 165.0
    conn1.close()  # CLOSED CONNECTION (Simulate application close / exit)

    # 2. REOPEN & VERIFY PERSISTENCE (Simulate fresh restart / reopen)
    conn2 = sqlite3.connect(DATABASE_PATH)
    c2 = conn2.cursor()
    c2.execute("SELECT name_ar, price, cost FROM menu_items WHERE id = ?", (item_id,))
    row2 = c2.fetchone()
    assert row2 is not None
    assert row2[0] == new_item["nameAr"]
    assert row2[1] == 165.0
    conn2.close()

    # Verify via API endpoint
    fetch_res = client.get(f"/api/v1/menu/items/{item_id}")
    assert fetch_res.status_code == 200
    assert fetch_res.json()["data"]["sku"] == test_sku

    # 3. UPDATE
    update_payload = {
        "price": 185.0,
        "nameAr": "ساندوتش فاهيتا التحقق الحي المحدث",
    }
    update_res = client.put(f"/api/v1/menu/items/{item_id}", json=update_payload)
    assert update_res.status_code == 200
    assert update_res.json()["data"]["price"] == 185.0
    assert update_res.json()["data"]["nameAr"] == "ساندوتش فاهيتا التحقق الحي المحدث"

    # Verify directly in SQLite
    conn3 = sqlite3.connect(DATABASE_PATH)
    c3 = conn3.cursor()
    c3.execute("SELECT name_ar, price FROM menu_items WHERE id = ?", (item_id,))
    row3 = c3.fetchone()
    assert row3[0] == "ساندوتش فاهيتا التحقق الحي المحدث"
    assert row3[1] == 185.0
    conn3.close()

    # 4. DELETE
    del_res = client.delete(f"/api/v1/menu/items/{item_id}")
    assert del_res.status_code == 200

    # Verify removed from SQLite
    conn4 = sqlite3.connect(DATABASE_PATH)
    c4 = conn4.cursor()
    c4.execute("SELECT COUNT(*) FROM menu_items WHERE id = ?", (item_id,))
    assert c4.fetchone()[0] == 0

    # Check Audit Log in SQLite
    c4.execute("SELECT action FROM audit_logs WHERE entity_id = ? ORDER BY timestamp ASC", (item_id,))
    audit_actions = [r[0] for r in c4.fetchall()]
    assert "CREATE_MENU_ITEM" in audit_actions
    assert "UPDATE_MENU_ITEM" in audit_actions
    assert "DELETE_MENU_ITEM" in audit_actions
    conn4.close()
