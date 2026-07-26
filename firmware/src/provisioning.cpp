#include "provisioning.hpp"

#include <WiFiClient.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <ArduinoJson.h>

Preferences preferences;

void ProvisioningManager::exchangeTicketForCredentials(const String& macAddress, const String& ticketToken) {
    if (WiFiClass::status() != WL_CONNECTED) {
        Serial.println("Error: Not connected to Wi-Fi");
        return;
    }

    WiFiClient client;
    HTTPClient http;
    const String apiUrl = "http://192.168.178.33:8000/api/device/register";

    if (http.begin(client, apiUrl)) {
        http.addHeader("Content-Type", "application/json");

        const String requestBody = R"({"mac_address":")" + macAddress + R"(","ticket_token":")" + ticketToken + "\"}";

        const int httpCode = http.POST(requestBody);

        if (httpCode == 200) {
            String payload = http.getString();

            JsonDocument doc;
            deserializeJson(doc, payload);
            
            const char* deviceJwt = doc["device_jwt"];
            const char* mqttUser = doc["mqtt_username"];
            const char* mqttPass = doc["mqtt_password"];

            preferences.begin("kyndora", false);
            preferences.putString("device_jwt", deviceJwt);
            preferences.putString("mqtt_user", mqttUser);
            preferences.putString("mqtt_pass", mqttPass);
            preferences.end();

            Serial.println("Provisioning successful! Credentials saved to NVS.");
        } else {
            Serial.printf("Provisioning failed. HTTP Code: %d\n", httpCode);
            Serial.println(http.getString());
        }
        http.end();
    }
}