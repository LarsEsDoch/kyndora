#include "mqtt_manager.h"
#include <WiFi.h>
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <Preferences.h>

static const char* MQTT_CA_CERT =
"-----BEGIN CERTIFICATE-----\n"
"MIICCTCCAY6gAwIBAgINAgPlwGjvYxqccpBQUjAKBggqhkjOPQQDAzBHMQswCQYD\n"
"VQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIG\n"
"A1UEAxMLR1RTIFJvb3QgUjQwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAw\n"
"WjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2Vz\n"
"IExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjQwdjAQBgcqhkjOPQIBBgUrgQQAIgNi\n"
"AATzdHOnaItgrkO4NcWBMHtLSZ37wWHO5t5GvWvVYRg1rkDdc/eJkTBa6zzuhXyi\n"
"QHY7qca4R9gq55KRanPpsXI5nymfopjTX15YhmUPoYRlBtHci8nHc8iMai/lxKvR\n"
"HYqjQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW\n"
"BBSATNbrdP9JNqPV2Py1PsVq8JQdjDAKBggqhkjOPQQDAwNpADBmAjEA6ED/g94D\n"
"9J+uHXqnLrmvT/aDHQ4thQEd0dlq7A/Cr8deVl5c1RxYIigL9zC2L7F8AjEA8GE8\n"
"p/SgguMh1YQdc4acLa/KNJvxn7kjNuK8YAOdgLOaVsjh4rsUecrNIdSUtUlD\n"
"-----END CERTIFICATE-----\n";

void MqttManager::begin(const String& deviceId, const String& mqttUser, const String& mqttPass) {
    _deviceId = deviceId;

    _statusTopic = "kyndora/" + _deviceId + "/status";
    _commandTopic = "kyndora/" + _deviceId + "/commands";
    _contentTopic = "kyndora/" + _deviceId + "/content";
    _heartbeatTopic = "kyndora/" + _deviceId + "/heartbeat";
    _telemetryTopic = "kyndora/" + _deviceId + "/telemetry";
    _buttonTopic = "kyndora/" + _deviceId + "/button";

    _client.setServer(MQTT_SERVER_URI);
    _client.setCredentials(mqttUser.c_str(), mqttPass.c_str());
    _client.setClientId(_deviceId.c_str());
    _client.setCleanSession(true);
    _client.setKeepAlive(60);
    _client.setAutoReconnect(true);
    _client.setBufferSize(2048);
    _client.setCACert(MQTT_CA_CERT);

    _client.setWill(_statusTopic.c_str(), 1, true, "offline");

    _client.onConnect([this](bool sessionPresent) { onMqttConnect(sessionPresent); });
    _client.onDisconnect([this](bool sessionPresent) { onMqttDisconnect(sessionPresent); });
    _client.onError([this](esp_mqtt_error_codes_t error) {
        Serial.printf("MQTT Error, type=%d\n", error.error_type);
        _apiError = true;
    });

    _client.onTopic(_commandTopic.c_str(), 1, [this](char* topic, char* payload, int retain, int qos, bool dup) {
        onCommandMessage(topic, payload, retain, qos, dup);
    });

    _client.onTopic(_contentTopic.c_str(), 1, [this](char* topic, char* payload, int retain, int qos, bool dup) {
        onContentMessage(topic, payload, retain, qos, dup);
    });

    _client.connect();
}

void MqttManager::onMqttConnect(bool sessionPresent) {
    Serial.println("MQTT connected via WSS.");
    _connected = true;
    _apiError = false;

    _client.publish(_statusTopic.c_str(), 1, true, "online");

    publishHeartbeat();
    sendTelemetry();
}

void MqttManager::onMqttDisconnect(bool sessionPresent) {
    Serial.println("MQTT disconnected.");
    _connected = false;
}

void MqttManager::publishHeartbeat() {
    if (!_connected) return;

    JsonDocument doc;
    doc["status"] = "online";
    doc["uptime_s"] = millis() / 1000;
    doc["battery_level"] = 85;

    char buffer[256];
    size_t len = serializeJson(doc, buffer, sizeof(buffer));

    _client.publish(_heartbeatTopic.c_str(), 0, false, buffer, len);
    Serial.println("Heartbeat published!");
}

void MqttManager::sendTelemetry() {
    if (!_connected) return;

    preferences.begin("kyndora", true);
    fw_version = preferences.getString("fw_applied", "");
    preferences.end();

    JsonDocument doc;
    doc["rssi"] = WiFi.RSSI();
    doc["ssid"] = WiFi.SSID();
    doc["fw_version"] = fw_version;
    doc["free_heap"] = ESP.getFreeHeap();
    doc["core_temp"] = temperatureRead();
    doc["battery_v"] = 3.9;
    doc["battery_percent"] = 85;

    char buffer[512];
    size_t len = serializeJson(doc, buffer, sizeof(buffer));

    int msgId = _client.publish(_telemetryTopic.c_str(), 0, false, buffer, len);
    if (msgId != -1) {
        Serial.println("Telemetry sent!");
    } else {
        Serial.println("Failed to send telemetry.");
    }
}

void MqttManager::handle() {
    if (!_connected) return;

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

void MqttManager::onCommandMessage(char* topic, char* payload, int retain, int qos, bool dup) {
    Serial.print("Command received: ");
    Serial.println(payload);

    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, payload);

    if (error) {
        String message = String(payload);
        if (message == "restart") {
            Serial.println("Received command: Restart in 3 seconds...");
            delay(3000);
            ESP.restart();
        } else if (message == "factory_reset") {
            Serial.println("Received command: Resetting Kyndora settings and restarting in 3 seconds...");
            Preferences prefs;
            prefs.begin("kyndora", false);
            prefs.clear();
            prefs.end();
            delay(3000);
            ESP.restart();
        } else if (message == "check_update") {
            _pendingUpdateCheck = true;
            Serial.println("Received command: Check for updates now");
        } else {
            Serial.println("Unknown message.");
        }
        return;
    }

    String command = doc["command"] | "";

    if (command == "set_timezone") {
        String newTz = doc["tz"].as<String>();

        Preferences prefs;
        prefs.begin("kyndora", false);
        prefs.putString("timezone", newTz);
        prefs.end();

        configTzTime(newTz.c_str(), "pool.ntp.org");
        Serial.println("Timezone succesful updated!");
    } else if (command == "set_weather") {
        _weatherTemp = doc["temp"].as<float>();
        _weatherCode = doc["code"].as<int>();
        _weatherIsDay = doc["is_day"].as<bool>();
        _weatherWindy = doc["windy"].as<bool>();
        _hasNewWeather = true;
        Serial.println("Weather data received.");
    } else if (command == "set_return_time") {
        time_t timestamp = doc["timestamp"].as<time_t>();

        Preferences prefs;
        prefs.begin("kyndora", false);
        prefs.putULong64("return_time", (uint64_t)timestamp);
        prefs.end();

        _returnTime = timestamp;
        _hasNewReturnTime = true;

        Serial.printf("Return time saved: %llu\n", (unsigned long long)timestamp);
    } else if (command == "rainbow") {
        _pendingLightCommand = "rainbow";
        Serial.println("Received command: Rainbow mode");
    } else if (command == "warm_white") {
        _pendingLightCommand = "warm_white";
        Serial.println("Received command: Warm white mode");
    } else if (command == "miss_you") {
        _pendingLightCommand = "miss_you";
        Serial.println("Received command: Miss you animation");
    } else {
        Serial.println("Unknown command.");
    }
}

void MqttManager::onContentMessage(char* topic, char* payload, int retain, int qos, bool dup) {
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, payload);

    if (!error && doc["action"] == "fetch_new") {
        Serial.println("Ping from backend! Set flag to download new content.");
        _hasNewContent = true;
    }
}

String MqttManager::fetchLatestMessage(const char* backendIp) {
    if (WiFi.status() != WL_CONNECTED) return "";

    HTTPClient http;
    String url = "https://" + String(backendIp) + "/api/feed/device/" + _deviceId + "/latest";

    http.begin(url);
    int httpCode = http.GET();

    String jsonResponse = "";

    if (httpCode == HTTP_CODE_OK) {
        jsonResponse = http.getString();
        _apiError = false;
    } else {
        Serial.printf("HTTP GET failed, Error: %s\n", http.errorToString(httpCode).c_str());
        _apiError = true;
    }

    http.end();
    return jsonResponse;
}

void MqttManager::publishButtonEvent(const String& action) {
    if (!_connected) return;

    JsonDocument doc;
    doc["action"] = action;

    char buffer[128];
    size_t len = serializeJson(doc, buffer, sizeof(buffer));

    _client.publish(_buttonTopic.c_str(), 0, false, buffer, len);
    Serial.println("Button event published: " + action);
}