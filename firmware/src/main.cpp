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
#include "weather_icons.h"
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

void drawIconBitmap(const uint8_t* bitmap, int16_t x, int16_t y, uint8_t scale) {
    const int16_t rowBytes = (WEATHER_ICON_SIZE + 7) / 8;

    for (int16_t row = 0; row < WEATHER_ICON_SIZE; row++) {
        for (int16_t col = 0; col < WEATHER_ICON_SIZE; col++) {
            uint8_t byteVal = pgm_read_byte(&bitmap[row * rowBytes + (col / 8)]);
            bool isSet = byteVal & (1 << (7 - (col % 8)));

            if (isSet) {
                display.fillRect(x + col * scale, y + row * scale, scale, scale, GxEPD_BLACK);
            }
        }
    }
}

const uint8_t* selectWeatherIcon(int code, bool isDay, bool windy) {
    if (code >= 95) {
        return ICON_THUNDERSTORM;
    }
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
        return ICON_WEATHER_SNOWY;
    }
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
        return ICON_RAINY;
    }
    if (code == 45 || code == 48) {
        return ICON_MIST;
    }
    if (windy && code <= 3) {
        return ICON_AIR;
    }
    if (code == 0) {
        return isDay ? ICON_CLEAR_DAY : ICON_MOON_STARS;
    }
    if (code == 1 || code == 2) {
        return isDay ? ICON_PARTLY_CLOUDY_DAY : ICON_PARTLY_CLOUDY_NIGHT;
    }
    return ICON_CLOUD;
}

void drawWeather(float temp, int code, bool isDay, bool windy) {
    constexpr uint16_t weather_x = 20;
    constexpr uint16_t weather_y = 225;
    constexpr uint16_t weather_w = 360;
    constexpr uint16_t weather_h = 70;
    constexpr uint8_t iconScale = 2;

    display.setPartialWindow(weather_x, weather_y, weather_w, weather_h);
    display.firstPage();
    do {
        display.fillRect(weather_x, weather_y, weather_w, weather_h, GxEPD_WHITE);

        const uint8_t* icon = selectWeatherIcon(code, isDay, windy);
        drawIconBitmap(icon, weather_x + 5, weather_y + 11, iconScale);

        display.setFont();
        display.setTextSize(2);
        display.setCursor(weather_x + 90, weather_y + 30);
        display.print(String(temp, 1) + " C");
        display.setTextSize(1);
    } while (display.nextPage());
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
            drawWeather(
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
                        drawDoodle(payload);
                    }
                    else {
                        currentDisplayMessage = payload;

                        constexpr uint16_t msg_x = 20;
                        constexpr uint16_t msg_y = 305;
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