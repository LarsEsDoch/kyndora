#pragma once
#include <Arduino.h>
#include <BH1750.h>
#include <FastLED.h>

//#define NUM_LEDS 8
#define NUM_LEDS 1
//#define DATA_PIN 21
#define DATA_PIN 48

class LightManager {
public:
    void begin();
    void handle();

private:
    BH1750 lightMeter;
    CRGB leds[NUM_LEDS];
    uint32_t lastCheck = 0;
    const uint32_t checkInterval = 250;
};