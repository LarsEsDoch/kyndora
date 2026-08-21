import json

from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from database import get_session
from models import PushToken, User
from schemas import FcmTokenRegister, WebPushSubscriptionRegister
from security import get_current_user
from services.push_service import VAPID_PUBLIC_KEY

router = APIRouter(prefix="/api/push", tags=["push"])


@router.get("/vapid-public-key")
def get_vapid_public_key():
    return {"public_key": VAPID_PUBLIC_KEY}


@router.post("/register/fcm")
def register_fcm_token(
    data: FcmTokenRegister,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    existing = session.exec(
        select(PushToken).where(
            PushToken.user_id == current_user.id,
            PushToken.platform == "fcm",
            PushToken.token == data.token,
        )
    ).first()
    if existing:
        return {"status": "success", "message": "Token already registered."}

    token = PushToken(user_id=current_user.id, platform="fcm", token=data.token)
    session.add(token)
    session.commit()
    return {"status": "success", "message": "FCM token registered."}


@router.post("/register/webpush")
def register_webpush_subscription(
    data: WebPushSubscriptionRegister,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    subscription_json = json.dumps({"endpoint": data.endpoint, "keys": data.keys})

    existing = session.exec(
        select(PushToken).where(
            PushToken.user_id == current_user.id,
            PushToken.platform == "webpush",
        )
    ).all()
    for row in existing:
        if json.loads(row.token).get("endpoint") == data.endpoint:
            return {"status": "success", "message": "Subscription already registered."}

    token = PushToken(
        user_id=current_user.id, platform="webpush", token=subscription_json
    )
    session.add(token)
    session.commit()
    return {"status": "success", "message": "WebPush subscription registered."}
