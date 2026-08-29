#include "button_manager.h"

void ButtonManager::begin(int8_t missYouPin, int8_t powerPin, int8_t nextPin, int8_t prevPin) {
    _missYouBtn.pin = missYouPin;
    _powerBtn.pin = powerPin;
    _nextBtn.pin = nextPin;
    _prevBtn.pin = prevPin;

    pinMode(missYouPin, INPUT_PULLUP);
    pinMode(powerPin, INPUT_PULLUP);
    pinMode(nextPin, INPUT_PULLUP);
    pinMode(prevPin, INPUT_PULLUP);
}

void ButtonManager::handle() {
    updateButton(_missYouBtn, _missYouPressed);
    updateButton(_powerBtn, _powerPressed);
    updateButton(_nextBtn, _nextPressed);
    updateButton(_prevBtn, _prevPressed);
}

void ButtonManager::updateButton(ButtonState& btn, bool& pressedFlag) {
    if (btn.pin < 0) return;

    bool raw = digitalRead(btn.pin);
    uint32_t now = millis();

    if (raw != btn.lastRaw) {
        btn.lastChangeMs = now;
        btn.lastRaw = raw;
    }

    if ((now - btn.lastChangeMs) > DEBOUNCE_MS && btn.stableState != btn.lastRaw) {
        btn.stableState = btn.lastRaw;

        if (btn.stableState == LOW) {
            pressedFlag = true;
        }
    }
}