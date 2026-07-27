from fastapi import APIRouter, Response, status
from pydantic import BaseModel
import os
import jwt

router = APIRouter(prefix="/api/mqtt", tags=["MQTT"])


class MqttAuthRequest(BaseModel):
    username: str | None = None
    password: str | None = None
    clientid: str | None = None


class MqttAclRequest(BaseModel):
    access: int | None = None
    acc: int | None = None
    username: str | None = None
    clientid: str | None = None
    ipaddr: str | None = None
    ip: str | None = None
    topic: str | None = None


@router.post("/auth")
def authenticate_mqtt_client(request: MqttAuthRequest, response: Response):
    token = request.password
    username = request.username
    secret = os.getenv('JWT_SECRET')

    if not token:
        response.status_code = status.HTTP_401_UNAUTHORIZED
        return {"ok": False}

    if username == "admin" and token == os.getenv('MQTT_PASSWORD'):
        return {"ok": True}

    try:
        payload = jwt.decode(token, secret, algorithms=["HS256"])
        sub = payload.get("sub", "")

        if request.clientid and sub.replace(":", "").upper() == request.clientid.upper():
            return {"ok": True}

        if payload:
            return {"ok": True}

    except Exception as e:
        print(f"MQTT Auth failed: {str(e)}")

    response.status_code = status.HTTP_401_UNAUTHORIZED
    return {"ok": False}


@router.post("/acl")
def authorize_mqtt_topic(request: MqttAclRequest, response: Response):
    topic = request.topic or ""
    clientid = request.clientid or ""

    if request.username == "admin" or clientid.upper() in topic.upper() or "kyndora/" in topic:
        return {"ok": True}

    response.status_code = status.HTTP_401_UNAUTHORIZED
    return {"ok": False}