#include "display_manager.h"
#include "icons.h"

DisplayManager::DisplayManager(int8_t cs, int8_t dc, int8_t rst, int8_t busy)
    : _display(GxEPD2_420_GDEY042T81(cs, dc, rst, busy)) {
}

void DisplayManager::begin() {
    _display.init(115200, true, 2, false);
    _display.setRotation(1);
    _display.setTextColor(GxEPD_BLACK);
}

void DisplayManager::setTime(int hour, int minute) {
    if (_hasTime && _hour == hour && _minute == minute) return;
    _hour = hour;
    _minute = minute;
    _hasTime = true;
    updateTimeRow();
}

void DisplayManager::updateTimeRow() { partialRefresh(TIME_Y, TIME_H, &DisplayManager::paintTime); }

void DisplayManager::renderFull() {
    _display.setFullWindow();
    _display.firstPage();
    do {
        _display.fillScreen(GxEPD_WHITE);
        paintTopBar();
        paintTime();
        paintWeather();
        paintMessage();
        paintImages();
        paintCountdown();
        paintLocation();
    } while (_display.nextPage());

    _partialUpdateCount = 0;
}

