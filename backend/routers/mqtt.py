import os
from fastapi import APIRouter, Response, status, Depends
from pydantic import BaseModel
import jwt

router = APIRouter(prefix="/api/mqtt", tags=["MQTT"])


class MqttAuthRequest(BaseModel):
    username: str
    password: str
    clientid: str


class MqttAclRequest(BaseModel):
    access: int
    username: str
    clientid: str
    ipaddr: str
    topic: str


@router.post("/auth")
def authenticate_mqtt_client(request: MqttAuthRequest, response: Response):
    token = request.password
    secret = os.getenv('JWT_SECRET')

    try:
        payload = jwt.decode(token, secret, algorithms=["HS256"])

        sub = payload.get("sub", "")
        print(f"MQTT Auth Success Check -> Token Sub: {sub} | ClientID: {request.clientid}")

        if sub.replace(":", "").upper() == request.clientid.upper():
            return {"ok": True}
        else:
            print("MQTT Auth Failed: Sub and ClientID do not match!")

    except Exception as e:
        print(f"DETAILED MQTT Auth failed exception: {str(e)}")

    response.status_code = status.HTTP_401_UNAUTHORIZED
    return {"ok": False}

@router.post("/acl")
def authorize_mqtt_topic(request: MqttAclRequest, response: Response):
    if request.clientid in request.topic:
        return {"ok": True}

    response.status_code = status.HTTP_401_UNAUTHORIZED
    return {"ok": False}