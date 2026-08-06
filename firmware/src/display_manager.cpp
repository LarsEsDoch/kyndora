#include "display_manager.h"
#include "FreeSansBold36pt7b.h"
#include "icons.h"

DisplayManager::DisplayManager(int8_t cs, int8_t dc, int8_t rst, int8_t busy)
    : _display(GxEPD2_420_GDEY042T81(cs, dc, rst, busy)) {
}

void DisplayManager::begin() {
    _display.init(115200, true, 2, false);
    _display.setRotation(1);
    _display.setTextColor(GxEPD_BLACK);
}

void DisplayManager::showSetupScreen() {
    _display.setFullWindow();
    _display.firstPage();
    do {
        _display.fillScreen(GxEPD_WHITE);
        _display.setFont();
        _display.setTextSize(2);
        _display.setCursor(30, _display.height() / 2);
        _display.print("Awaiting Setup via Bluetooth");
    } while (_display.nextPage());
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

void DisplayManager::setWeather(float temp, int code, bool isDay, bool windy) {
    _weatherTemp = temp;
    _weatherCode = code;
    _weatherIsDay = isDay;
    _weatherWindy = windy;
    _hasWeather = true;
    updateWeatherRow();
}

void DisplayManager::setMessage(const String& text) {
    _message = text;

    tm timeInfo{};
    if (getLocalTime(&timeInfo)) {
        _messageTm = timeInfo;
        _hasMessageTimestamp = true;
    }

    updateMessageRow();
    updateTopBar();
}

void DisplayManager::setDoodle(const String& hexString) {
    if (hexString.length() != DOODLE_SIZE * DOODLE_SIZE / 8 * 2) {
        return;
    }

    for (int i = 0; i < DOODLE_SIZE * DOODLE_SIZE / 8; i++) {
        String hexByte = hexString.substring(i * 2, i * 2 + 2);
        _doodleBuffer[i] = (uint8_t) strtol(hexByte.c_str(), NULL, 16);
    }

    _hasDoodle = true;
    updateImagesRow();
}

void DisplayManager::setCountdownText(const String& text) {
    _countdownText = text;
    updateCountdownRow();
}

void DisplayManager::setLocationText(const String& text) {
    _locationText = text;
    updateLocationRow();
}

void DisplayManager::setLocationStale(bool stale) {
    if (_locationStale == stale) return;
    _locationStale = stale;
    updateLocationRow();
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
void DisplayManager::updateWeatherRow() { partialRefresh(WEATHER_Y, WEATHER_H, &DisplayManager::paintWeather); }
void DisplayManager::updateMessageRow() { partialRefresh(MESSAGE_Y, MESSAGE_H, &DisplayManager::paintMessage); }
void DisplayManager::updateImagesRow() { partialRefresh(IMAGES_Y, IMAGES_H, &DisplayManager::paintImages); }
void DisplayManager::updateCountdownRow() { partialRefresh(COUNTDOWN_Y, COUNTDOWN_H, &DisplayManager::paintCountdown); }
void DisplayManager::updateLocationRow() { partialRefresh(LOCATION_Y, LOCATION_H, &DisplayManager::paintLocation); }

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

void DisplayManager::paintWeather() {
    if (!_hasWeather) return;

    const uint8_t* icon = selectWeatherIcon();
    String tempText = String(_weatherTemp, 1) + " C";

    _display.setFont();
    _display.setTextSize(2);

    int16_t x1, y1;
    uint16_t tw, th;
    _display.getTextBounds(tempText, 0, 0, &x1, &y1, &tw, &th);

    int16_t gap = 10;
    int16_t totalWidth = WEATHER_ICON_TARGET_SIZE + gap + tw;
    int16_t startX = (_display.width() - totalWidth) / 2;
    int16_t iconY = WEATHER_Y + (WEATHER_H - WEATHER_ICON_TARGET_SIZE) / 2;

    drawIconBitmap(icon, startX, iconY, WEATHER_ICON_TARGET_SIZE);

    _display.setCursor(startX + WEATHER_ICON_TARGET_SIZE + gap - x1, WEATHER_Y + WEATHER_H / 2 + th / 2);
    _display.print(tempText);
}

void DisplayManager::paintMessage() {
    if (_message.length() == 0) return;

    _display.setFont();
    _display.setTextSize(2);

    int16_t x1, y1;
    uint16_t tw, th;
    _display.getTextBounds(_message, 0, 0, &x1, &y1, &tw, &th);

    int16_t cursorX = (_display.width() - tw) / 2 - x1;
    int16_t cursorY = MESSAGE_Y + MESSAGE_H / 2 + th / 2;

    _display.setCursor(cursorX, cursorY);
    _display.print(_message);
}

void DisplayManager::paintImages() {
    if (!_hasDoodle) return;

    int16_t gap = 20;
    int16_t totalWidth = DOODLE_SIZE * 2 + gap;
    int16_t startX = (_display.width() - totalWidth) / 2;
    int16_t imgY = IMAGES_Y + (IMAGES_H - DOODLE_SIZE) / 2;

    _display.drawBitmap(startX, imgY, _doodleBuffer, DOODLE_SIZE, DOODLE_SIZE, GxEPD_BLACK);
    _display.drawBitmap(startX + DOODLE_SIZE + gap, imgY, _doodleBuffer, DOODLE_SIZE, DOODLE_SIZE, GxEPD_BLACK);
}

void DisplayManager::paintCountdown() {
    if (_countdownText.length() == 0) return;

    _display.setFont();
    _display.setTextSize(1);

    int16_t x1, y1;
    uint16_t tw, th;
    _display.getTextBounds(_countdownText, 0, 0, &x1, &y1, &tw, &th);

    int16_t cursorX = (_display.width() - tw) / 2 - x1;
    int16_t cursorY = COUNTDOWN_Y + COUNTDOWN_H / 2 + th / 2;

    _display.setCursor(cursorX, cursorY);
    _display.print(_countdownText);
}

void DisplayManager::paintLocation() {
    if (_locationText.length() == 0) return;

    _display.setFont();
    _display.setTextSize(2);

    int16_t x1, y1;
    uint16_t tw, th;
    _display.getTextBounds(_locationText, 0, 0, &x1, &y1, &tw, &th);

    int16_t iconSize = 24;
    int16_t gap = 10;
    int16_t totalWidth = iconSize + gap + tw;
    int16_t startX = (_display.width() - totalWidth) / 2;

    drawIconBitmap(locationIconBitmap(), startX, LOCATION_Y + (LOCATION_H - iconSize) / 2, iconSize);

    _display.setCursor(startX + iconSize + gap - x1, LOCATION_Y + LOCATION_H / 2 + th / 2);
    _display.print(_locationText);
}

String DisplayManager::buildFreshnessText() {
    if (!_hasMessageTimestamp) return "";

    tm nowTm{};
    if (!getLocalTime(&nowTm)) return "";

    tm nowMidnight = nowTm;
    nowMidnight.tm_hour = 0;
    nowMidnight.tm_min = 0;
    nowMidnight.tm_sec = 0;
    time_t nowMidnightEpoch = mktime(&nowMidnight);

    tm msgMidnight = _messageTm;
    msgMidnight.tm_hour = 0;
    msgMidnight.tm_min = 0;
    msgMidnight.tm_sec = 0;
    time_t msgMidnightEpoch = mktime(&msgMidnight);

    long daysDiff = (long)((nowMidnightEpoch - msgMidnightEpoch) / 86400);

    if (daysDiff <= 0) return "";
    if (daysDiff == 1) return "Yesterday";

    char buffer[20];
    sprintf(buffer, "%02d:%02d %02d.%02d.", _messageTm.tm_hour, _messageTm.tm_min, _messageTm.tm_mday, _messageTm.tm_mon + 1);
    return String(buffer);
}

const uint8_t* DisplayManager::selectWeatherIcon() const {
    int code = _weatherCode;
    bool isDay = _weatherIsDay;
    bool windy = _weatherWindy;

    if (code >= 95) {
        return ICON_THUNDERSTORM;
    }
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
        return ICON_WEATHER_SNOWY;
    }
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
        return ICON_RAINY;
    }
    if (code == 45 || code == 48) {
        return ICON_MIST;
    }
    if (windy && code <= 3) {
        return ICON_AIR;
    }
    if (code == 0) {
        return isDay ? ICON_CLEAR_DAY : ICON_MOON_STARS;
    }
    if (code == 1 || code == 2) {
        return isDay ? ICON_PARTLY_CLOUDY_DAY : ICON_PARTLY_CLOUDY_NIGHT;
    }
    return ICON_CLOUD;
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

const uint8_t* DisplayManager::locationIconBitmap() const {
    return _locationStale ? ICON_LOCATION_OFF : ICON_LOCATION_ON;
}