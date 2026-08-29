import json
import os
from datetime import datetime, timezone

import paho.mqtt.client as mqtt
from sqlmodel import Session, select

from database import engine
from models import Device, Telemetry, User
from services.push_service import send_push_to_user

MQTT_BROKER = "192.168.178.32"
MQTT_PORT = 1883


def on_connect(client, userdata, flags, rc, properties=None):
    if rc == 0:
        print("Backend MQTT Worker connected successfully.")
        client.subscribe("kyndora/+/#")
    else:
        print(f"Backend MQTT Worker failed to connect, return code {rc}")


def format_mac(mac: str) -> str:
    if len(mac) == 12 and ":" not in mac:
        return ":".join(mac[i : i + 2] for i in range(0, 12, 2)).upper()
    return mac.upper()


def on_message(client, userdata, msg):
    try:
        topic = msg.topic
        payload_raw = msg.payload.decode()

        parts = topic.split("/")
        if len(parts) < 3:
            return

        device_mac = parts[1]
        msg_type = parts[2]

        db_mac = format_mac(device_mac)

        with Session(engine) as session:
            if msg_type == "status":
                device = session.get(Device, db_mac)
                if device:
                    device.status = payload_raw
                    device.last_seen_at = datetime.now(timezone.utc)
                    session.add(device)
                    session.commit()

            else:
                payload = json.loads(payload_raw)

                if msg_type == "heartbeat":
                    device = session.get(Device, db_mac)
                    if device:
                        device.status = payload.get("status", device.status)
                        device.uptime_s = payload.get("uptime_s", device.uptime_s)
                        device.battery_level = payload.get(
                            "battery_level", device.battery_level
                        )
                        device.last_seen_at = datetime.now(timezone.utc)
                        session.add(device)
                        session.commit()

                elif msg_type == "telemetry":
                    device = session.get(Device, db_mac)
                    statement = select(Telemetry).where(Telemetry.device_mac == db_mac)
                    telemetry = session.exec(statement).first()
                    if telemetry:
                        telemetry.rssi = payload.get("rssi", telemetry.rssi)
                        telemetry.ssid = payload.get("ssid", telemetry.ssid)
                        device.firmware_version = payload.get(
                            "fw_version", device.firmware_version
                        )
                        telemetry.free_heap = payload.get(
                            "free_heap", telemetry.free_heap
                        )
                        telemetry.core_temp = payload.get(
                            "core_temp", telemetry.core_temp
                        )
                        telemetry.battery_v = payload.get(
                            "battery_v", telemetry.battery_v
                        )
                        telemetry.battery_percent = payload.get(
                            "battery_percent", telemetry.battery_percent
                        )
                        session.add(telemetry)
                        session.commit()

                elif msg_type == "button":
                    action = payload.get("action")
                    device = session.get(Device, db_mac)
                    if not device:
                        return

                    owner = session.get(User, device.user_id)
                    if not owner or not owner.partner_id:
                        return

                    if action == "miss_you":
                        partner_device = session.exec(
                            select(Device).where(Device.user_id == owner.partner_id)
                        ).first()

                        if partner_device:
                            partner_mac = partner_device.mac_address.replace(":", "").upper()
                            client.publish(
                                f"kyndora/{partner_mac}/commands",
                                json.dumps({"command": "miss_you"}),
                            )

                        try:
                            send_push_to_user(
                                session,
                                owner.partner_id,
                                title=owner.username,
                                body="is thinking of you 💌",
                                data={"type": "miss_you"},
                            )
                        except Exception as e:
                            print(f"Push notification failed (button miss_you): {e}")

    except json.JSONDecodeError:
        pass
    except Exception as e:
        print(f"Error handling incoming MQTT message: {e!s}")


def init_mqtt_worker():
    client = mqtt.Client(client_id="kyndora_backend_worker")

    admin_password = os.getenv("MQTT_PASSWORD", "admin123")
    client.username_pw_set("admin", admin_password)

    client.on_connect = on_connect
    client.on_message = on_message

    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        client.loop_start()
    except Exception as e:
        print(f"Could not start MQTT worker: {e}")
