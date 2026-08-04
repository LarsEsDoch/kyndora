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
