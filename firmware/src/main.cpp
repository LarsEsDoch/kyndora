#include <Arduino.h>
#include <WiFi.h>
#include <ctime>
#include <GxEPD2.h>
#include <Fonts/FreeSansBold24pt7b.h>
#include "gdey/GxEPD2_420_GDEY042T81.h"
#include <GxEPD2_BW.h>

#define PIN_EPD_CS    10
#define PIN_EPD_DC     9
#define PIN_EPD_RST   13
#define PIN_EPD_BUSY  14
#define PIN_EPD_SCK   12
#define PIN_EPD_MOSI  11

const char* ssid     = "***REMOVED***";
const char* password = "***REMOVED***";

const char* ntpServer = "pool.ntp.org";
const char* timeZone  = "CET-1CEST,M3.5.0,M10.5.0/3";

GxEPD2_BW<GxEPD2_420_GDEY042T81, GxEPD2_420_GDEY042T81::HEIGHT> display(
    GxEPD2_420_GDEY042T81(PIN_EPD_CS, PIN_EPD_DC, PIN_EPD_RST, PIN_EPD_BUSY));

int letzteMinute = -1;
unsigned long letzteNTPUpdate = 0;

void setup() {
    Serial.begin(115200);

    SPI.begin(PIN_EPD_SCK, -1, PIN_EPD_MOSI, PIN_EPD_CS);

    display.init(115200, true, 2, false);
    display.setRotation(1);
    display.setTextColor(GxEPD_BLACK);
    display.setFont(&FreeSansBold24pt7b);

    Serial.print("Verbinde mit ");
    Serial.println(ssid);
    WiFi.begin(ssid, password);
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("\nWLAN verbunden!");

    configTzTime(timeZone, ntpServer);
    Serial.println("Warte auf NTP-Zeitsynchronisation...");

    struct tm timeinfo;
    while (!getLocalTime(&timeinfo)) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("\nZeit erfolgreich synchronisiert.");

    display.firstPage();
    do {
        display.fillScreen(GxEPD_WHITE);
    } while (display.nextPage());
}

void loop() {
    struct tm timeinfo;
    if (!getLocalTime(&timeinfo)) {
        Serial.println("Fehler beim Abrufen der lokalen Zeit");
        delay(1000);
        return;
    }

    if (timeinfo.tm_sec != letzteMinute) {
        letzteMinute = timeinfo.tm_sec;

        char zeitString[9];
        sprintf(zeitString, "%02d:%02d:%02d", timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec);
        Serial.print("Aktualisiere Uhrzeit auf: ");
        Serial.println(zeitString);

        uint16_t box_x = 50;
        uint16_t box_y = 140;
        uint16_t box_w = 240;
        uint16_t box_h = 80;

        display.setPartialWindow(box_x, box_y, box_w, box_h);
        display.firstPage();
        do {
            display.fillRect(box_x, box_y, box_w, box_h, GxEPD_WHITE);

            display.setCursor(box_x + 10, box_y + 60);
            display.print(zeitString);
        } while (display.nextPage());

        if (timeinfo.tm_min == 0) {
            display.init(0, false, 2, false);
        }
    }

    delay(100);
}