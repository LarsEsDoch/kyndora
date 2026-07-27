#include "mqtt_manager.h"
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

WiFiClient espClient;
PubSubClient mqttClient(espClient);

void MqttManager::begin(const String& deviceId, const String& mqttUser, const String& mqttPass, const char* brokerIp) {
    _deviceId = deviceId;
    _mqttUser = mqttUser;
    _mqttPass = mqttPass;
    _brokerIp = brokerIp;

    mqttClient.setServer(_brokerIp, 1883);
}

void MqttManager::connect() {
    Serial.print("Attempting MQTT connection...");

    if (mqttClient.connect(_deviceId.c_str(), _mqttUser.c_str(), _mqttPass.c_str())) {
        Serial.println("connected!");

        publishHeartbeat();

        // String subTopic = "kyndora/" + _deviceId + "/doodle";
        // mqttClient.subscribe(subTopic.c_str());
    } else {
        Serial.print("failed, rc=");
        Serial.print(mqttClient.state());
        Serial.println(" try again in 5 seconds");
    }
}

void MqttManager::publishHeartbeat() {
    if (!mqttClient.connected()) return;

    JsonDocument doc;
    doc["status"] = "online";
    doc["fw_version"] = FW_VERSION;

    doc["battery_level"] = 85; 

    char buffer[256];
    serializeJson(doc, buffer);

    String topic = "kyndora/" + _deviceId + "/heartbeat";

    mqttClient.publish(topic.c_str(), buffer);
    Serial.println("Heartbeat published: " + String(buffer));
}

void MqttManager::sendTelemetry() {
    String topic = "kyndora/" + _deviceId + "/telemetry";
    
    String payload = "{";
    payload += "\"rssi\": " + String(WiFi.RSSI()) + ",";
    payload += "\"uptime\": " + String(millis() / 1000);
    payload += "}";

    if (mqttClient.publish(topic.c_str(), payload.c_str())) {
        Serial.println("Telemetry sent successfully!");
    } else {
        Serial.println("Failed to send telemetry.");
    }
}

void MqttManager::handle() {
    if (WiFi.status() != WL_CONNECTED) return;

    if (!mqttClient.connected()) {
        unsigned long now = millis();
        if (now - _lastReconnectAttempt > 5000) {
            _lastReconnectAttempt = now;
            connect();
        }
    } else {
        mqttClient.loop();

        unsigned long now = millis();
        if (now - _lastHeartbeat > HEARTBEAT_INTERVAL) {
            _lastHeartbeat = now;
            publishHeartbeat();
        }
    }
}