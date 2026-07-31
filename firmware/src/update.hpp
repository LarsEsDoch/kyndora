#pragma once

class UpdateManager {
public:
    explicit UpdateManager(const String& version, const int& checkUpdateHour);

    void automaticCheckForUpdates();

    void checkForUpdates();

    void executeOTA();

    bool hasUpdateError() const { return updateError; }
private:
    int updateHour;

    int lastCheckDay = -1;

    String currentVersion;

    String downloadUrl;

    bool updateError = false;

    static bool isWiFiConnected();
};