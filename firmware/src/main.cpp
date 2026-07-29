#include <Arduino.h>
#include <WiFi.h>
#include <ctime>
#include <GxEPD2.h>
#include <Fonts/FreeSansBold24pt7b.h>
#include "gdey/GxEPD2_420_GDEY042T81.h"
#include <GxEPD2_BW.h>
#include "update.hpp"
#include "provisioning.hpp"
#include "mqtt_manager.h"
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
GxEPD2_BW<GxEPD2_420_GDEY042T81, GxEPD2_420_GDEY042T81::HEIGHT> display(
    GxEPD2_420_GDEY042T81(PIN_EPD_CS, PIN_EPD_DC, PIN_EPD_RST, PIN_EPD_BUSY));

MqttManager mqttManager;

int lastMinute = -1;

String currentDisplayMessage = "No messages :(";

String weatherCodeToText(int code) {
    if (code == 0) return "Klar";
    if (code == 1 || code == 2 || code == 3) return "Bewoelkt";
    if (code == 45 || code == 48) return "Nebel";
    if (code >= 51 && code <= 67) return "Regen";
    if (code >= 71 && code <= 77) return "Schnee";
    if (code >= 80 && code <= 82) return "Schauer";
    if (code >= 95) return "Gewitter";
    return "Unbekannt";
}

void drawWeather(float temp, int code) {
    constexpr uint16_t weather_x = 20;
    constexpr uint16_t weather_y = 290;
    constexpr uint16_t weather_w = 360;
    constexpr uint16_t weather_h = 50;

    String weatherText = weatherCodeToText(code) + " " + String(temp, 1) + "C";

    display.setFont();
    display.setPartialWindow(weather_x, weather_y, weather_w, weather_h);
    display.firstPage();
    do {
        display.fillRect(weather_x, weather_y, weather_w, weather_h, GxEPD_WHITE);
        display.setCursor(weather_x + 5, weather_y + 20);
        display.print(weatherText);
    } while (display.nextPage());

    display.setFont(&FreeSansBold24pt7b);
}

void setup() {
    Serial.begin(115200);

    SPI.begin(PIN_EPD_SCK, -1, PIN_EPD_MOSI, PIN_EPD_CS);
    display.init(115200, true, 2, false);
    display.setRotation(1);
    display.setTextColor(GxEPD_BLACK);
    display.setFont(&FreeSansBold24pt7b);

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

        display.firstPage();
        do {
            display.fillScreen(GxEPD_WHITE);
        } while (display.nextPage());


        String deviceId = WiFi.macAddress();
        deviceId.replace(":", "");

        const char* brokerIp = "192.168.178.33";

        mqttManager.begin(deviceId, mqttUser, mqttPass, brokerIp);
    } else {
        display.firstPage();
        do {
            display.fillScreen(GxEPD_WHITE);
            display.setCursor(50, 150);
            display.print("Awaiting Setup via Bluetooth");
        } while (display.nextPage());
    }
}

void drawDoodle(String hexString) {
    if (hexString.length() != 1600) {
        Serial.printf("Error: Unexpected Doodle-Length. Expected 1600, got %d\n", hexString.length());
        return;
    }

    uint8_t imageBuffer[800];

    for (int i = 0; i < 800; i++) {
        String hexByte = hexString.substring(i * 2, i * 2 + 2);

        imageBuffer[i] = (uint8_t) strtol(hexByte.c_str(), NULL, 16);
    }

    Serial.println("Doodle successful parsed. Draw on E-Paper...");

    int xPos = (display.width() - 80) / 2;
    int yPos = (display.height() - 80) / 2;

    display.setFullWindow();
    display.firstPage();
    do {
        display.fillScreen(GxEPD_WHITE);

        display.drawBitmap(xPos, yPos, imageBuffer, 80, 80, GxEPD_BLACK);

    } while (display.nextPage());

    Serial.println("Drawing finished.");
}

void loop() {
    uint32_t now = millis();

    ProvisioningManager::handle();

    if (ProvisioningManager::isProvisioned() && WiFi.status() == WL_CONNECTED) {

        mqttManager.handle();

        if (now - lastTimeMinutes >= intervalMinute) {
            lastTimeMinutes = now;
            updater.automaticCheckForUpdates();
        }

        if (mqttManager.hasNewWeather()) {
            mqttManager.clearNewWeatherFlag();
            drawWeather(mqttManager.getWeatherTemp(), mqttManager.getWeatherCode());
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
                        drawDoodle(payload);
                    }
                    else {
                        currentDisplayMessage = payload;

                        constexpr uint16_t msg_x = 20;
                        constexpr uint16_t msg_y = 230;
                        constexpr uint16_t msg_w = 360;
                        constexpr uint16_t msg_h = 50;

                        display.setFont();
                        display.setPartialWindow(msg_x, msg_y, msg_w, msg_h);
                        display.firstPage();
                        do {
                            display.fillRect(msg_x, msg_y, msg_w, msg_h, GxEPD_WHITE);
                            display.setCursor(msg_x + 5, msg_y + 20);
                            display.print("Partner: " + currentDisplayMessage);
                        } while (display.nextPage());

                        display.setFont(&FreeSansBold24pt7b);
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

            char zeitString[9];
            sprintf(zeitString, "%02d:%02d:%02d", timeInfo.tm_hour, timeInfo.tm_min, timeInfo.tm_sec);

            constexpr uint16_t box_x = 50;
            constexpr uint16_t box_y = 140;
            constexpr uint16_t box_w = 240;
            constexpr uint16_t box_h = 80;

            display.setPartialWindow(box_x, box_y, box_w, box_h);
            display.firstPage();
            do {
                display.fillRect(box_x, box_y, box_w, box_h, GxEPD_WHITE);
                display.setCursor(box_x + 10, box_y + 60);
                display.print(zeitString);
            } while (display.nextPage());

            if (timeInfo.tm_hour == 0) {
                display.init(0, false, 2, false);
            }
            delay(500);
        }
    }

    delay(100);
}