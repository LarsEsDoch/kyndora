import os
import time
import json
import threading
import requests
import paho.mqtt.publish as publish
from sqlmodel import Session, select
from database import engine
from models import Device, User

MQTT_BROKER = "192.168.178.33"
MQTT_PORT = 1883
MQTT_PASSWORD = os.getenv('MQTT_PASSWORD', 'admin123')
WEATHER_INTERVAL_SECONDS = 900


def fetch_weather(latitude: float, longitude: float):
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "current": "temperature_2m,weather_code"
    }
    response = requests.get(url, params=params, timeout=10)
    response.raise_for_status()
    current = response.json()["current"]
    return current["temperature_2m"], current["weather_code"]


def push_weather_to_device(device: Device, temperature: float, weather_code: int):
    clean_mac = device.mac_address.replace(":", "").upper()
    topic = f"kyndora/{clean_mac}/commands"

    payload = json.dumps({
        "command": "set_weather",
        "temp": temperature,
        "code": weather_code
    })

    publish.single(
        topic=topic,
        payload=payload,
        hostname=MQTT_BROKER,
        port=MQTT_PORT,
        auth={"username": "admin", "password": MQTT_PASSWORD}
    )


def run_weather_cycle():
    with Session(engine) as session:
        devices = session.exec(select(Device)).all()

        for device in devices:
            user = session.get(User, device.user_id)
            if not user or not user.partner_id:
                continue

            partner = session.get(User, user.partner_id)
            if not partner or partner.latitude is None or partner.longitude is None:
                continue

            try:
                temperature, weather_code = fetch_weather(partner.latitude, partner.longitude)
                push_weather_to_device(device, temperature, weather_code)
                print(f"Weather pushed to {device.mac_address}: {temperature}C, code {weather_code}")
            except Exception as e:
                print(f"Weather update failed for {device.mac_address}: {e}")


def weather_loop():
    while True:
        run_weather_cycle()
        time.sleep(WEATHER_INTERVAL_SECONDS)


def init_weather_worker():
    thread = threading.Thread(target=weather_loop, daemon=True)
    thread.start()