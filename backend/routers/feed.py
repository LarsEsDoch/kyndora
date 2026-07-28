from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select
import paho.mqtt.publish as publish
import json
import os
from database import get_session
from models import ContentFeed, User, Device
from security import get_current_user

router = APIRouter(prefix="/api/feed", tags=["feed"])

MQTT_BROKER = "192.168.178.33"
MQTT_PORT = 1883
MQTT_PASSWORD = os.getenv('MQTT_PASSWORD', 'admin123')

@router.post("/")
def send_content(
    content_type: str,
    payload: str,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user)
):
    if not current_user.partner_id:
        raise HTTPException(status_code=400, detail="No partner assigned")

    new_item = ContentFeed(
        sender_id=current_user.id,
        receiver_id=current_user.partner_id,
        content_type=content_type,
        payload=payload,
        is_displayed=False
    )
    session.add(new_item)
    session.commit()

    partner_device = session.exec(
        select(Device).where(Device.user_id == current_user.partner_id)
    ).first()

    if partner_device:
        topic = f"kyndora/{partner_device.mac_address}/content"
        trigger_msg = json.dumps({"action": "fetch_new"})

        try:
            publish.single(
                topic=topic,
                payload=trigger_msg,
                hostname=MQTT_BROKER,
                port=MQTT_PORT,
                auth={"username": "admin", "password": MQTT_PASSWORD}
            )
            print(f"MQTT Ping gesendet an {topic}")
        except Exception as e:
            print(f"Fehler beim MQTT Ping: {e}")

    return {"status": "success", "message": "Content saved and partner notified."}