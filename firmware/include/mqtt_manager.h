#pragma once
#include <Arduino.h>

class MqttManager {
public:
    void begin(const String& deviceId, const String& mqttUser, const String& mqttPass, const char* brokerIp);

    void handle();
    void handleCallback(char* topic, byte* payload, unsigned int length);

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
private:
    void connect();
    void publishHeartbeat();
    void sendTelemetry();

    String _deviceId;
    String _mqttUser;
    String _mqttPass;
    const char* _brokerIp;

    bool _hasNewContent = false;

    bool _hasNewWeather = false;
    float _weatherTemp = 0;
    int _weatherCode = 0;
    bool _weatherIsDay = true;
    bool _weatherWindy = false;

    bool _apiError = false;

    unsigned long _lastReconnectAttempt = 0;
    unsigned long _lastHeartbeat = 0;
    unsigned long _lastTelemetry = 0;
    const unsigned long HEARTBEAT_INTERVAL = 60000;
    const unsigned long TELEMETRY_INTERVAL = 3600000;

    const String FW_VERSION = "0.1.0";
};