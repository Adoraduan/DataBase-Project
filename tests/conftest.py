import pytest

from app import create_app

PASSWORD = "Campus@2026"


def login(client, username):
    response = client.post("/api/auth/login", json={"username": username, "password": PASSWORD})
    assert response.status_code == 200, response.get_json()
    return response.get_json()["data"]


@pytest.fixture()
def client():
    return create_app().test_client()


@pytest.fixture()
def customer(client):
    login(client, "alice")
    return client


@pytest.fixture()
def staff():
    client = create_app().test_client()
    login(client, "bob")
    return client


@pytest.fixture()
def manager():
    client = create_app().test_client()
    login(client, "carol")
    return client
