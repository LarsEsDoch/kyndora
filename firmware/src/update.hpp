#pragma once
#include <Arduino.h>
#include <Preferences.h>

class UpdateManager {
public:
    explicit UpdateManager(const String& buildVersion, const String& channel, const int& checkUpdateHour);

    void begin();
    void automaticCheckForUpdates();
    void checkForUpdates();
    void executeOTA(const String& newVersion);

    bool hasUpdateError() const { return updateError; }

private:
    int updateHour;
    int lastCheckDay = -1;

    String channel;
    String appliedVersion;
    String initialBuildVersion;
    String downloadUrl;

    bool updateError = false;

    Preferences preferences;

    String buildApiUrl() const;
    String loadAppliedVersion(const String& buildVersion);
    void saveAppliedVersion(const String& version);

    static bool isWiFiConnected();
};