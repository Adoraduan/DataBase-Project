def test_login_success(client):
    response = client.post("/api/auth/login", json={"username": "alice", "password": "Campus@2026"})
    body = response.get_json()
    assert response.status_code == 200
    assert body["code"] == 0
    assert body["data"]["role"] == "customer"


def test_login_wrong_password(client):
    response = client.post("/api/auth/login", json={"username": "alice", "password": "wrong"})
    body = response.get_json()
    assert response.status_code == 401
    assert body["code"] == 4010
    assert body["request_id"]


def test_login_missing_fields(client):
    response = client.post("/api/auth/login", json={})
    assert response.status_code == 400
    assert response.get_json()["code"] == 4001


def test_login_sql_injection_string(client):
    response = client.post(
        "/api/auth/login",
        json={"username": "' OR 1=1 --", "password": "x"},
    )
    assert response.status_code == 401


def test_requires_login(client):
    response = client.get("/api/products")
    assert response.status_code == 401
    assert response.get_json()["code"] == 4010


def test_customer_cannot_read_inventory(client, customer):
    response = customer.get("/api/inventory")
    assert response.status_code == 403
    assert response.get_json()["code"] == 4030


def test_staff_cannot_create_product(staff):
    response = staff.post(
        "/api/products",
        json={"product_name": "测试商品", "category_id": 1, "status": "上架"},
    )
    assert response.status_code == 403
