import json
import os

from fastapi import APIRouter, Depends, HTTPException
from paho.mqtt import publish
from sqlmodel import Session, or_, select

from database import get_session
from models import ContentFeed, Device, User
from security import get_current_user

router = APIRouter(prefix="/api/feed", tags=["feed"])

MQTT_BROKER = "192.168.178.32"
MQTT_PORT = 1883
MQTT_PASSWORD = os.getenv("MQTT_PASSWORD", "admin123")


def format_mac(mac: str) -> str:
    if len(mac) == 12 and ":" not in mac:
        return ":".join(mac[i : i + 2] for i in range(0, 12, 2)).upper()
    return mac.upper()


@router.get("")
def get_current_feed(
    session: Session = Depends(get_session), current_user=Depends(get_current_user)
):
    statement = (
        select(ContentFeed)
        .where(
            or_(
                ContentFeed.receiver_id == current_user.id,
                ContentFeed.sender_id == current_user.id,
            )
        )
        .order_by(ContentFeed.created_at.desc())
        .limit(5)
    )

    feed_items = session.exec(statement).all()

    result = []
    for item in feed_items:
        result.append(
            {
                "id": item.id,
                "content_type": item.content_type,
                "payload": item.payload,
                "is_displayed": item.is_displayed,
                "created_at": item.created_at.isoformat(),
                "direction": "sent"
                if item.sender_id == current_user.id
                else "received",
            }
        )

    return result


@router.post("/")
def send_content(
    content_type: str,
    payload: str,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    if not current_user.partner_id:
        raise HTTPException(status_code=400, detail="No partner assigned")

    new_item = ContentFeed(
        sender_id=current_user.id,
        receiver_id=current_user.partner_id,
        content_type=content_type,
        payload=payload,
        is_displayed=False,
    )
    session.add(new_item)
    session.commit()

    partner_device = session.exec(
        select(Device).where(Device.user_id == current_user.partner_id)
    ).first()

    if partner_device:
        topic = f"kyndora/{partner_device.mac_address.replace(':', '').upper()}/content"
        trigger_msg = json.dumps({"action": "fetch_new"})

        try:
            publish.single(
                topic=topic,
                payload=trigger_msg,
                hostname=MQTT_BROKER,
                port=MQTT_PORT,
                auth={"username": "admin", "password": MQTT_PASSWORD},
            )
            print(f"MQTT Ping gesendet an {topic}")
        except Exception as e:
            print(f"Fehler beim MQTT Ping: {e}")

    return {"status": "success", "message": "Content saved and partner notified."}


@router.get("/device/{mac_address}/latest")
def get_latest_content_for_device(
    mac_address: str, session: Session = Depends(get_session)
):
    clean_mac = format_mac(mac_address)
    device = session.get(Device, clean_mac)
    if not device or not device.user_id:
        raise HTTPException(status_code=4404, detail="Device or owner not found")

    statement = (
        select(ContentFeed)
        .where(
            ContentFeed.receiver_id == device.user_id, ContentFeed.is_displayed == False
        )
        .order_by(ContentFeed.created_at.desc())
    )
    content_item = session.exec(statement).first()

    if not content_item:
        return {"has_new": False}

    content_item.is_displayed = True
    session.add(content_item)
    session.commit()

    return {
        "has_new": True,
        "id": content_item.id,
        "type": content_item.content_type,
        "payload": content_item.payload,
    }
