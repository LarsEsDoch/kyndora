#include <Arduino.h>
#include <SPI.h>
#include <WiFi.h>
#include <ctime>
#include "update.hpp"
#include "provisioning.hpp"
#include "mqtt_manager.h"
#include "light_manager.hpp"
#include "display_manager.h"
#include <ArduinoJson.h>

#define PIN_EPD_CS    10
#define PIN_EPD_DC     9
#define PIN_EPD_RST   13
#define PIN_EPD_BUSY  14
#define PIN_EPD_SCK   12
#define PIN_EPD_MOSI  11

auto ntpServer = "pool.ntp.org";
String timeZone  = "CET-1CEST,M3.5.0,M10.5.0/3";

uint32_t lastTimeMinutes = 0;
constexpr uint32_t intervalMinute = 60000;
const String currentVersion = "v0.0.0";

UpdateManager updater(currentVersion, 3);
LightManager lightManager;
DisplayManager displayManager(PIN_EPD_CS, PIN_EPD_DC, PIN_EPD_RST, PIN_EPD_BUSY);
MqttManager mqttManager;

int lastMinute = -1;
int lastFullRefreshDay = -1;

uint32_t lastWifiCheck = 0;
constexpr uint32_t wifiCheckInterval = 5000;

bool getApiErrorFlag() {
    return mqttManager.hasApiError() || updater.hasUpdateError();
}

WifiIconState getCurrentWifiIconState() {
    if (!ProvisioningManager::isProvisioned()) return WIFI_ICON_NOT_SETUP;
    if (WiFi.status() != WL_CONNECTED) return WIFI_ICON_NOT_CONNECTED;
    if (getApiErrorFlag()) return WIFI_ICON_ALERT;

    int32_t rssi = WiFi.RSSI();
    if (rssi >= -60) return WIFI_ICON_STRENGTH_4;
    if (rssi >= -70) return WIFI_ICON_STRENGTH_3;
    if (rssi >= -80) return WIFI_ICON_STRENGTH_2;
    return WIFI_ICON_STRENGTH_1;
}

void setup() {
    Serial.begin(115200);

    SPI.begin(PIN_EPD_SCK, -1, PIN_EPD_MOSI, PIN_EPD_CS);
    displayManager.begin();
    lightManager.begin();

    ProvisioningManager::begin();

    if (ProvisioningManager::isProvisioned()) {
        Preferences preferences;
        preferences.begin("kyndora", true);
        timeZone = preferences.getString("timezone", "CET-1CEST,M3.5.0,M10.5.0/3");
        String mqttUser = preferences.getString("mqtt_user", "");
        String mqttPass = preferences.getString("mqtt_pass", "");
        preferences.end();

        configTzTime(timeZone.c_str(), ntpServer);
        Serial.println("Waiting for NTP time synchronization with TZ: " + timeZone + " ...");

        tm timeInfo{};
        while (!getLocalTime(&timeInfo)) {
            delay(500);
            Serial.print(".");
        }
        Serial.println("\nTime successfully synchronized.");

        displayManager.setTime(timeInfo.tm_hour, timeInfo.tm_min);
        lastMinute = timeInfo.tm_min;
        lastFullRefreshDay = timeInfo.tm_mday;

        displayManager.setWifiState(getCurrentWifiIconState());
        displayManager.renderFull();

        String deviceId = WiFi.macAddress();
        deviceId.replace(":", "");

        const char* brokerIp = "192.168.178.32";

        mqttManager.begin(deviceId, mqttUser, mqttPass, brokerIp);
    } else {
        displayManager.showSetupScreen();
    }
}

void loop() {
    uint32_t now = millis();

    ProvisioningManager::handle();

    if (now - lastWifiCheck >= wifiCheckInterval) {
        lastWifiCheck = now;
        displayManager.setWifiState(getCurrentWifiIconState());
    }

    if (ProvisioningManager::isProvisioned() && WiFi.status() == WL_CONNECTED) {

        mqttManager.handle();
        lightManager.handle();

        if (now - lastTimeMinutes >= intervalMinute) {
            lastTimeMinutes = now;
            updater.automaticCheckForUpdates();
        }

        if (mqttManager.hasNewWeather()) {
            mqttManager.clearNewWeatherFlag();
            displayManager.setWeather(
                mqttManager.getWeatherTemp(),
                mqttManager.getWeatherCode(),
                mqttManager.getWeatherIsDay(),
                mqttManager.getWeatherWindy()
            );
        }

        if (mqttManager.hasNewContent()) {
            mqttManager.clearNewContentFlag();

            String responseJson = mqttManager.fetchLatestMessage("192.168.178.100");

            if (responseJson.length() > 0) {
                JsonDocument doc;
                DeserializationError error = deserializeJson(doc, responseJson);

                if (!error && doc["has_new"] == true) {
                    String contentType = doc["type"];
                    String payload = doc["payload"].as<String>();

                    if (contentType == "doodle") {
                        displayManager.setDoodle(payload);
                    } else {
                        displayManager.setMessage(payload);
                    }
                }
            }
        }

        tm timeInfo{};
        if (!getLocalTime(&timeInfo)) {
            delay(100);
            return;
        }

        if (timeInfo.tm_min != lastMinute) {
            lastMinute = timeInfo.tm_min;
            displayManager.setTime(timeInfo.tm_hour, timeInfo.tm_min);
        }

        if (timeInfo.tm_mday != lastFullRefreshDay) {
            lastFullRefreshDay = timeInfo.tm_mday;
            displayManager.renderFull();
        }
    }

    delay(100);
}