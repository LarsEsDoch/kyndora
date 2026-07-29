#include "mqtt_manager.h"
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <Preferences.h>

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
    String contentTopic = "kyndora/" + _deviceId + "/content";

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
        mqttClient.subscribe(contentTopic.c_str());

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

void MqttManager::handleCallback(char* topic, byte* payload, unsigned int length) {
    String message = "";
    for (unsigned int i = 0; i < length; i++) {
        message += (char)payload[i];
    }

    Serial.print("Message received on Topic: ");
    Serial.println(topic);
    Serial.print("Payload: ");
    Serial.println(message);

    String expectedCommandTopic = "kyndora/" + _deviceId + "/commands";
    String expectedContentTopic = "kyndora/" + _deviceId + "/content";

    if (String(topic) == expectedCommandTopic) {
        JsonDocument doc;
        DeserializationError error = deserializeJson(doc, message);

        if (!error && doc["command"] == "set_timezone") {
            String newTz = doc["tz"].as<String>();

            Preferences prefs;
            prefs.begin("kyndora", false);
            prefs.putString("timezone", newTz);
            prefs.end();

            configTzTime(newTz.c_str(), "pool.ntp.org");
            Serial.println("Timezone succesful updated!");
        }
        else if (!error && doc["command"] == "set_weather") {
            _weatherTemp = doc["temp"].as<float>();
            _weatherCode = doc["code"].as<int>();
            _hasNewWeather = true;
            Serial.println("Weather data received.");
        }
        else if (message == "restart") {
            Serial.println("Received command: Restart in 3 seconds...");
            delay(3000);
            ESP.restart();
        }
        else {
            Serial.println("Unknown command.");
        }
    }
    else if (String(topic) == expectedContentTopic) {
        JsonDocument doc;
        DeserializationError error = deserializeJson(doc, message);

        if (!error && doc["action"] == "fetch_new") {
            Serial.println("Ping from backend! Set flag to download new content.");

            _hasNewContent = true;
        }
    }
}

String MqttManager::fetchLatestMessage(const char* backendIp) {
    if (WiFi.status() != WL_CONNECTED) return "";

    HTTPClient http;
    String url = "http://" + String(backendIp) + ":8000/api/feed/device/" + _deviceId + "/latest";

    http.begin(url);
    int httpCode = http.GET();

    String jsonResponse = "";

    if (httpCode == HTTP_CODE_OK) {
        jsonResponse = http.getString();
        Serial.println("Feed-Data successful fetched.");
    } else {
        Serial.printf("HTTP GET failed, Error: %s\n", http.errorToString(httpCode).c_str());
    }

    http.end();
    return jsonResponse;
}