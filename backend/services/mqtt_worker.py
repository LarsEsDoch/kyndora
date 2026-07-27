import json
import os
import paho.mqtt.client as mqtt

MQTT_BROKER = "192.168.178.33"
MQTT_PORT = 1883


def on_connect(client, userdata, flags, rc, properties=None):
    if rc == 0:
        print("Backend MQTT Worker connected successfully.")
        client.subscribe("kyndora/+/heartbeat")
    else:
        print(f"Backend MQTT Worker failed to connect, return code {rc}")


def on_message(client, userdata, msg):
    try:
        topic = msg.topic
        payload = json.loads(msg.payload.decode())

        parts = topic.split("/")
        device_mac = parts[1] if len(parts) > 1 else "unknown"

        print(f"Received Telemetry from [Device: {device_mac}]: {payload}")

        # HERE SAVE IN POSTGRESDB

    except Exception as e:
        print(f"Error handling incoming MQTT message: {str(e)}")


def init_mqtt_worker():
    client = mqtt.Client(client_id="kyndora_backend_worker")
    client.username_pw_set("admin", os.getenv('MQTT_PASSWORD'))

    client.on_connect = on_connect
    client.on_message = on_message

    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        client.loop_start()
    except Exception as e:
        print(f"Could not start MQTT worker: {e}")