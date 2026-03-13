#include <Arduino.h>
#include <WiFi.h>

// Pins für dein Board (müssen wir später anpassen)
#define STATUS_LED 2

void setup() {
    // Seriellen Monitor starten (wichtig für Debugging!)
    Serial.begin(115200);
    pinMode(STATUS_LED, OUTPUT);

    Serial.println("Connect-Box wird gestartet...");
    // Hier würde später das WiFi-Setup und JWT-Check stehen
}

void loop() {
    // Ein simpler Herzschlag-Monitor im Code
    digitalWrite(STATUS_LED, HIGH);
    Serial.println("System Status: OK (Heartbeat gesendet)");
    delay(1000);

    digitalWrite(STATUS_LED, LOW);
    delay(4000); // Alle 5 Sekunden blinken
}