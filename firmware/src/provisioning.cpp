#include "provisioning.hpp"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

#define SERVICE_UUID           "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_UUID_SSID         "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define CHAR_UUID_PASS         "beb5483f-36e1-4688-b7f5-ea07361b26a8"
#define CHAR_UUID_TOKEN        "beb54840-36e1-4688-b7f5-ea07361b26a8"

Preferences ProvisioningManager::preferences;
String ProvisioningManager::tempSSID = "";
String ProvisioningManager::tempPassword = "";
String ProvisioningManager::tempToken = "";
bool ProvisioningManager::dataReceivedReady = false;

bool ProvisioningManager::provisionedState = false;
bool ProvisioningManager::stateChecked = false;

BLEServer* pServer = nullptr;

class MyCallbacks : public BLECharacteristicCallbacks {
public:
    void onWrite(BLECharacteristic *pCharacteristic) {
        String value = pCharacteristic->getValue().c_str();
        if (value.length() > 0) {
            String uuid = pCharacteristic->getUUID().toString().c_str();

            if (uuid == CHAR_UUID_SSID) ProvisioningManager::tempSSID = value;
            if (uuid == CHAR_UUID_PASS) ProvisioningManager::tempPassword = value;
            if (uuid == CHAR_UUID_TOKEN) ProvisioningManager::tempToken = value;

            Serial.println("BLE Received Data for UUID: " + uuid);

            if (ProvisioningManager::tempSSID != "" &&
                ProvisioningManager::tempPassword != "" &&
                ProvisioningManager::tempToken != "") {
                ProvisioningManager::setReceivedData(ProvisioningManager::tempSSID, ProvisioningManager::tempPassword, ProvisioningManager::tempToken);
            }
        }
    }
};

void ProvisioningManager::setReceivedData(String ssid, String pass, String token) {
    dataReceivedReady = true;
    Serial.println("All provisioning data received via BLE!");
}

bool ProvisioningManager::isProvisioned() {
    if (stateChecked) return provisionedState;

    preferences.begin("kyndora", false);
    String jwt = preferences.getString("device_jwt", "");
    preferences.end();

    provisionedState = (jwt != "");
    stateChecked = true;

    return provisionedState;
}

String ProvisioningManager::getSavedSSID() {
    preferences.begin("kyndora", true);
    String val = preferences.getString("wifi_ssid", "");
    preferences.end();
    return val;
}

String ProvisioningManager::getSavedPassword() {
    preferences.begin("kyndora", true);
    String val = preferences.getString("wifi_pass", "");
    preferences.end();
    return val;
}

String ProvisioningManager::getSavedJWT() {
    preferences.begin("kyndora", true);
    String val = preferences.getString("device_jwt", "");
    preferences.end();
    return val;
}

void ProvisioningManager::reset() {
    preferences.begin("kyndora", false);
    preferences.clear();
    preferences.end();
    Serial.println("NVS cleared. Rebooting...");
    delay(1000);
    ESP.restart();
}

void ProvisioningManager::begin() {
    if (!isProvisioned()) {
        Serial.println("Device not provisioned. Starting BLE Setup Mode...");
        startBLEServer();
    } else {
        Serial.println("Device already provisioned. Proceeding to connect WiFi...");
        connectToWiFi();
    }
}

void ProvisioningManager::startBLEServer() {
    BLEDevice::init("Kyndora-Setup");
    pServer = BLEDevice::createServer();

    BLEService *pService = pServer->createService(SERVICE_UUID);

    BLECharacteristic *pCharSSID = pService->createCharacteristic(CHAR_UUID_SSID, BLECharacteristic::PROPERTY_WRITE);
    pCharSSID->setCallbacks(new MyCallbacks());

    BLECharacteristic *pCharPass = pService->createCharacteristic(CHAR_UUID_PASS, BLECharacteristic::PROPERTY_WRITE);
    pCharPass->setCallbacks(new MyCallbacks());

    BLECharacteristic *pCharToken = pService->createCharacteristic(CHAR_UUID_TOKEN, BLECharacteristic::PROPERTY_WRITE);
    pCharToken->setCallbacks(new MyCallbacks());

    pService->start();
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    BLEDevice::startAdvertising();

    Serial.println("BLE Server started. Waiting for Flutter App...");
}

void ProvisioningManager::stopBLEServer() {
    BLEDevice::deinit(true);
    Serial.println("BLE stopped to save power and memory.");
}

void ProvisioningManager::handle() {
    if (dataReceivedReady) {
        dataReceivedReady = false;

        stopBLEServer();
        delay(500);

        WiFi.begin(tempSSID.c_str(), tempPassword.c_str());
        Serial.print("Connecting to new Wi-Fi");

        int attempts = 0;
        while (WiFi.status() != WL_CONNECTED && attempts < 30) {
            delay(500);
            Serial.print(".");
            attempts++;
        }

        if (WiFi.status() == WL_CONNECTED) {
            Serial.println("\nWi-Fi connected!");
            exchangeTicketForCredentials();
        } else {
            Serial.println("\nFailed to connect to Wi-Fi. Restarting BLE...");
            startBLEServer();
        }
    }
}

void ProvisioningManager::connectToWiFi() {
    String ssid = getSavedSSID();
    String pass = getSavedPassword();

    WiFi.begin(ssid.c_str(), pass.c_str());
    Serial.print("Connecting to saved Wi-Fi");
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("\nWi-Fi connected!");
}

void ProvisioningManager::exchangeTicketForCredentials() {
    HTTPClient http;
    String apiUrl = "http://192.168.178.100:8000/api/device/register";

    if (http.begin(apiUrl)) {
        http.addHeader("Content-Type", "application/json");

        String mac = WiFi.macAddress();
        String requestBody = "{\"mac_address\":\"" + mac + "\",\"ticket_token\":\"" + tempToken + "\"}";

        int httpCode = http.POST(requestBody);

        if (httpCode == 200) {
            String payload = http.getString();

            JsonDocument doc;
            deserializeJson(doc, payload);

            const char* deviceJwt = doc["device_jwt"];
            const char* mqttUser = doc["mqtt_username"];
            const char* mqttPass = doc["mqtt_password"];

            preferences.begin("kyndora", false);
            preferences.putString("wifi_ssid", tempSSID);
            preferences.putString("wifi_pass", tempPassword);
            preferences.putString("device_jwt", deviceJwt);
            preferences.putString("mqtt_user", mqttUser);
            preferences.putString("mqtt_pass", mqttPass);
            preferences.end();

            Serial.println("Provisioning successful! Restarting to apply settings...");
            delay(1000);
            ESP.restart();
        } else {
            Serial.printf("Provisioning failed. HTTP Code: %d\n", httpCode);
            Serial.println(http.getString());
            WiFi.disconnect();
            startBLEServer();
        }
        http.end();
    }
}