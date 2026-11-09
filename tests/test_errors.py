import pyodbc

import app.db as db_module


def test_db_connection_failure_is_uniform(client, monkeypatch):
    def boom(*args, **kwargs):
        raise pyodbc.OperationalError("08001", "connection failed")

    monkeypatch.setattr(db_module, "connect", boom)

    response = client.post(
        "/api/auth/login",
        json={"username": "alice", "password": "Campus@2026"},
    )
    body = response.get_json()
    assert response.status_code == 503
    assert body["code"] == 5001
    assert "ODBC" not in body["message"]
    assert "SQL" not in body["message"]
    assert body["request_id"]


def test_404_page(client):
    response = client.get("/nope")
    assert response.status_code == 404
    assert response.content_type.startswith("text/html")


def test_401_page_redirects_to_login(client):
    response = client.get("/orders")
    assert response.status_code == 302
    assert "/login" in response.headers["Location"]


def test_error_shape(client):
    response = client.get("/api/orders")
    body = response.get_json()
    assert response.status_code == 401
    assert set(body) == {"code", "message", "request_id"}
    assert body["code"] == 4010


def test_keyword_injection_is_parameterized(customer):
    response = customer.get("/api/products", query_string={"keyword": "' OR 1=1 --"})
    assert response.status_code == 200
    assert response.get_json()["code"] == 0
