import paho.mqtt.client as mqtt
from dotenv import load_dotenv

load_dotenv()

MQTT_BROKER = "192.168.178.32"
MQTT_PORT = 1883

client = mqtt.Client(client_id="kyndora_backend")


def connect_mqtt():
    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        client.loop_start()
        print("MQTT Broker connected")
    except Exception as e:
        print(f"MQTT Error: {e}")


def publish_message(topic: str, message: str):
    client.publish(topic, message)
