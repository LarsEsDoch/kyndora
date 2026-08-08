import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String token;
  final String macAddress;
  final String deviceName;

  const DeviceDetailScreen({
    super.key,
    required this.token,
    required this.macAddress,
    required this.deviceName,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  bool _isLoading = true;

  bool _showDateIfNotToday = true;
  bool _showWiFi = true;
  bool _showTime = true;
  bool _showWeather = true;
  bool _showSunriseSunset = true;
  bool _showDailyMessage = true;
  bool _showTamagotchi = true;
  bool _showDoodle = true;
  bool _showCountdown = true;
  bool _showLiveLocation = true;

  bool _autoUpdate = true;
  TimeOfDay _updateTime = const TimeOfDay(hour: 3, minute: 0);
  String _firmwareVersion = "1.0.4";
  String _currentWiFi = "HomeNetwork_5G";
  String _WiFiStrength = "Perfect";
  String _uptime = "20 Days, 5 Hours and 3 Minutes";
  String _temperature = "26.3°C";
  String _lastSeen = "23.05.2025 at 18:50";

  bool _ledEnabled = true;
  double _ledBrightness = 80.0;
  bool _adaptiveBrightness = true;
  bool _nightMode = false;
  double _nightBrightness = 10.0;

  @override
  void initState() {
    super.initState();
    _fetchDeviceSettings();
  }

  Future<void> _fetchDeviceSettings() async {
    try {
      //FETCH: http.get('$backendUrl/api/device/${widget.macAddress}/settings')
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _syncSetting(String key, dynamic value) {
    //POST: http.post('$backendUrl/api/device/${widget.macAddress}/settings', body: {key: value})
  }

  Future<void> _executeCommand(String command) async {
    try {
      //POST: http.post('$backendUrl/api/device/${widget.macAddress}/command?command=$command')
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Command "$command" sent.')));
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.deviceName} Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          ExpansionTile(
            leading: const Icon(Icons.dashboard),
            title: const Text("Display Elements"),
            children: [
              SwitchListTile(title: const Text("Show Date (If not today)"), value: _showDateIfNotToday, onChanged: (v) { setState(() => _showDateIfNotToday = v); _syncSetting('show_date', v); }),
              SwitchListTile(title: const Text("Show WiFi Indicator"), value: _showWiFi, onChanged: (v) { setState(() => _showWiFi = v); _syncSetting('show_wifi', v); }),
              SwitchListTile(title: const Text("Show Time"), value: _showTime, onChanged: (v) { setState(() => _showTime = v); _syncSetting('show_time', v); }),
              SwitchListTile(title: const Text("Show Weather & Temp"), value: _showWeather, onChanged: (v) { setState(() => _showWeather = v); _syncSetting('show_weather', v); }),
              SwitchListTile(title: const Text("Show Sunrise/Sunset (30 min)"), value: _showSunriseSunset, onChanged: (v) { setState(() => _showSunriseSunset = v); _syncSetting('show_sunrise', v); }),
              SwitchListTile(title: const Text("Show Daily Message"), value: _showDailyMessage, onChanged: (v) { setState(() => _showDailyMessage = v); _syncSetting('show_message', v); }),
              SwitchListTile(title: const Text("Show Tamagotchi (Mood/Sleep)"), value: _showTamagotchi, onChanged: (v) { setState(() => _showTamagotchi = v); _syncSetting('show_tamagotchi', v); }),
              SwitchListTile(title: const Text("Show Daily Doodle"), value: _showDoodle, onChanged: (v) { setState(() => _showDoodle = v); _syncSetting('show_doodle', v); }),
              SwitchListTile(title: const Text("Show Countdown"), value: _showCountdown, onChanged: (v) { setState(() => _showCountdown = v); _syncSetting('show_countdown', v); }),
              SwitchListTile(title: const Text("Show Live Location"), value: _showLiveLocation, onChanged: (v) { setState(() => _showLiveLocation = v); _syncSetting('show_location', v); }),
            ],
          ),
          ExpansionTile(
            leading: const Icon(Icons.lightbulb),
            title: const Text("LED Strip Configuration"),
            children: [
              SwitchListTile(title: const Text("Enable LEDs"), value: _ledEnabled, onChanged: (v) { setState(() => _ledEnabled = v); _syncSetting('led_enabled', v); }),
              SwitchListTile(title: const Text("Adaptive Brightness"), value: _adaptiveBrightness, onChanged: (v) { setState(() => _adaptiveBrightness = v); _syncSetting('adaptive_brightness', v); }),
              ListTile(
                title: const Text("LED Brightness"),
                subtitle: Slider(value: _ledBrightness, min: 0, max: 100, divisions: 100, label: "${_ledBrightness.round()}%", onChanged: _ledEnabled && !_adaptiveBrightness ? (v) { setState(() => _ledBrightness = v); } : null, onChangeEnd: (v) => _syncSetting('led_brightness', v)),
              ),
              const Divider(),
              SwitchListTile(title: const Text("Night Mode"), value: _nightMode, onChanged: (v) { setState(() => _nightMode = v); _syncSetting('night_mode', v); }),
              ListTile(
                title: const Text("Night Brightness"),
                subtitle: Slider(value: _nightBrightness, min: 0, max: 50, divisions: 50, label: "${_nightBrightness.round()}%", onChanged: _nightMode ? (v) { setState(() => _nightBrightness = v); } : null, onChangeEnd: (v) => _syncSetting('night_brightness', v)),
              ),
            ],
          ),
          ExpansionTile(
            leading: const Icon(Icons.system_update),
            title: const Text("Firmware & Updates"),
            children: [
              ListTile(title: const Text("Current Firmware Version"), trailing: Text(_firmwareVersion)),
              SwitchListTile(title: const Text("Automatic Updates"), value: _autoUpdate, onChanged: (v) { setState(() => _autoUpdate = v); _syncSetting('auto_update', v); }),
              ListTile(
                title: const Text("Update Schedule"),
                trailing: Text(_updateTime.format(context)),
                onTap: () async {
                  final time = await showTimePicker(context: context, initialTime: _updateTime);
                  if (time != null) {
                    setState(() => _updateTime = time);
                    _syncSetting('update_time', "${time.hour}:${time.minute}");
                  }
                },
              ),
            ],
          ),
          ExpansionTile(
            leading: const Icon(Icons.wifi),
            title: const Text("Network & System Actions"),
            children: [
              ListTile(title: const Text("Last Seen"), trailing: Text(_lastSeen)),
              ListTile(title: const Text("Connected WiFi"), trailing: Text(_currentWiFi)),
              ListTile(title: const Text("Wifi Strength"), trailing: Text(_WiFiStrength)),
              ListTile(title: const Text("Uptime"), trailing: Text(_uptime)),
              ListTile(title: const Text("Temperature"), trailing: Text(_temperature)),
              ListTile(
                leading: const Icon(Icons.wifi_off, color: Colors.orange),
                title: const Text("Reset WiFi Configuration"),
                onTap: () => _executeCommand('reset_wifi'),
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services, color: Colors.orange),
                title: const Text("Clear Device Cache"),
                onTap: () => _executeCommand('clear_cache'),
              ),
              ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: const Text("Factory Reset", style: TextStyle(color: Colors.red)),
                onTap: () => _executeCommand('factory_reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}