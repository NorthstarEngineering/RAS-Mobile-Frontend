import pytest
from fastapi.testclient import TestClient
from backend.main import app
from backend.config import API_V1_STR

client = TestClient(app)


def test_get_kitchen_dashboard():
    res = client.get(f"{API_V1_STR}/kitchen/dashboard")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    data = body["data"]
    assert "totalStockValue" in data or "total_stock_value" in data
    assert "totalItemsCount" in data or "total_items_count" in data
    assert "criticalItems" in data or "critical_items" in data
    assert "recentMovements" in data or "recent_movements" in data


def test_get_kitchen_items():
    res = client.get(f"{API_V1_STR}/kitchen/items")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    assert isinstance(body["data"], list)
    assert len(body["data"]) > 0
    first_item = body["data"][0]
    assert "sku" in first_item
    assert "name" in first_item
    assert "quantity" in first_item


def test_get_kitchen_item_by_id():
    res_list = client.get(f"{API_V1_STR}/kitchen/items")
    assert res_list.status_code == 200
    items = res_list.json()["data"]
    target_id = items[0]["id"]

    res_item = client.get(f"{API_V1_STR}/kitchen/items/{target_id}")
    assert res_item.status_code == 200
    body = res_item.json()
    assert body["success"] is True
    assert body["data"]["id"] == target_id


def test_create_and_fetch_kitchen_item():
    import uuid
    rand_sku = f"SPICE-TEST-{uuid.uuid4().hex[:6]}"
    payload = {
        "name": "توابل برجر سرية ممتازة",
        "sku": rand_sku,
        "category": "صوصات مركزية",
        "quantity": 25.0,
        "unit": "كجم",
        "unitCost": 85.0,
        "safetyStock": 10.0,
        "capacity": 100.0,
        "location": "مستودع التوابل الجاف",
    }
    res_create = client.post(f"{API_V1_STR}/kitchen/items", json=payload)
    assert res_create.status_code == 201
    body = res_create.json()
    assert body["success"] is True
    created = body["data"]
    assert created["sku"] == rand_sku

    # Fetch by ID
    created_id = created["id"]
    res_get = client.get(f"{API_V1_STR}/kitchen/items/{created_id}")
    assert res_get.status_code == 200
    assert res_get.json()["data"]["name"] == "توابل برجر سرية ممتازة"


def test_get_kitchen_movements():
    res = client.get(f"{API_V1_STR}/kitchen/movements")
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    assert isinstance(body["data"], list)
    assert len(body["data"]) > 0
