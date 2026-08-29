#pragma once
#include <Arduino.h>
#include <PsychicMqttClient.h>

class MqttManager {
public:
    void begin(const String& deviceId, const String& mqttUser, const String& mqttPass);

    void handle();

    bool isConnected() const { return _connected; }

    bool hasNewContent() const { return _hasNewContent; }
    void clearNewContentFlag() { _hasNewContent = false; }
    String fetchLatestMessage(const char* backendIp);

    bool hasNewWeather() const { return _hasNewWeather; }
    void clearNewWeatherFlag() { _hasNewWeather = false; }
    float getWeatherTemp() const { return _weatherTemp; }
    int getWeatherCode() const { return _weatherCode; }
    bool getWeatherIsDay() const { return _weatherIsDay; }
    bool getWeatherWindy() const { return _weatherWindy; }

    bool hasApiError() const { return _apiError; }

    bool hasPendingLightCommand() const { return _pendingLightCommand.length() > 0; }
    String consumePendingLightCommand() {
        String command = _pendingLightCommand;
        _pendingLightCommand = "";
        return command;
    }

private:
    void publishHeartbeat();
    void sendTelemetry();

    void onMqttConnect(bool sessionPresent);
    void onMqttDisconnect(bool sessionPresent);
    void onCommandMessage(char* topic, char* payload, int retain, int qos, bool dup);
    void onContentMessage(char* topic, char* payload, int retain, int qos, bool dup);

    PsychicMqttClient _client;

    String _deviceId;
    String _statusTopic;
    String _commandTopic;
    String _contentTopic;
    String _heartbeatTopic;
    String _telemetryTopic;

    bool _connected = false;

    bool _hasNewContent = false;

    bool _hasNewWeather = false;
    float _weatherTemp = 0;
    int _weatherCode = 0;
    bool _weatherIsDay = true;
    bool _weatherWindy = false;

    bool _apiError = false;

    String _pendingLightCommand = "";

    unsigned long _lastHeartbeat = 0;
    unsigned long _lastTelemetry = 0;
    const unsigned long HEARTBEAT_INTERVAL = 60000;
    const unsigned long TELEMETRY_INTERVAL = 3600000;

    const String FW_VERSION = "0.1.0";

    static constexpr const char* MQTT_SERVER_URI = "wss://mqtt.bogatzhome.com";
};