#include <HardwareSerial.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <Update.h>
#include <ArduinoJson.h>
#include <ctime>
#include "update.hpp"

UpdateManager::UpdateManager(const String& buildVersion, const String& channelIn, const int& checkUpdateHour) {
    channel = channelIn;
    updateHour = checkUpdateHour;
    appliedVersion = loadAppliedVersion(buildVersion);
    Serial.println("OTA channel: " + channel + " | Applied version: " + appliedVersion);
}

String UpdateManager::loadAppliedVersion(const String& buildVersion) {
    preferences.begin("kyndora", true);
    String stored = preferences.getString("fw_applied", "");
    preferences.end();

    if (stored.length() == 0) {
        saveAppliedVersion(buildVersion);
        return buildVersion;
    }
    return stored;
}

void UpdateManager::saveAppliedVersion(const String& version) {
    preferences.begin("kyndora", false);
    preferences.putString("fw_applied", version);
    preferences.end();
    appliedVersion = version;
}

bool UpdateManager::isWiFiConnected() {
    return (WiFiClass::status() == WL_CONNECTED);
}

void UpdateManager::automaticCheckForUpdates() {
    tm timeInfo{};
    if (!getLocalTime(&timeInfo)) return;

    if (timeInfo.tm_hour >= updateHour) {
        if (lastCheckDay != timeInfo.tm_mday) {
            lastCheckDay = timeInfo.tm_mday;
            Serial.println("Update time reached.");
            Serial.printf("Using channel: %s \n", channel.c_str());
            checkForUpdates();
        }
    }
}

String UpdateManager::buildApiUrl() const {
    const String base = "https://api.github.com/repos/LarsEsDoch/kyndora/releases";
    if (channel == "stable") {
        return base + "/latest";
    }
    return base + "/tags/" + channel;
}

void UpdateManager::checkForUpdates() {
    if (!isWiFiConnected()) {
        Serial.println("Update error: No Wi-Fi connection.");
        updateError = true;
        return;
    }

    Serial.println("Checking for new updates on channel '" + channel + "'...");

    WiFiClientSecure client;
    client.setInsecure();

    HTTPClient http;
    http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);

    const String apiUrl = buildApiUrl();

    if (!http.begin(client, apiUrl)) {
        updateError = true;
        return;
    }

    http.addHeader("User-Agent", "KYNDORA-OTA-Client");
    const int httpCode = http.GET();

    if (httpCode != HTTP_CODE_OK) {
        Serial.printf("Error retrieving API %s, HTTP code: %d\n", apiUrl.c_str(), httpCode);
        updateError = true;
        http.end();
        return;
    }

    updateError = false;
    const String payload = http.getString();
    http.end();

    JsonDocument doc;
    if (deserializeJson(doc, payload)) {
        Serial.println("Update error: failed to parse release JSON.");
        updateError = true;
        return;
    }

    const String tagName = doc["tag_name"].as<String>();
    JsonArray assets = doc["assets"].as<JsonArray>();

    String firmwareUrl;
    String assetUpdatedAt;
    for (JsonObject asset : assets) {
        String name = asset["name"].as<String>();
        if (name.endsWith("firmware.bin")) {
            firmwareUrl = asset["browser_download_url"].as<String>();
            assetUpdatedAt = asset["updated_at"].as<String>();
            break;
        }
    }

    if (firmwareUrl.length() == 0) {
        Serial.println("Update error: no firmware.bin asset found in release.");
        updateError = true;
        return;
    }

    const String remoteVersion = (channel == "stable")
        ? tagName
        : tagName + "@" + assetUpdatedAt;

    Serial.println("Applied Version: " + appliedVersion);
    Serial.println("Remote Version:  " + remoteVersion);

    String localVersion = appliedVersion;

    if (remoteVersion != localVersion) {
        Serial.println("New version found! Downloading...");
        downloadUrl = firmwareUrl;
        executeOTA(remoteVersion);
        if (!updateError) {
            saveAppliedVersion(remoteVersion);
        }
    } else {
        Serial.println("The firmware is up to date.");
    }
}

void UpdateManager::executeOTA(const String& newVersion) {
    if (downloadUrl.length() == 0) return;

    WiFiClientSecure downloadClient;
    downloadClient.setInsecure();

    HTTPClient http;
    http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);

    Serial.println("Starting firmware download...");

    if (!http.begin(downloadClient, downloadUrl)) {
        updateError = true;
        return;
    }

    http.addHeader("User-Agent", "ESP32-OTA-Client");
    const int httpCode = http.GET();

    if (httpCode != HTTP_CODE_OK) {
        Serial.printf("Download failed, HTTP code: %d\n", httpCode);
        updateError = true;
        http.end();
        return;
    }

    const int contentLength = http.getSize();
    Serial.printf("File size: %d Bytes\n", contentLength);

    if (!Update.begin(contentLength)) {
        Serial.println("Not enough space in the flash memory for the update.");
        updateError = true;
        http.end();
        return;
    }

    Serial.println("Flashing started. Please do not turn off the box...");
    WiFiClient& stream = http.getStream();
    const size_t written = Update.writeStream(stream);

    if (written != contentLength) {
        Serial.println("Written only: " + String(written) + "/" + String(contentLength) + ". Flash aborted.");
        updateError = true;
    }

    if (Update.end() && !updateError && Update.isFinished()) {
        downloadUrl = "";
        saveAppliedVersion(newVersion);
        Serial.println("Update complete. Restarting...");
        delay(1000);
        ESP.restart();
    } else {
        Serial.printf("An error occurred: #%d\n", Update.getError());
        updateError = true;
    }

    http.end();
}