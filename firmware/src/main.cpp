#include <Arduino.h>
#include <GxEPD2_4G_4G.h>
#include <GxEPD2_4G_BW.h>
#include <Fonts/FreeSansBold12pt7b.h>

#include "gdey/GxEPD2_420_GDEY042T81.h"

#define EPD_CS    10
#define EPD_DC     9
#define EPD_RST   13
#define EPD_BUSY  14
#define EPD_SCK   12
#define EPD_MOSI  11

GxEPD2_4G_4G<GxEPD2_420_GDEY042T81, GxEPD2_420_GDEY042T81::HEIGHT> display(
    GxEPD2_420_GDEY042T81(EPD_CS, EPD_DC, EPD_RST, EPD_BUSY)
);

void helloWorldGrayScale() {
    display.setRotation(1);
    display.setFullWindow();
    display.firstPage();
    do {
        display.fillScreen(GxEPD_WHITE);
        display.setFont(&FreeSansBold12pt7b);

        display.setTextColor(GxEPD_BLACK);
        display.setCursor(20, 50);
        display.print("1. Schwarz");
        display.fillRect(230, 30, 50, 30, GxEPD_BLACK);

        display.setTextColor(GxEPD_DARKGREY);
        display.setCursor(20, 100);
        display.print("2. Dunkelgrau");
        display.fillRect(230, 80, 50, 30, GxEPD_DARKGREY);

        display.setTextColor(GxEPD_LIGHTGREY);
        display.setCursor(20, 150);
        display.print("3. Hellgrau");
        display.fillRect(230, 130, 50, 30, GxEPD_LIGHTGREY);

        display.fillRect(15, 180, 270, 40, GxEPD_DARKGREY);
        display.setTextColor(GxEPD_WHITE);
        display.setCursor(20, 210);
        display.print("4. Weiss auf Grau");

    } while (display.nextPage());
    Serial.println("Display-Update fertig!");
}

void setup() {
    Serial.begin(115200);
    delay(2000);

    Serial.printf("Total PSRAM: %d Bytes\n", ESP.getPsramSize());
    Serial.printf("Free PSRAM:   %d Bytes\n", ESP.getFreePsram());

    SPI.begin(EPD_SCK, -1, EPD_MOSI, EPD_CS);

    Serial.println("Initialize E-Ink...");
    display.init(115200, true, 2, false);


    helloWorldGrayScale();
    display.hibernate();
}

void loop() {
    // Ein simpler Herzschlag-Monitor im Code
    digitalWrite(STATUS_LED, HIGH);
    Serial.println("System Status: OK (Heartbeat gesendet)");
    delay(1000);

    digitalWrite(STATUS_LED, LOW);
    delay(4000); // Alle 5 Sekunden blinken
}