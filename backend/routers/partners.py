import json
import os
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request
from paho.mqtt import publish
from sqlmodel import Session, select

from database import get_session
from models import Device, MorningQuoteSettings, PartnerRequest, User
from schemas import MoodUpdate, MorningQuotesUpdate, ReturnTimeUpdate, TimezoneUpdate
from security import get_current_user
from services.push_service import send_push_to_user
from services.timezone_service import resolve_and_push_partner_timezone
from ws_manager import notify_user

router = APIRouter(prefix="/api/partners", tags=["partners"])

MQTT_BROKER = "192.168.178.32"
MQTT_PORT = 1883
MQTT_PASSWORD = os.getenv("MQTT_PASSWORD", "admin123")


def _push_to_partner_device(
    session: Session, current_user: User, command: str, extra: dict
):
    if not current_user.partner_id:
        return

    partner_device = session.exec(
        select(Device).where(Device.user_id == current_user.partner_id)
    ).first()
    if not partner_device:
        return

    clean_mac = partner_device.mac_address.replace(":", "").upper()
    topic = f"kyndora/{clean_mac}/commands"
    body = {"command": command, **extra}

    try:
        publish.single(
            topic=topic,
            payload=json.dumps(body),
            hostname=MQTT_BROKER,
            port=MQTT_PORT,
            auth={"username": "admin", "password": MQTT_PASSWORD},
        )
    except Exception as e:
        print(f"MQTT Error ({command}): {e}")


@router.post("/request")
def send_partner_request(
    target_username: str,
    request: Request,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    target_user = session.exec(
        select(User).where(User.username == target_username)
    ).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="User not found")

    if target_user.id == current_user.id:
        raise HTTPException(status_code=400, detail="You cannot partner with yourself")

    if current_user.partner_id:
        raise HTTPException(status_code=400, detail="You already have a partner")

    existing = session.exec(
        select(PartnerRequest).where(
            PartnerRequest.sender_id == current_user.id,
            PartnerRequest.receiver_id == target_user.id,
            PartnerRequest.status == "pending",
        )
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Request already sent")

    req = PartnerRequest(sender_id=current_user.id, receiver_id=target_user.id)
    session.add(req)
    session.commit()
    session.refresh(req)

    notify_user(
        str(target_user.id),
        {
            "type": "partner_request",
            "data": {
                "id": req.id,
                "sender_username": current_user.username,
                "created_at": req.created_at.isoformat(),
            },
        },
        request.app.state.loop,
    )

    try:
        send_push_to_user(
            session,
            target_user.id,
            title="New Partner Request",
            body=f"{current_user.username} wants to connect with you on Kyndora",
            data={"type": "partner_request"},
        )
    except Exception as e:
        print(f"Push notification failed: {e}")

    return {
        "status": "success",
        "message": f"Partner request sent to {target_username}",
    }


@router.get("/requests/pending")
def get_pending_requests(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    statement = (
        select(PartnerRequest)
        .where(
            PartnerRequest.receiver_id == current_user.id,
            PartnerRequest.status == "pending",
        )
        .order_by(PartnerRequest.created_at.desc())
    )

    requests = session.exec(statement).all()

    result = []
    for req in requests:
        sender = session.get(User, req.sender_id)
        result.append(
            {
                "id": req.id,
                "sender_username": sender.username if sender else "Unknown",
                "created_at": req.created_at,
            }
        )

    return result


@router.post("/decline/{request_id}")
def decline_partner_request(
    request_id: int,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    req = session.get(PartnerRequest, request_id)
    if not req or req.receiver_id != current_user.id:
        raise HTTPException(status_code=404, detail="Request not found")

    if req.status != "pending":
        raise HTTPException(status_code=400, detail="Request is no longer pending")

    req.status = "declined"
    session.add(req)
    session.commit()

    return {"status": "success", "message": "Request declined."}


@router.post("/accept/{request_id}")
def accept_partner_request(
    request_id: int,
    request: Request,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    req = session.get(PartnerRequest, request_id)
    if not req or req.receiver_id != current_user.id:
        raise HTTPException(status_code=404, detail="Request not found")

    if req.status != "pending":
        raise HTTPException(status_code=400, detail="Request is no longer pending")

    sender = session.get(User, req.sender_id)
    if not sender:
        raise HTTPException(status_code=404, detail="Sender not found")

    current_user.partner_id = sender.id
    sender.partner_id = current_user.id

    req.status = "accepted"

    session.add(current_user)
    session.add(sender)
    session.add(req)
    session.commit()

    notify_user(
        str(sender.id),
        {
            "type": "partner_accepted",
            "data": {"username": current_user.username},
        },
        request.app.state.loop,
    )

    return {
        "status": "success",
        "message": f"You are now partners with {sender.username}",
    }


@router.get("/status")
def get_partner_status(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    if not current_user.partner_id:
        return {"has_partner": False}

    partner = session.get(User, current_user.partner_id)
    if not partner:
        raise HTTPException(status_code=404, detail="Partner not found")

    return {
        "has_partner": True,
        "username": partner.username,
        "mood": partner.mood,
        "is_sleeping": partner.is_sleeping,
        "status_updated_at": partner.status_updated_at,
        "return_time": partner.return_time,
    }


@router.post("/mood")
def update_mood(
    data: MoodUpdate,
    request: Request,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    current_user.mood = data.mood
    current_user.is_sleeping = data.is_sleeping
    current_user.status_updated_at = datetime.now(timezone.utc)
    session.add(current_user)
    session.commit()

    _push_to_partner_device(
        session,
        current_user,
        "set_mood",
        {"mood": data.mood, "is_sleeping": data.is_sleeping},
    )

    if current_user.partner_id:
        notify_user(
            str(current_user.partner_id),
            {"type": "partner_status_changed"},
            request.app.state.loop,
        )

    return {"status": "success", "message": "Mood updated."}


@router.post("/return-time")
def set_return_time(
    data: ReturnTimeUpdate,
    request: Request,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    current_user.return_time = data.timestamp
    session.add(current_user)
    session.commit()

    _push_to_partner_device(
        session,
        current_user,
        "set_return_time",
        {"timestamp": data.timestamp.timestamp()},
    )

    if current_user.partner_id:
        notify_user(
            str(current_user.partner_id),
            {"type": "partner_status_changed"},
            request.app.state.loop,
        )

    return {"status": "success", "message": "Return time updated."}


@router.get("/quotes")
def get_morning_quotes(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    settings = session.get(MorningQuoteSettings, current_user.id)
    if not settings:
        return {"wake_hour": 7, "wake_minute": 0, "quotes": []}
    return settings


@router.post("/quotes")
def set_morning_quotes(
    data: MorningQuotesUpdate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    settings = session.get(MorningQuoteSettings, current_user.id)
    if not settings:
        settings = MorningQuoteSettings(user_id=current_user.id)

    settings.wake_hour = data.wake_hour
    settings.wake_minute = data.wake_minute
    settings.quotes = data.quotes
    settings.updated_at = datetime.now(timezone.utc)

    session.add(settings)
    session.commit()

    _push_to_partner_device(
        session,
        current_user,
        "set_morning_quotes",
        {
            "wake_hour": data.wake_hour,
            "wake_minute": data.wake_minute,
            "quotes": data.quotes,
        },
    )

    return {"status": "success", "message": "Morning quotes saved."}


@router.post("/timezone")
def set_timezone(
    data: TimezoneUpdate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    if not data.auto_detect and not data.iana_timezone:
        raise HTTPException(
            status_code=400,
            detail="iana_timezone is required when auto_detect is disabled.",
        )

    current_user.timezone_auto_detect = data.auto_detect
    if not data.auto_detect:
        current_user.iana_timezone = data.iana_timezone

    resolved_tz = resolve_and_push_partner_timezone(session, current_user)

    return {
        "status": "success",
        "message": "Timezone settings updated.",
        "resolved_timezone": resolved_tz,
    }


@router.post("/miss-you")
def send_miss_you(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    if not current_user.partner_id:
        raise HTTPException(status_code=400, detail="No partner assigned")

    _push_to_partner_device(session, current_user, "miss_you", {})

    try:
        send_push_to_user(
            session,
            current_user.partner_id,
            title=current_user.username,
            body="is thinking of you 💌",
            data={"type": "miss_you"},
        )
    except Exception as e:
        print(f"Push notification failed: {e}")

    return {"status": "success", "message": "Miss you sent."}
