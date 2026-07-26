#pragma once
#include <Arduino.h>

class ProvisioningManager {
public:
    static void exchangeTicketForCredentials(const String& macAddress, const String& ticketToken);

    static String getSavedJWT();
    static String getSavedMqttUser();
};