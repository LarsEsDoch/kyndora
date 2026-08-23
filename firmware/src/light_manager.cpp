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
    fill_solid(leds, NUM_LEDS, WARM_WHITE_COLOR);
    FastLED.show();
}

uint8_t LightManager::getAdaptiveBrightness() {
    float rawLux = lightMeter.readLightLevel();

    if (smoothedLux < 0) {
        smoothedLux = rawLux;
    } else {
        smoothedLux = (luxSmoothingFactor * rawLux) + ((1.0f - luxSmoothingFactor) * smoothedLux);
    }

    int targetBrightness = map((long)smoothedLux, 50, 0, 255, 0);
    targetBrightness = constrain(targetBrightness, 15, 255);

    if (currentBrightness < 0) {
        currentBrightness = targetBrightness;
    } else {
        if (currentBrightness < targetBrightness) {
            currentBrightness += brightnessFadeSpeed;
            if (currentBrightness > targetBrightness) currentBrightness = targetBrightness;
        } else if (currentBrightness > targetBrightness) {
            currentBrightness -= brightnessFadeSpeed;
            if (currentBrightness < targetBrightness) currentBrightness = targetBrightness;
        }
    }

    return static_cast<uint8_t>(currentBrightness);
}

void LightManager::renderCurrentMode(uint8_t brightness) {
    FastLED.setBrightness(brightness);

    if (currentMode == MODE_RAINBOW) {
        startHue += 1;
        fill_rainbow(leds, NUM_LEDS, startHue, 7);
    } else {
        fill_solid(leds, NUM_LEDS, WARM_WHITE_COLOR);
    }

    FastLED.show();
}

void LightManager::handle() {
    uint32_t now = millis();
    if (now - lastCheck >= checkInterval) {
        lastCheck = now;

        uint8_t brightness = getAdaptiveBrightness();

        if (missYouAnimationActive) {
            renderMissYouAnimation(now, brightness);
        } else {
            renderCurrentMode(brightness);
        }
    }
}

void LightManager::setWarmWhiteMode() {
    currentMode = MODE_WARM_WHITE;
}

void LightManager::setRainbowMode() {
    currentMode = MODE_RAINBOW;
}

void LightManager::playMissYouAnimation() {
    missYouAnimationActive = true;
    missYouAnimationStart = millis();
}

void LightManager::renderMissYouAnimation(uint32_t now, uint8_t brightness) {
    const uint32_t waveOffset = 1000;

    const uint32_t totalDuration = missYouSweepDuration + (missYouRepeats - 1) * waveOffset;
    uint32_t elapsed = now - missYouAnimationStart;

    if (elapsed >= totalDuration) {
        missYouAnimationActive = false;
        renderCurrentMode(brightness);
        return;
    }

    FastLED.setBrightness(brightness);
    fill_solid(leds, NUM_LEDS, WARM_WHITE_COLOR);

    const float center = (NUM_LEDS - 1) / 2.0f;
    const float maxDistance = center + missYouStripeWidth;

    float redIntensities[NUM_LEDS] = {0};

    for (uint8_t w = 0; w < missYouRepeats; w++) {
        int32_t waveElapsed = elapsed - (w * waveOffset);

        if (waveElapsed >= 0 && waveElapsed < missYouSweepDuration) {
            float progress = static_cast<float>(waveElapsed) / static_cast<float>(missYouSweepDuration);

            float easedProgress = progress * progress * (3.0f - 2.0f * progress);
            float distance = easedProgress * maxDistance;

            float globalAlpha = 1.0f;
            if (progress < 0.10f) {
                globalAlpha = progress / 0.10f;
            } else if (progress > 0.80f) {
                globalAlpha = (1.0f - progress) / 0.20f;
            }

            for (uint8_t i = 0; i < NUM_LEDS; i++) {
                float leftStripeCenter = center - distance;
                float rightStripeCenter = center + distance;

                float leftDistance = abs(static_cast<float>(i) - leftStripeCenter);
                float rightDistance = abs(static_cast<float>(i) - rightStripeCenter);
                float stripeDistance = min(leftDistance, rightDistance);

                if (stripeDistance < missYouStripeWidth) {
                    float normalizedDist = stripeDistance / static_cast<float>(missYouStripeWidth);
                    float shapeFactor = 1.0f - normalizedDist;
                    shapeFactor = shapeFactor * shapeFactor * (3.0f - 2.0f * shapeFactor);

                    redIntensities[i] += (shapeFactor * globalAlpha);
                }
            }
        }
    }

    for (uint8_t i = 0; i < NUM_LEDS; i++) {
        if (redIntensities[i] > 0.0f) {
            float finalIntensity = min(redIntensities[i], 1.0f);
            uint8_t redAmount = static_cast<uint8_t>(255.0f * finalIntensity);

            leds[i] = blend(WARM_WHITE_COLOR, CRGB::Red, redAmount);
        }
    }

    FastLED.show();
}