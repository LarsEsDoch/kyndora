#include <Arduino.h>
#include <WiFi.h>
#include <ctime>
#include <GxEPD2.h>
#include <Fonts/FreeSansBold24pt7b.h>
#include "gdey/GxEPD2_420_GDEY042T81.h"
#include <GxEPD2_BW.h>
#include "update.hpp"

#define PIN_EPD_CS    10
#define PIN_EPD_DC     9
#define PIN_EPD_RST   13
#define PIN_EPD_BUSY  14
#define PIN_EPD_SCK   12
#define PIN_EPD_MOSI  11

const char* ssid     = "***REMOVED***";
const char* password = "***REMOVED***";

auto ntpServer = "pool.ntp.org";
auto timeZone  = "CET-1CEST,M3.5.0,M10.5.0/3";

uint32_t lastTimeSeconds = 0;
uint32_t lastTimeMinutes = 0;
uint32_t lastTimeHours   = 0;

const uint32_t intervalSecond = 1000;
const uint32_t intervalMinute = 60000;
const uint32_t intervalHour   = 3600000;

const String currentVersion = "v0.0.0";

UpdateManager updater(currentVersion, 3);

GxEPD2_BW<GxEPD2_420_GDEY042T81, GxEPD2_420_GDEY042T81::HEIGHT> display(
    GxEPD2_420_GDEY042T81(PIN_EPD_CS, PIN_EPD_DC, PIN_EPD_RST, PIN_EPD_BUSY));

int lastMinute = -1;
unsigned long lastNTPUpdate = 0;

void setup() {
    Serial.begin(115200);

    SPI.begin(PIN_EPD_SCK, -1, PIN_EPD_MOSI, PIN_EPD_CS);

    display.init(115200, true, 2, false);
    display.setRotation(1);
    display.setTextColor(GxEPD_BLACK);
    display.setFont(&FreeSansBold24pt7b);

    Serial.print("Connect with ");
    Serial.println(ssid);
    WiFi.begin(ssid, password);
    while (WiFiClass::status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("\nWi-Fi connected!");

    configTzTime(timeZone, ntpServer);
    Serial.println("Waiting for NTP time synchronization...");

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
}

void loop() {
    uint32_t now = millis();

    if (now - lastTimeSeconds >= intervalSecond) {
        lastTimeSeconds = now;

    }

    if (now - lastTimeMinutes >= intervalMinute) {
        lastTimeMinutes = now;

        updater.automaticCheckForUpdates();
    }

    if (now - lastTimeHours >= intervalHour) {
        lastTimeHours = now;

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

    delay(100);
}