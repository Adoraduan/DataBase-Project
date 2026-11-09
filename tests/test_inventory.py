def _inventory(client, store_id=1):
    response = client.get(f"/api/inventory?store_id={store_id}")
    assert response.status_code == 200
    return response.get_json()["data"]


def test_list_inventory(staff):
    rows = _inventory(staff)
    assert rows
    assert {"sku_id", "store_id", "product_name", "sku_name", "quantity"} <= set(rows[0])


def test_adjust_inventory_and_restore(staff):
    rows = _inventory(staff)
    target = next(row for row in rows if row["sku_id"] == 1)
    original = target["quantity"]

    try:
        response = staff.put(
            "/api/inventory",
            json={"sku_id": 1, "store_id": 1, "quantity": original + 1},
        )
        assert response.status_code == 200
        assert next(row for row in _inventory(staff) if row["sku_id"] == 1)["quantity"] == original + 1
    finally:
        staff.put("/api/inventory", json={"sku_id": 1, "store_id": 1, "quantity": original})

    assert next(row for row in _inventory(staff) if row["sku_id"] == 1)["quantity"] == original


def test_invalid_inventory_quantity(staff):
    response = staff.put(
        "/api/inventory",
        json={"sku_id": 1, "store_id": 1, "quantity": -1},
    )
    assert response.status_code == 400
    assert response.get_json()["code"] == 4001


def test_inventory_missing_sku(staff):
    response = staff.put(
        "/api/inventory",
        json={"sku_id": 99999, "store_id": 1, "quantity": 5},
    )
    assert response.status_code == 404
    assert response.get_json()["code"] == 4040
