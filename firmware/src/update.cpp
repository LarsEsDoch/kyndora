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
    return (WiFiClass::status() == WL_CONNECTED);
}

void UpdateManager::automaticCheckForUpdates() {
    tm timeInfo{};
    if (!getLocalTime(&timeInfo)) {
        return;
    }

    if (timeInfo.tm_hour >= updateHour) {
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

        const int httpCode = http.GET();

        if (httpCode == HTTP_CODE_OK) {
            const String payload = http.getString();

            const int tagIndex = payload.indexOf(R"("tag_name":")");
            if (tagIndex != -1) {
                const int tagStart = tagIndex + 12;
                const int tagEnd = payload.indexOf("\"", tagStart);
                const String latestVersion = payload.substring(tagStart, tagEnd);

                Serial.println("Installed Version: " + currentVersion);
                Serial.println("Latest GitHub Version: " + latestVersion);

                if (latestVersion != currentVersion) {
                    Serial.println("New version found! Getting download link...");

                    const int urlIndex = payload.indexOf(R"("browser_download_url":")");
                    if (urlIndex != -1) {
                        const int urlStart = urlIndex + 24;
                        const int urlEnd = payload.indexOf("\"", urlStart);
                        const String url = payload.substring(urlStart, urlEnd);

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
    if (downloadUrl.length() == 0) return;

    WiFiClientSecure downloadClient;
    downloadClient.setInsecure();

    HTTPClient http;
    http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);

    Serial.println("Starting firmware download...");

    if (http.begin(downloadClient, downloadUrl)) {
        http.addHeader("User-Agent", "ESP32-OTA-Client");
        const int httpCode = http.GET();

        if (httpCode == HTTP_CODE_OK) {
            const int contentLength = http.getSize();
            Serial.printf("File size: %d Bytes\n", contentLength);

            if (Update.begin(contentLength)) {
                Serial.println("Flashing started. Please do not turn off the box...");

                // TODO: Hier kannst du später deine Display-Wartemeldung einblenden!

                WiFiClient& stream = http.getStream();

                const size_t written = Update.writeStream(stream);

                if (written == contentLength) {
                    Serial.println("Written: " + String(written) + " successfully");
                } else {
                    Serial.println("Written only: " + String(written) + "/" + String(contentLength) + ". Flash aborted.");
                }

                if (Update.end()) {
                    Serial.println("OTA successfully completed!");
                    if (Update.isFinished()) {
                        downloadUrl = "";
                        Serial.println("Update complete. Restarting...");
                        delay(1000);
                        ESP.restart();
                    } else {
                        Serial.println("Update not completed. Failed.");
                    }
                } else {
                    Serial.printf("An error occurred: #%d\n", Update.getError());
                }
            } else {
                Serial.println("Not enough space in the flash memory for the update.");
            }
        } else {
            Serial.printf("Download failed, HTTP code: %d\n", httpCode);
        }
        http.end();
    }
}