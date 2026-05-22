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
    tm timeInfo{};
    if (!getLocalTime(&timeInfo)) {
        return;
    }

    if (timeInfo.tm_hour == updateHour && timeInfo.tm_min == 0) {
        if (lastCheckDay != timeInfo.tm_mday) {
            lastCheckDay = timeInfo.tm_mday;

            Serial.println("Update time reached.");
            checkForUpdates();
        }
    }
}

void UpdateManager::checkForUpdates() {
    if (!isWiFiConnected()) {
        Serial.println("Update error: No Wi-Fi connection.");
        return;
    }

    Serial.println("Checking for new updates...");

    WiFiClientSecure client;
    client.setInsecure();

    HTTPClient http;

    http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);

    const auto githubApiUrl = "https://api.github.com/repos/LarsEsDoch/kyndora/releases/latest";

    if (http.begin(client, githubApiUrl)) {
        http.addHeader("User-Agent", "KYNDORA-OTA-Client");

        int httpCode = http.GET();

        if (httpCode == HTTP_CODE_OK) {
            String payload = http.getString();

            int tagIndex = payload.indexOf("\"tag_name\":\"");
            if (tagIndex != -1) {
                int tagStart = tagIndex + 12;
                int tagEnd = payload.indexOf("\"", tagStart);
                String latestVersion = payload.substring(tagStart, tagEnd);

                Serial.println("Installed Version: " + currentVersion);
                Serial.println("Latest GitHub Version: " + latestVersion);

                if (latestVersion != currentVersion) {
                    Serial.println("New version found! Getting download link...");

                    const int urlIndex = payload.indexOf("\"browser_download_url\":\"");
                    if (urlIndex != -1) {
                        int urlStart = urlIndex + 24;
                        int urlEnd = payload.indexOf("\"", urlStart);
                        String url = payload.substring(urlStart, urlEnd);

                        Serial.println("Download URL: " + url);
                        downloadUrl = url;

                        executeOTA();
                    }
                } else {
                    Serial.println("The firmware is up to date.");
                }
            }
        } else {
            Serial.printf("Error retrieving API, HTTP code: %d\n", httpCode);
        }
        http.end();
    }
}

void UpdateManager::executeOTA() {
}
