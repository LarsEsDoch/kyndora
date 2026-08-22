#include "light_manager.hpp"

void LightManager::begin() {

    Wire.begin(2, 1);

    if (lightMeter.begin(BH1750::CONTINUOUS_HIGH_RES_MODE)) {
        Serial.println("BH1750 successfully initialized.");
    } else {
        Serial.println("Error starting the BH1750!");
    }

    FastLED.addLeds<WS2812B, DATA_PIN, GRB>(leds, NUM_LEDS);
    FastLED.setMaxPowerInVoltsAndMilliamps(5, 1000);
    FastLED.setBrightness(0);
    FastLED.show();
}

void LightManager::handle() {
    uint32_t now = millis();
    if (now - lastCheck >= checkInterval) {
        lastCheck = now;

        float lux = lightMeter.readLightLevel();

        int brightness = map((long)lux, 50, 5, 255, 5);
        brightness = constrain(brightness, 0, 255);
        FastLED.setBrightness(brightness);

        static uint8_t startHue = 0;
        startHue += 1;

        fill_rainbow(leds, NUM_LEDS, startHue, 7);

        FastLED.show();
    }
}