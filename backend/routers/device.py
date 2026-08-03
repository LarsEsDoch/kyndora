import os
import json

from fastapi import APIRouter, Depends, HTTPException, status
from paho.mqtt import publish
from sqlmodel import Session, select
from pydantic import BaseModel
from datetime import datetime, timezone
from uuid import UUID

import utils
from database import get_session
from models import Device, ProvisioningTicket, Telemetry, User
from security import get_current_user_id, create_access_token, get_current_user

MQTT_BROKER = "192.168.178.32"
MQTT_PORT = 1883

router = APIRouter(prefix="/api/device", tags=["Devices"])


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


@router.get("/{mac_address}")
def get_device_details(
        mac_address: str,
        session: Session = Depends(get_session),
        current_user_id: str = Depends(get_current_user_id)
):
    device = session.get(Device, mac_address)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    if str(device.user_id) != str(current_user_id):
        raise HTTPException(status_code=403, detail="Not authorized for this device")

    statement = select(Telemetry).where(Telemetry.device_mac == mac_address).order_by(Telemetry.created_at.desc())
    latest_telemetry = session.exec(statement).first()

    last_seen_str = "Never"
    if device.last_seen_at:
        last_seen_str = device.last_seen_at.strftime("%d.%m.%Y %H:%M:%S")

    telemetry_data = {}
    if latest_telemetry:
        telemetry_data = latest_telemetry.model_dump()
        telemetry_data["temperature"] = latest_telemetry.core_temp

    return {
        "mac_address": device.mac_address,
        "name": device.name,
        "status": device.status,
        "last_seen": last_seen_str,
        "firmware_version": device.firmware_version,
        "battery_level": device.battery_level,
        "timezone": device.timezone,
        "telemetry": telemetry_data
    }

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

    if device.user_id != current_user_id:
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

@router.post("/display-timezone")
def set_display_device_timezone(
        iana_name: str,
        session: Session = Depends(get_session),
        current_user: User = Depends(get_current_user)
):
    if not current_user.partner_id:
        raise HTTPException(status_code=400, detail="You don't have partner assigned.")

    partner_device = session.exec(
        select(Device).where(Device.user_id == current_user.partner_id)
    ).first()

    tz_string = utils.get_posix_tz(iana_name)

    partner_device.timezone = tz_string
    session.add(partner_device)
    session.commit()

    clean_mac = partner_device.mac_address.replace(":", "").upper()
    topic = f"kyndora/{clean_mac}/commands"

    payload = json.dumps({
        "command": "set_timezone",
        "tz": tz_string
    })

    try:
        publish.single(
            topic=topic,
            payload=payload,
            hostname=MQTT_BROKER,
            port=MQTT_PORT,
            auth={"username": "admin", "password": os.getenv('MQTT_PASSWORD')}
        )
    except Exception as e:
        print(f"MQTT Error: {e}")

    return {
        "status": "success",
        "message": f"Timezone changed to '{tz_string}' for your partner."
    }