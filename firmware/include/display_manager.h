#pragma once
#include <Arduino.h>
#include <GxEPD2_BW.h>
#include <ctime>
#include "gdey/GxEPD2_420_GDEY042T81.h"
class DisplayManager {
public:
    DisplayManager(int8_t cs, int8_t dc, int8_t rst, int8_t busy);

    void begin();
    void setTime(int hour, int minute);
private:

    static constexpr int16_t TIME_Y = 34;
    static constexpr int16_t TIME_H = 110;


    static constexpr uint16_t FULL_REFRESH_THRESHOLD = 20;

    GxEPD2_BW<GxEPD2_420_GDEY042T81, GxEPD2_420_GDEY042T81::HEIGHT> _display;

    bool _hasTime = false;
    int _hour = 0;
    int _minute = 0;

    uint16_t _partialUpdateCount = 0;

    void partialRefresh(int16_t y, int16_t h, void (DisplayManager::*paintFn)());
    void registerPartialUpdate();

