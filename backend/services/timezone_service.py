import json
import os
from typing import Optional

from paho.mqtt import publish
from sqlmodel import Session, select
from timezonefinder import TimezoneFinder

import utils
from models import Device, User

MQTT_BROKER = "192.168.178.32"
MQTT_PORT = 1883
MQTT_PASSWORD = os.getenv("MQTT_PASSWORD", "admin123")

_tf = TimezoneFinder()


def _push_timezone_to_device(device: Device, tz_string: str):
    clean_mac = device.mac_address.replace(":", "").upper()
    topic = f"kyndora/{clean_mac}/commands"
    payload = json.dumps({"command": "set_timezone", "tz": tz_string})

    try:
        publish.single(
            topic=topic,
            payload=payload,
            hostname=MQTT_BROKER,
            port=MQTT_PORT,
            auth={"username": "admin", "password": MQTT_PASSWORD},
        )
    except Exception as e:
        print(f"MQTT Error (set_timezone): {e}")


def resolve_and_push_partner_timezone(session: Session, user: User) -> Optional[str]:
    iana_name: Optional[str] = None

    if user.timezone_auto_detect:
        if user.latitude is None or user.longitude is None:
            return None
        iana_name = _tf.timezone_at(lat=user.latitude, lng=user.longitude)
        if not iana_name:
            print(
                f"Timezone auto-detect: keine Zone für ({user.latitude}, {user.longitude}) gefunden."
            )
            return None
        user.iana_timezone = iana_name
    else:
        iana_name = user.iana_timezone
        if not iana_name:
            return None

    tz_string = utils.get_posix_tz(iana_name)

    session.add(user)
    session.commit()

    if not user.partner_id:
        return tz_string

    partner_device = session.exec(
        select(Device).where(Device.user_id == user.partner_id)
    ).first()

    if not partner_device:
        return tz_string

    partner_device.timezone = tz_string
    session.add(partner_device)
    session.commit()

    _push_timezone_to_device(partner_device, tz_string)

    return tz_string
