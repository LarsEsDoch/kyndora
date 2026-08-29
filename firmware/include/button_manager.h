#pragma once
#include <Arduino.h>

class ButtonManager {
public:
    void begin(int8_t missYouPin, int8_t powerPin, int8_t nextPin, int8_t prevPin);
    void handle();

    bool hasMissYouPressed() { bool v = _missYouPressed; _missYouPressed = false; return v; }
    bool hasPowerPressed()   { bool v = _powerPressed;   _powerPressed = false;   return v; }
    bool hasNextPressed()    { bool v = _nextPressed;    _nextPressed = false;    return v; }
    bool hasPreviousPressed(){ bool v = _prevPressed;    _prevPressed = false;    return v; }

private:
    struct ButtonState {
        int8_t pin = -1;
        bool lastRaw = HIGH;
        bool stableState = HIGH;
        uint32_t lastChangeMs = 0;
    };

    static constexpr uint32_t DEBOUNCE_MS = 20;

    ButtonState _missYouBtn;
    ButtonState _powerBtn;
    ButtonState _nextBtn;
    ButtonState _prevBtn;

    bool _missYouPressed = false;
    bool _powerPressed = false;
    bool _nextPressed = false;
    bool _prevPressed = false;

    void updateButton(ButtonState& btn, bool& pressedFlag);
};