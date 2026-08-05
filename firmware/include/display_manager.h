#pragma once
#include <Arduino.h>
#include <GxEPD2_BW.h>
#include <ctime>
#include "gdey/GxEPD2_420_GDEY042T81.h"

enum WifiIconState {
    WIFI_ICON_NOT_SETUP,
    WIFI_ICON_NOT_CONNECTED,
    WIFI_ICON_ALERT,
    WIFI_ICON_STRENGTH_1,
    WIFI_ICON_STRENGTH_2,
    WIFI_ICON_STRENGTH_3,
    WIFI_ICON_STRENGTH_4
};

class DisplayManager {
public:
    DisplayManager(int8_t cs, int8_t dc, int8_t rst, int8_t busy);

    void begin();
    void showSetupScreen();

    void setWifiState(WifiIconState state);
    void setTime(int hour, int minute);
    void setWeather(float temp, int code, bool isDay, bool windy);
    void setMessage(const String& text);
    void setDoodle(const String& hexString);
private:
    static constexpr int16_t TOP_BAR_Y = 0;
    static constexpr int16_t TOP_BAR_H = 34;

    static constexpr int16_t TIME_Y = 34;
    static constexpr int16_t TIME_H = 110;

    static constexpr int16_t WEATHER_Y = 144;
    static constexpr int16_t WEATHER_H = 50;

    static constexpr int16_t MESSAGE_Y = 194;
    static constexpr int16_t MESSAGE_H = 44;

    static constexpr int16_t IMAGES_Y = 238;
    static constexpr int16_t IMAGES_H = 90;

    static constexpr int16_t DOODLE_SIZE = 80;
    static constexpr int16_t WIFI_ICON_TARGET_SIZE = 24;

    static constexpr uint16_t FULL_REFRESH_THRESHOLD = 20;

    GxEPD2_BW<GxEPD2_420_GDEY042T81, GxEPD2_420_GDEY042T81::HEIGHT> _display;

    WifiIconState _wifiState = WIFI_ICON_NOT_SETUP;
    bool _wifiInitialized = false;

    bool _hasTime = false;
    int _hour = 0;
    int _minute = 0;

    uint16_t _partialUpdateCount = 0;

    void partialRefresh(int16_t y, int16_t h, void (DisplayManager::*paintFn)());
    void registerPartialUpdate();

    void updateTopBar();
    void updateTimeRow();
    void paintTopBar();
    void paintTime();
    const uint8_t* wifiIconBitmap() const;
    void drawIconBitmap(const uint8_t* bitmap, int16_t x, int16_t y, int16_t targetSize);
};