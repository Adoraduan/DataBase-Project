from uuid import uuid4


def test_list_products(customer):
    response = customer.get("/api/products")
    body = response.get_json()
    assert response.status_code == 200
    assert body["code"] == 0
    assert len(body["data"]) >= 3
    assert all("skus" in product for product in body["data"])


def test_get_product_detail(customer):
    response = customer.get("/api/products/1")
    body = response.get_json()
    assert response.status_code == 200
    assert body["data"]["product_id"] == 1
    assert body["data"]["skus"]


def test_manager_create_and_delete_product(manager):
    name = f"测试商品-{uuid4().hex[:8]}"
    created = manager.post(
        "/api/products",
        json={"product_name": name, "category_id": 1, "description": "测试用", "status": "上架"},
    )
    body = created.get_json()
    assert created.status_code == 200, body
    product_id = body["data"]["product_id"]

    fetched = manager.get(f"/api/products/{product_id}")
    assert fetched.get_json()["data"]["product_name"] == name

    deleted = manager.delete(f"/api/products/{product_id}")
    assert deleted.status_code == 200
    assert manager.get(f"/api/products/{product_id}").status_code == 404


def test_delete_product_with_skus_conflicts(manager):
    response = manager.delete("/api/products/1")
    body = response.get_json()
    assert response.status_code == 409
    assert body["code"] == 4099
    assert "SQL" not in body["message"]


def test_create_and_update_sku(manager):
    name = f"规格商品-{uuid4().hex[:8]}"
    product = manager.post(
        "/api/products",
        json={"product_name": name, "category_id": 1, "status": "上架"},
    ).get_json()["data"]
    product_id = product["product_id"]

    created = manager.post(
        f"/api/products/{product_id}/skus",
        json={"sku_name": "中杯", "price": "16.50", "status": "上架"},
    )
    body = created.get_json()
    assert created.status_code == 200, body
    sku = body["data"]["skus"][0]
    assert sku["sku_name"] == "中杯"
    assert sku["price"] == 16.5

    updated = manager.put(
        f"/api/skus/{sku['sku_id']}",
        json={"sku_name": "大杯", "price": "18.00", "status": "上架"},
    )
    assert updated.status_code == 200
    assert updated.get_json()["data"]["skus"][0]["sku_name"] == "大杯"


def test_invalid_sku_price(manager):
    response = manager.post(
        "/api/products/1/skus",
        json={"sku_name": "错误规格", "price": "-1", "status": "上架"},
    )
    assert response.status_code == 400
    assert response.get_json()["code"] == 4001
