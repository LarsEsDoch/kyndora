#include <HardwareSerial.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <Update.h>
#include <ctime>
#include "update.hpp"

UpdateManager::UpdateManager(const String& version, const int& checkUpdateHour) {
    currentVersion = version;
    updateHour = checkUpdateHour;
}

bool UpdateManager::isWiFiConnected() {
    return (WiFi.status() == WL_CONNECTED);
}

void UpdateManager::automaticCheckForUpdates() {
}

void UpdateManager::checkForUpdates() {
}

void UpdateManager::executeOTA() {
}
