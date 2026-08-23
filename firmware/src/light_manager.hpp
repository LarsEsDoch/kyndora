#pragma once
#include <Arduino.h>
#include <BH1750.h>
#include <FastLED.h>

#define NUM_LEDS 14
#define DATA_PIN 21

class LightManager {
public:
    void begin();
    void handle();

    void setWarmWhiteMode();
    void setRainbowMode();
    void playMissYouAnimation();

private:
    enum Mode {
        MODE_WARM_WHITE,
        MODE_RAINBOW
    };

    BH1750 lightMeter;
    CRGB leds[NUM_LEDS];
    uint32_t lastCheck = 0;
    const uint32_t checkInterval = 10;

    float smoothedLux = -1.0f;
    float currentBrightness = -1.0f;

    const float luxSmoothingFactor = 0.05f;
    const float brightnessFadeSpeed = 0.50f;

    const CRGB WARM_WHITE_COLOR = CRGB(255, 110, 20);

    Mode currentMode = MODE_WARM_WHITE;
    uint8_t startHue = 0;

    bool missYouAnimationActive = false;
    uint32_t missYouAnimationStart = 0;
    const uint16_t missYouSweepDuration = 1500;
    const uint8_t missYouRepeats = 3;
    const uint8_t missYouStripeWidth = 5;

    uint8_t getAdaptiveBrightness();
    void renderCurrentMode(uint8_t brightness);
    void renderMissYouAnimation(uint32_t now, uint8_t brightness);
};