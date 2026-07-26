#pragma once
#include <Arduino.h>
#include <Preferences.h>
#include <WiFi.h>

class MyCallbacks;
class ProvisioningManager {

    friend class MyCallbacks;
public:
    static void begin();

    static void handle();

    static bool isProvisioned();

    static void reset();

    static String getSavedSSID();
    static String getSavedPassword();
    static String getSavedJWT();

    static void setReceivedData(String ssid, String pass, String token);

private:
    static void startBLEServer();
    static void stopBLEServer();
    static void connectToWiFi();
    static void exchangeTicketForCredentials();

    static Preferences preferences;

    static String tempSSID;
    static String tempPassword;
    static String tempToken;
    static bool dataReceivedReady;

    static bool provisionedState;
    static bool stateChecked;
};