import os
import paho.mqtt.publish as publish
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from database import get_session
from models import User, PartnerRequest, Device
from security import get_current_user

router = APIRouter(prefix="/api/partners", tags=["partners"])

MQTT_BROKER = "192.168.178.33"
MQTT_PORT = 1883
MQTT_PASSWORD = os.getenv('MQTT_PASSWORD', 'admin123')

@router.post("/request")
def send_partner_request(
    target_username: str,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user)
):
    target_user = session.exec(select(User).where(User.username == target_username)).first()
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
            PartnerRequest.status == "pending"
        )
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Request already sent")

    req = PartnerRequest(sender_id=current_user.id, receiver_id=target_user.id)
    session.add(req)
    session.commit()

    return {"status": "success", "message": f"Partner request sent to {target_username}"}


@router.post("/accept/{request_id}")
def accept_partner_request(
    request_id: int,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user)
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

    return {"status": "success", "message": f"You are now partners with {sender.username}"}