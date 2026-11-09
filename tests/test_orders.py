def _stock(client, sku_id, store_id=1):
    rows = client.get(f"/api/inventory?store_id={store_id}").get_json()["data"]
    return next(row["quantity"] for row in rows if row["sku_id"] == sku_id)


def _set_stock(client, sku_id, quantity, store_id=1):
    response = client.put(
        "/api/inventory",
        json={"sku_id": sku_id, "store_id": store_id, "quantity": quantity},
    )
    assert response.status_code == 200


def _create_order(client, items, store_id=1):
    response = client.post("/api/orders", json={"store_id": store_id, "items": items})
    return response


def test_customer_creates_order_and_cancel_restores_stock(customer, staff):
    before = _stock(staff, 1)
    response = _create_order(customer, [{"sku_id": 1, "quantity": 1}])
    body = response.get_json()
    assert response.status_code == 200, body
    order = body["data"]
    assert order["status"] == "待支付"
    assert order["total_amount"] == 15.0
    assert len(order["items"]) == 1
    assert _stock(staff, 1) == before - 1

    cancelled = customer.post(f"/api/orders/{order['order_id']}/cancel")
    assert cancelled.status_code == 200
    assert cancelled.get_json()["data"]["status"] == "已取消"
    assert _stock(staff, 1) == before


def test_order_items_add_update_delete(customer, staff):
    stock_1 = _stock(staff, 1)
    stock_2 = _stock(staff, 2)

    order = _create_order(customer, [{"sku_id": 1, "quantity": 1}]).get_json()["data"]
    order_id = order["order_id"]

    added = customer.post(f"/api/orders/{order_id}/items", json={"sku_id": 2, "quantity": 1})
    body = added.get_json()
    assert added.status_code == 200, body
    assert body["data"]["total_amount"] == 33.0
    assert len(body["data"]["items"]) == 2
    item_1 = next(item for item in body["data"]["items"] if item["sku_id"] == 1)
    item_2 = next(item for item in body["data"]["items"] if item["sku_id"] == 2)

    updated = customer.put(
        f"/api/orders/{order_id}/items/{item_1['order_item_id']}",
        json={"quantity": 2},
    )
    body = updated.get_json()
    assert updated.status_code == 200, body
    assert body["data"]["total_amount"] == 48.0

    removed = customer.delete(f"/api/orders/{order_id}/items/{item_2['order_item_id']}")
    body = removed.get_json()
    assert removed.status_code == 200, body
    assert body["data"]["total_amount"] == 30.0

    customer.post(f"/api/orders/{order_id}/cancel")
    assert _stock(staff, 1) == stock_1
    assert _stock(staff, 2) == stock_2


def test_pay_and_staff_advance_status(customer, staff):
    before = _stock(staff, 1)
    order = _create_order(customer, [{"sku_id": 1, "quantity": 1}]).get_json()["data"]
    order_id = order["order_id"]

    paid = customer.post(f"/api/orders/{order_id}/pay")
    assert paid.status_code == 200
    assert paid.get_json()["data"]["status"] == "已支付"
    assert paid.get_json()["data"]["paid_at"]

    for expected in ("制作中", "待取餐", "已完成"):
        advanced = staff.post(f"/api/orders/{order_id}/status", json={"status": expected})
        assert advanced.status_code == 200, advanced.get_json()
        assert advanced.get_json()["data"]["status"] == expected
    assert advanced.get_json()["data"]["completed_at"]

    invalid = staff.post(f"/api/orders/{order_id}/status", json={"status": "已完成"})
    assert invalid.status_code == 409
    assert invalid.get_json()["code"] == 4090

    _set_stock(staff, 1, before)


def test_insufficient_stock_rolls_back(customer, staff):
    before = _stock(staff, 4)
    response = _create_order(customer, [{"sku_id": 4, "quantity": 99}])
    assert response.status_code == 409
    assert response.get_json()["code"] == 4090
    assert _stock(staff, 4) == before


def test_customer_cannot_view_others_order(customer):
    response = customer.get("/api/orders/3")
    assert response.status_code == 403
    assert response.get_json()["code"] == 4030


def test_customer_cannot_advance_status(customer):
    response = customer.post("/api/orders/1/status", json={"status": "制作中"})
    assert response.status_code == 403


def test_order_not_found(customer):
    response = customer.get("/api/orders/99999")
    assert response.status_code == 404
    assert response.get_json()["code"] == 4040


def test_invalid_order_quantity(customer):
    response = _create_order(customer, [{"sku_id": 1, "quantity": 0}])
    assert response.status_code == 400
    assert response.get_json()["code"] == 4001


def test_empty_order(customer):
    response = customer.post("/api/orders", json={"store_id": 1, "items": []})
    assert response.status_code == 400
    assert response.get_json()["code"] == 4001


def test_pay_twice(customer, staff):
    before = _stock(staff, 1)
    order = _create_order(customer, [{"sku_id": 1, "quantity": 1}]).get_json()["data"]
    order_id = order["order_id"]
    customer.post(f"/api/orders/{order_id}/pay")
    second = customer.post(f"/api/orders/{order_id}/pay")
    assert second.status_code == 409
    assert second.get_json()["code"] == 4090
    _set_stock(staff, 1, before)


def test_customer_order_list_only_own(customer):
    response = customer.get("/api/orders")
    assert response.status_code == 200
    assert all(order["user_id"] == 1 for order in response.get_json()["data"])


def test_staff_order_list(staff):
    response = staff.get("/api/orders")
    assert response.status_code == 200
    assert response.get_json()["data"]
