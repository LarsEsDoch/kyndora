import json
import os
from uuid import UUID

import firebase_admin
from firebase_admin import credentials, messaging
from pywebpush import WebPushException, webpush
from sqlmodel import Session, select

from models import PushToken

FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH")
VAPID_PRIVATE_KEY = os.getenv("VAPID_PRIVATE_KEY")
VAPID_PUBLIC_KEY = os.getenv("VAPID_PUBLIC_KEY")
VAPID_CLAIMS_EMAIL = os.getenv("VAPID_CLAIMS_EMAIL", "mailto:admin@example.com")

_firebase_app = None
if FIREBASE_CREDENTIALS_PATH and os.path.exists(FIREBASE_CREDENTIALS_PATH):
    try:
        cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
        _firebase_app = firebase_admin.initialize_app(cred)
        print("Firebase Admin SDK initialized.")
    except Exception as e:
        print(f"Firebase Admin init failed: {e}")
else:
    print("FIREBASE_CREDENTIALS_PATH nicht gesetzt/gefunden - FCM-Push deaktiviert.")


def _send_fcm(token: str, title: str, body: str, data: dict) -> bool:
    if not _firebase_app:
        return True
    try:
        message = messaging.Message(
            token=token,
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in data.items()},
        )
        messaging.send(message)
        return True
    except (messaging.UnregisteredError, messaging.SenderIdMismatchError):
        return False
    except Exception as e:
        print(f"FCM send error: {e}")
        return True


def _send_webpush(subscription_json: str, title: str, body: str, data: dict) -> bool:
    if not VAPID_PRIVATE_KEY or not VAPID_PUBLIC_KEY:
        return True
    try:
        subscription_info = json.loads(subscription_json)
        payload = json.dumps({"title": title, "body": body, "data": data})
        webpush(
            subscription_info=subscription_info,
            data=payload,
            vapid_private_key=VAPID_PRIVATE_KEY,
            vapid_claims={"sub": VAPID_CLAIMS_EMAIL},
        )
        return True
    except WebPushException as e:
        status = getattr(e.response, "status_code", None)
        if status in (404, 410):
            return False
        print(f"WebPush error: {e}")
        return True
    except Exception as e:
        print(f"WebPush error: {e}")
        return True


def send_push_to_user(
    session: Session,
    user_id: UUID,
    title: str,
    body: str,
    data: dict | None = None,
):
    data = data or {}
    statement = select(PushToken).where(PushToken.user_id == user_id)
    tokens = session.exec(statement).all()

    for token_row in tokens:
        if token_row.platform == "fcm":
            still_valid = _send_fcm(token_row.token, title, body, data)
        elif token_row.platform == "webpush":
            still_valid = _send_webpush(token_row.token, title, body, data)
        else:
            continue

        if not still_valid:
            session.delete(token_row)

    session.commit()
