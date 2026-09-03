# Kyndora

**Kyndora** is a connected device system that helps two people stay emotionally close across distance. A physical E-Ink display device sits with one partner ("at home"), while a companion mobile app lets the other partner ("away") share their mood, send messages, draw doodles, and let their return time count down, all visible on the device.

The project consists of a custom ESP32-S3 firmware, a FastAPI backend, an MQTT broker for real-time device communication, and a single Flutter app used by both partners.

---

## Table of Contents

- [Concept](#concept)
- [System Architecture](#system-architecture)
- [Hardware](#hardware)
- [Repository Structure](#repository-structure)
- [Features](#features)
  - [On the Device (E-Ink Display)](#on-the-device-e-ink-display)
  - [Mobile App](#mobile-app)
  - [Backend](#backend)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
  - [Backend & Infrastructure](#backend--infrastructure)
  - [Firmware](#firmware)
  - [Mobile App](#mobile-app-1)
- [Device Provisioning Flow](#device-provisioning-flow)
- [CI/CD](#cicd)
- [Roadmap](#roadmap)
- [License](#license)

---

## Concept

Kyndora is built for couples, families, or friends who are temporarily apart. One person owns the **device**, a small E-Ink display box that sits on a desk or nightstand and passively shows information about their partner: current mood, a daily message, a hand-drawn doodle, the partner's local weather, and a countdown until they return.

The other person carries only the **app**. From anywhere, they can:

- Set their current mood and sleep status
- Send a message or draw a doodle for the day
- Set (or update) their return date/time
- Send an instant "Miss You" ping that lights up the LEDs on the partner's device
- Share their live location and timezone so the device always shows the correct weather and time

Both roles share the same app, the app simply adapts depending on whether a device is registered to the account or not.

## System Architecture

```
┌──────────────────┐        MQTT (WSS)        ┌───────────────────┐
│   ESP32-S3       │◄────────────────────────►│  Mosquitto Broker │
│   Kyndora Device │                          │  (mosquitto-go-   │
│  (E-Ink + LEDs)  │        HTTPS (REST)      │   auth backend)   │
└────────┬─────────┘◄─────────────────────────┴───────────┬───────┘
         │                                                │
         │                                        HTTP auth/ACL
         │                                                │
         ▼                                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                        FastAPI Backend                          │
│  Auth (JWT) · Devices · Partners · Feed · Push · WebSocket      │
│  Weather worker · Timezone resolver · MQTT worker               │
└───────────┬────────────────────────────────────────┬────────────┘
            │                                        │
            ▼                                        ▼
     ┌─────────────┐                          ┌──────────────────┐
     │ PostgreSQL  │                          │  Flutter Mobile  │
     │  (SQLModel) │                          │  App (Android /  │
     └─────────────┘                          │  iOS PWA)        │
                                              └──────────────────┘
```

- The **device** communicates exclusively over MQTT for low-latency, device-only events (commands, status, telemetry) and falls back to plain HTTPS requests for content that doesn't fit an MQTT payload well (e.g. fetching the latest feed item).
- The **app** communicates with the backend over HTTPS for all actions and keeps a **WebSocket** connection open for real-time, user-facing events (partner requests, status changes, new feed items).
- **Push notifications** (Firebase Cloud Messaging for Android, Web Push/VAPID for the iOS PWA) ensure the app owner is notified even when the app isn't open.

## Hardware

| Component | Purpose |
|---|---|
| ESP32-S3 (DevKitC-1-N16R8) | Main microcontroller, WiFi + BLE |
| Waveshare 4.2" E-Paper Display | Primary display (GxEPD2, black/white, partial + full refresh) |
| SK6812 (WS2812B-compatible) LED strip | Ambient/indirect lighting, animations |
| BH1750 digital light sensor | Adaptive LED brightness based on ambient light |
| 4× physical buttons | Miss You, Power/Reset, Next, Previous |
| USB-C panel-mount connector | Power |

Pin mapping and full hardware notes live alongside the firmware source.

## Repository Structure

```
kyndora/
├── firmware/           # ESP32-S3 firmware (PlatformIO, C++/Arduino)
│   ├── include/         # Headers, fonts, icon assets
│   └── src/              # Managers: Display, MQTT, Light, Button, Update, Provisioning
├── backend/            # FastAPI backend (Python)
│   ├── routers/          # auth, device, partners, feed, mqtt, push, users, ws
│   ├── services/         # MQTT worker, weather worker, push, timezone
│   └── tests/            # pytest test suite
├── mobile_app/         # Flutter app (Android + iOS PWA)
│   └── lib/
│       ├── screens/      # Auth, provisioning, device detail, main layout
│       ├── tabs/          # Feed, Devices, Partner
│       └── services/     # Realtime (WebSocket), push, location
├── infrastructure/     # docker-compose, Mosquitto config
├── tools/              # Icon conversion pipeline (PNG → PROGMEM header)
└── .github/workflows/  # CI/CD for backend, firmware, and app
```

## Features

### On the Device (E-Ink Display)

The display is divided into fixed rows, each independently partial-refreshed to minimize flicker and E-Ink wear, with a full refresh every 20 partial updates and once per day:

- **Top bar**, freshness timestamp of the last message + WiFi signal / status icon
- **Time**, large, centered, NTP-synced and timezone-aware
- **Weather**, partner's current local weather icon + temperature (auto-selected icon based on weather code, day/night, and wind)
- **Daily message**, the partner's message for the day
- **Doodle**, the partner's hand-drawn daily doodle, rendered from an 80×80px 1-bit bitmap
- **Countdown**, live countdown until the partner's set return date/time
- **Location**, a short location label with a "stale" indicator if location data hasn't updated recently

Device-side logic includes:

- **LED lighting** with ambient-light-adaptive brightness (BH1750) and a "Miss You" sweep animation
- **Physical buttons** for sending an instant Miss You ping, plus day navigation
- **OTA firmware updates** over GitHub Releases, with support for a `stable` channel and a rolling `beta` channel
- **BLE provisioning** for zero-friction WiFi + account setup, entirely driven from the app
- **NVS-backed persistence** so return time, applied firmware version, timezone, and WiFi credentials survive reboots

### Mobile App

A single Flutter codebase serves both roles:

- **Feed tab**, view messages and doodles sent between partners
- **Devices tab**, list, add (via BLE provisioning), and configure owned devices; per-device settings for display elements, LED brightness/adaptive brightness/night mode, auto-update schedule, and device actions (restart, WiFi reset, cache clear, factory reset)
- **Partner tab**, add a partner by username, send/accept/decline partner requests, send messages, draw and send doodles, set return time, configure timezone (auto-detect via GPS or manual), log mood/sleep status, manage a rotating list of morning quotes, and send an instant "Miss You"
- **Real-time updates** via WebSocket with automatic exponential-backoff reconnection
- **Push notifications**, FCM on Android, Web Push (VAPID) on the installable iOS PWA
- **Background location updates** to keep the partner's weather and timezone accurate

### Backend

- **Auth**, Argon2 password hashing, JWT bearer tokens
- **Partner system**, request/accept/decline flow with real-time and push notifications
- **Device management**, provisioning tickets, per-device settings, telemetry, remote commands
- **MQTT integration**, a background worker consumes device status/heartbeat/telemetry/button events and updates the database; outbound commands are published to device-specific topics (`kyndora/<deviceId>/<topic>`)
- **Weather worker**, polls Open-Meteo every 15 minutes for each user's partner location and pushes updates to the device via MQTT
- **Timezone resolution**, automatic IANA timezone lookup from GPS coordinates, converted to POSIX TZ strings and pushed to the device
- **WebSocket hub**, per-user connection manager for real-time app events
- **Push service**, unified interface over Firebase Admin SDK (FCM) and `pywebpush` (Web Push)
- **Firmware proxy**, exposes a stable `/api/firmware/check` endpoint that resolves the latest GitHub Release asset per channel

## Tech Stack

**Firmware**
ESP32-S3 · PlatformIO · Arduino framework · GxEPD2 · ArduinoJson · PsychicMqttClient (WSS) · FastLED · BH1750 · Preferences (NVS) · BLE

**Backend**
Python · FastAPI · SQLModel · PostgreSQL · JWT (PyJWT) · Argon2 · Eclipse Mosquitto (mosquitto-go-auth, SSL) · firebase-admin · pywebpush · timezonefinder · Open-Meteo API

**Mobile**
Flutter/Dart · Firebase Cloud Messaging · Web Push/VAPID · flutter_blue_plus · geolocator · web_socket_channel

**Infrastructure**
Docker Compose · GitHub Actions (CI/CD) · GitHub Releases (OTA distribution) · GitHub Pages (iOS PWA hosting)

## Getting Started

### Backend & Infrastructure

```bash
cd infrastructure
docker compose up -d          # starts PostgreSQL and the Mosquitto broker
```

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # configure DB_USER, DB_PASSWORD, JWT_SECRET, MQTT_PASSWORD, etc.
uvicorn main:app --reload
```

Run the test suite:

```bash
pytest
```

### Firmware

```bash
cd firmware
pio run                        # build
pio run -t upload              # flash to an ESP32-S3
```

The build expects an `FW_VERSION` environment variable (set automatically in CI); locally it falls back to `dev-local`.

### Mobile App

```bash
cd mobile_app
flutter pub get
flutter run                    # or: flutter build apk / flutter build web
```

## Device Provisioning Flow

1. The app requests a short-lived provisioning ticket from the backend (`POST /api/device/ticket`), scoped to the logged-in user.
2. The app connects to the device over BLE (advertised as `Kyndora-Setup`) and writes the WiFi SSID, WiFi password, and the provisioning ticket to dedicated GATT characteristics.
3. The device connects to WiFi and calls `POST /api/device/register` with its MAC address and the ticket.
4. The backend validates the ticket, creates (or reassigns) the device record, and returns a permanent device JWT plus MQTT credentials.
5. The device persists these credentials in NVS flash and connects to the MQTT broker over WSS from then on.

## CI/CD

Each part of the monorepo has its own GitHub Actions workflow, triggered on changes to its respective path:

- **`backend.yml`**, lint (ruff), test (pytest), build & push a Docker image to GHCR
- **`firmware.yml`**, build via PlatformIO, publish binaries to a rolling `beta` GitHub Release and to tagged releases
- **`app.yml`**, analyze, test, build Android APK and Flutter Web, deploy the iOS PWA to GitHub Pages, and publish artifacts to GitHub Releases

## Roadmap

- [ ] Tamagotchi-style mood/sleep visualization on the device display
- [ ] Certificate-pinned OTA downloads (replacing `setInsecure()`)
- [ ] LED behavior polish (night mode transitions, do-not-disturb mode)
- [ ] Device-side history browsing (past doodles, moods, locations)
- [ ] Special-event theming for the display

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
