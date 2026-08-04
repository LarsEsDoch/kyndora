#pragma once
#include <Arduino.h>
#include <GxEPD2_BW.h>
#include <ctime>
#include "gdey/GxEPD2_420_GDEY042T81.h"
class DisplayManager {
public:
    DisplayManager(int8_t cs, int8_t dc, int8_t rst, int8_t busy);

    void begin();
private:
    GxEPD2_BW<GxEPD2_420_GDEY042T81, GxEPD2_420_GDEY042T81::HEIGHT> _display;

