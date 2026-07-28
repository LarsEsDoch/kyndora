#include "mqtt_manager.h"
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

WiFiClient espClient;
PubSubClient mqttClient(espClient);
MqttManager* globalMqttInstance = nullptr;

void globalMqttCallback(char* topic, byte* payload, unsigned int length) {
    if (globalMqttInstance != nullptr) {
        globalMqttInstance->handleCallback(topic, payload, length);
    }
}

void MqttManager::begin(const String& deviceId, const String& mqttUser, const String& mqttPass, const char* brokerIp) {
    _deviceId = deviceId;
    _mqttUser = mqttUser;
    _mqttPass = mqttPass;
    _brokerIp = brokerIp;

    globalMqttInstance = this;
    mqttClient.setBufferSize(1024);
    mqttClient.setServer(_brokerIp, 1883);
    mqttClient.setCallback(globalMqttCallback);
}

void MqttManager::connect() {
    Serial.print("Attempting MQTT connection...");

    String statusTopic = "kyndora/" + _deviceId + "/status";
    String commandTopic = "kyndora/" + _deviceId + "/commands";

    if (mqttClient.connect(_deviceId.c_str(),
                           _mqttUser.c_str(),
                           _mqttPass.c_str(),
                           statusTopic.c_str(),
                           1,
                           true,
                           "offline")) {

        Serial.println(" connected!");

        mqttClient.loop();

        mqttClient.publish(statusTopic.c_str(), "online", true);

        mqttClient.subscribe(commandTopic.c_str());

        publishHeartbeat();
        sendTelemetry();
                           } else {
                               Serial.print("failed, rc=");
                               Serial.print(mqttClient.state());
                               Serial.println(" - try again in 5 seconds");
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
    if (!mqttClient.connected()) return;

    JsonDocument doc;

    doc["rssi"] = WiFi.RSSI();
    doc["ssid"] = WiFi.SSID();

    doc["uptime_s"] = millis() / 1000;
    doc["free_heap"] = ESP.getFreeHeap();
    doc["core_temp"] = temperatureRead();

    doc["battery_v"] = 3.9;
    doc["battery_percent"] = 85;

    char buffer[512];
    serializeJson(doc, buffer);

    String topic = "kyndora/" + _deviceId + "/telemetry";

    if (mqttClient.publish(topic.c_str(), buffer)) {
        Serial.println("Telemetry sent: " + String(buffer));
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
        if (now - _lastTelemetry > TELEMETRY_INTERVAL) {
            _lastTelemetry = now;
            sendTelemetry();
        }
    }
}