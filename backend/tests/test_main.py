from fastapi import status


def test_register_user_success(client):
    test_user = {"username": "testuser", "password": "sicheres_passwort"}

    response = client.post("/auth/register", json=test_user)

    assert response.status_code == status.HTTP_201_CREATED

    data = response.json()
    assert data["message"] == "Successfully registered user!"