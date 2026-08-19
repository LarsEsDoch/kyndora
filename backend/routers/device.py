import json
import os
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from paho.mqtt import publish
from pydantic import BaseModel
from sqlmodel import Session, select

from database import get_session
from models import Device, DeviceSettings, ProvisioningTicket, Telemetry
from schemas import DeviceSettingsUpdate
from security import create_access_token, get_current_user_id

MQTT_BROKER = "192.168.178.32"
MQTT_PORT = 1883

router = APIRouter(prefix="/api/device", tags=["Devices"])


class DeviceRegisterRequest(BaseModel):
    mac_address: str
    ticket_token: str


def _require_owned_device(
    mac_address: str, session: Session, current_user_id
) -> Device:
    device = session.get(Device, mac_address)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    if str(device.user_id) != str(current_user_id):
        raise HTTPException(status_code=403, detail="Not authorized for this device")
    return device


def _get_or_create_settings(session: Session, mac_address: str) -> DeviceSettings:
    settings = session.get(DeviceSettings, mac_address)
    if not settings:
        settings = DeviceSettings(mac_address=mac_address)
        session.add(settings)
        session.commit()
        session.refresh(settings)
    return settings


@router.get("")
def list_user_devices(
    session: Session = Depends(get_session), current_user=Depends(get_current_user_id)
):
    statement = select(Device).where(Device.user_id == current_user)
    devices = session.exec(statement).all()

    return devices


@router.get("/{mac_address}")
def get_device_details(
    mac_address: str,
    session: Session = Depends(get_session),
    current_user_id: str = Depends(get_current_user_id),
):
    device = _require_owned_device(mac_address, session, current_user_id)

    statement = (
        select(Telemetry)
        .where(Telemetry.device_mac == mac_address)
        .order_by(Telemetry.created_at.desc())
    )
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
        "uptime_s": device.uptime_s,
        "telemetry": telemetry_data,
    }


@router.get("/{mac_address}/settings")
def get_device_settings(
    mac_address: str,
    session: Session = Depends(get_session),
    current_user_id: str = Depends(get_current_user_id),
):
    _require_owned_device(mac_address, session, current_user_id)
    return _get_or_create_settings(session, mac_address)


@router.patch("/{mac_address}/settings")
def update_device_settings(
    mac_address: str,
    data: DeviceSettingsUpdate,
    session: Session = Depends(get_session),
    current_user_id: str = Depends(get_current_user_id),
):
    _require_owned_device(mac_address, session, current_user_id)
    settings = _get_or_create_settings(session, mac_address)

    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(settings, key, value)
    settings.updated_at = datetime.now(timezone.utc)

    session.add(settings)
    session.commit()
    session.refresh(settings)

    led_keys = {
        "led_enabled",
        "led_brightness",
        "adaptive_brightness",
        "night_mode",
        "night_brightness",
    }
    if led_keys & update_data.keys():
        clean_mac = mac_address.replace(":", "").upper()
        topic = f"kyndora/{clean_mac}/commands"
        payload = json.dumps(
            {
                "command": "set_led_config",
                "enabled": settings.led_enabled,
                "brightness": settings.led_brightness,
                "adaptive": settings.adaptive_brightness,
                "night_mode": settings.night_mode,
                "night_brightness": settings.night_brightness,
            }
        )
        try:
            publish.single(
                topic=topic,
                payload=payload,
                hostname=MQTT_BROKER,
                port=MQTT_PORT,
                auth={"username": "admin", "password": os.getenv("MQTT_PASSWORD")},
            )
        except Exception as e:
            print(f"MQTT Error (LED config): {e}")

    return settings


@router.post("/ticket", status_code=201)
def generate_provisioning_ticket(
    session: Session = Depends(get_session),
    current_user_id: UUID = Depends(get_current_user_id),
):
    new_ticket = ProvisioningTicket(user_id=current_user_id)
    session.add(new_ticket)
    session.commit()
    session.refresh(new_ticket)

    return {"ticket_token": new_ticket.ticket_token, "expires_in_minutes": 15}


@router.post("/register")
def register_device(
    request: DeviceRegisterRequest, session: Session = Depends(get_session)
):
    statement = select(ProvisioningTicket).where(
        ProvisioningTicket.ticket_token == request.ticket_token
    )
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

    is_new_device = device is None

    if not device:
        device = Device(mac_address=request.mac_address, user_id=ticket.user_id)
        session.add(device)
        session.flush()

        telemetry = Telemetry(device_mac=request.mac_address)
        session.add(telemetry)
    else:
        device.user_id = ticket.user_id

    device_jwt = create_access_token(
        data={"sub": request.mac_address, "role": "device"}
    )

    session.delete(ticket)
    session.commit()

    if is_new_device:
        _get_or_create_settings(session, request.mac_address)

    return {
        "device_jwt": device_jwt,
        "mqtt_username": str(ticket.user_id),
        "mqtt_password": device_jwt,
    }


@router.post("/{mac_address}/command")
def send_device_command(
    mac_address: str,
    command: str,
    session: Session = Depends(get_session),
    current_user_id: str = Depends(get_current_user_id),
):
    _require_owned_device(mac_address, session, current_user_id)

    topic = f"kyndora/{mac_address.replace(':', '')}/commands"

    try:
        publish.single(
            topic=topic,
            payload=command,
            hostname=MQTT_BROKER,
            port=MQTT_PORT,
            auth={"username": "admin", "password": os.getenv("MQTT_PASSWORD")},
        )
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to send MQTT command: {e!s}"
        )

    return {
        "status": "success",
        "message": f"Command '{command}' sent to device {mac_address}",
    }
