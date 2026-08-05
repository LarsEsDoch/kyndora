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


void DisplayManager::setWifiState(WifiIconState state) {
    if (_wifiInitialized && _wifiState == state) return;
    _wifiState = state;
    _wifiInitialized = true;
    updateTopBar();
}

void DisplayManager::setTime(int hour, int minute) {
    if (_hasTime && _hour == hour && _minute == minute) return;
    _hour = hour;
    _minute = minute;
    _hasTime = true;
    updateTimeRow();
}


void DisplayManager::partialRefresh(int16_t y, int16_t h, void (DisplayManager::*paintFn)()) {
    const int16_t w = _display.width();

    _display.setPartialWindow(0, y, w, h);
    _display.firstPage();
    do {
        _display.fillRect(0, y, w, h, GxEPD_WHITE);
        (this->*paintFn)();
    } while (_display.nextPage());

    registerPartialUpdate();
}

void DisplayManager::registerPartialUpdate() {
    _partialUpdateCount++;
    if (_partialUpdateCount >= FULL_REFRESH_THRESHOLD) {
        renderFull();
    }
}

void DisplayManager::updateTopBar() { partialRefresh(TOP_BAR_Y, TOP_BAR_H, &DisplayManager::paintTopBar); }
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

void DisplayManager::paintTopBar() {
    String freshness = buildFreshnessText();
    if (freshness.length() > 0) {
        _display.setFont();
        _display.setTextSize(2);
        _display.setCursor(10, TOP_BAR_Y + TOP_BAR_H / 2 + 4);
        _display.print(freshness);
    }

    const uint8_t* icon = wifiIconBitmap();
    int16_t iconX = _display.width() - WIFI_ICON_TARGET_SIZE - 10;
    int16_t iconY = TOP_BAR_Y + (TOP_BAR_H - WIFI_ICON_TARGET_SIZE) / 2;
    drawIconBitmap(icon, iconX, iconY, WIFI_ICON_TARGET_SIZE);
}

void DisplayManager::paintTime() {
    if (!_hasTime) return;

    char buffer[6];
    sprintf(buffer, "%02d:%02d", _hour, _minute);

    _display.setFont(&DejaVuSans_Bold36pt7b);
    _display.setTextSize(1);

    int16_t x1, y1;
    uint16_t tw, th;
    _display.getTextBounds(buffer, 0, 0, &x1, &y1, &tw, &th);

    int16_t cursorX = (_display.width() - tw) / 2 - x1;
    int16_t cursorY = TIME_Y + (TIME_H + th) / 2;

    _display.setCursor(cursorX, cursorY);
    _display.print(buffer);
}


const uint8_t* DisplayManager::wifiIconBitmap() const {
    switch (_wifiState) {
        case WIFI_ICON_NOT_SETUP: return ICON_WIFI_NOT_SET_UP;
        case WIFI_ICON_NOT_CONNECTED: return ICON_WIFI_NOT_CONNECTED;
        case WIFI_ICON_ALERT: return ICON_WIFI_ALERT;
        case WIFI_ICON_STRENGTH_1: return ICON_WIFI_STRENGTH_1;
        case WIFI_ICON_STRENGTH_2: return ICON_WIFI_STRENGTH_2;
        case WIFI_ICON_STRENGTH_3: return ICON_WIFI_STRENGTH_3;
        default: return ICON_WIFI_STRENGTH_4;
    }
}

void DisplayManager::drawIconBitmap(const uint8_t* bitmap, int16_t x, int16_t y, int16_t targetSize) {
    const int16_t rowBytes = (WEATHER_ICON_SIZE + 7) / 8;

    for (int16_t ty = 0; ty < targetSize; ty++) {
        int16_t srcY = (ty * WEATHER_ICON_SIZE) / targetSize;
        for (int16_t tx = 0; tx < targetSize; tx++) {
            int16_t srcX = (tx * WEATHER_ICON_SIZE) / targetSize;

            uint8_t byteVal = pgm_read_byte(&bitmap[srcY * rowBytes + (srcX / 8)]);
            bool isSet = byteVal & (1 << (7 - (srcX % 8)));

            if (isSet) {
                _display.drawPixel(x + tx, y + ty, GxEPD_BLACK);
            }
        }
    }
}

