import os

from fastapi import APIRouter, Depends, HTTPException, status
from paho.mqtt import publish
from sqlmodel import Session, select
from pydantic import BaseModel
from datetime import datetime, timezone
from uuid import UUID

from database import get_session
from models import Device, ProvisioningTicket, Telemetry
from security import get_current_user_id, create_access_token

MQTT_BROKER = "192.168.178.33"
MQTT_PORT = 1883

router = APIRouter(prefix="/api/device", tags=["Device Provisioning"])


class DeviceRegisterRequest(BaseModel):
    mac_address: str
    ticket_token: str

@router.get("")
def list_user_devices(
        session: Session = Depends(get_session),
        current_user=Depends(get_current_user_id)
):
    statement = select(Device).where(Device.user_id == current_user)
    devices = session.exec(statement).all()

    return devices

@router.post("/ticket", status_code=201)
def generate_provisioning_ticket(
        session: Session = Depends(get_session),
        current_user_id: str = Depends(get_current_user_id)
):
    new_ticket = ProvisioningTicket(user_id=UUID(current_user_id))
    session.add(new_ticket)
    session.commit()
    session.refresh(new_ticket)

    return {
        "ticket_token": new_ticket.ticket_token,
        "expires_in_minutes": 15
    }


@router.post("/register")
def register_device(
        request: DeviceRegisterRequest,
        session: Session = Depends(get_session)
):

    statement = select(ProvisioningTicket).where(ProvisioningTicket.ticket_token == request.ticket_token)
    ticket = session.exec(statement).first()

    if not ticket:
        raise HTTPException(status_code=404, detail="Invalid provisioning ticket")

    expires_at = ticket.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)

    if expires_at < datetime.now(timezone.utc):
        session.delete(ticket)
        session.commit()
        raise HTTPException(status_code=400, detail="Ticket has expired")

    device_statement = select(Device).where(Device.mac_address == request.mac_address)
    device = session.exec(device_statement).first()

    if not device:
        device = Device(mac_address=request.mac_address, user_id=ticket.user_id)
        session.add(device)
        session.flush()

        telemetry = Telemetry(device_mac=request.mac_address)
        session.add(telemetry)
    else:
        device.user_id = ticket.user_id

    device_jwt = create_access_token(data={"sub": request.mac_address, "role": "device"})

    session.delete(ticket)
    session.commit()

    return {
        "device_jwt": device_jwt,
        "mqtt_username": str(ticket.user_id),
        "mqtt_password": device_jwt
    }


@router.post("/{mac_address}/command")
def send_device_command(
        mac_address: str,
        command: str,
        session: Session = Depends(get_session),
        current_user_id: str = Depends(get_current_user_id)
):
    device = session.get(Device, mac_address)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    if str(device.user_id) != current_user_id:
        raise HTTPException(status_code=403, detail="Not authorized for this device")

    topic = f"kyndora/{mac_address.replace(':', '')}/commands"

    try:
        publish.single(
            topic=topic,
            payload=command,
            hostname=MQTT_BROKER,
            port=MQTT_PORT,
            auth={"username": "admin", "password": os.getenv('MQTT_PASSWORD')}
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send MQTT command: {str(e)}")

    return {"status": "success", "message": f"Command '{command}' sent to device {mac_address}"}