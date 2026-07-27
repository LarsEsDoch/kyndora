#pragma once
#include <Arduino.h>

class MqttManager {
public:
    void begin(const String& deviceId, const String& mqttUser, const String& mqttPass, const char* brokerIp);

    void handle();

private:
    void connect();
    void publishHeartbeat();
    void sendTelemetry();

    String _deviceId;
    String _mqttUser;
    String _mqttPass;
    const char* _brokerIp;

    unsigned long _lastReconnectAttempt = 0;
    unsigned long _lastHeartbeat = 0;
    unsigned long _lastTelemetry = 0;
    const unsigned long HEARTBEAT_INTERVAL = 60000;
    const unsigned long TELEMETRY_INTERVAL = 3600000;

    const String FW_VERSION = "0.1.0";
};