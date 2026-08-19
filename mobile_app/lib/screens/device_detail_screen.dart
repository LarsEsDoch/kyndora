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

  String _firmwareVersion = "Unknown";
  String _status = "offline";
  String _lastSeen = "Never";
  int? _batteryLevel;
  String? _wifiSsid;
  int? _rssi;
  int? _uptimeSeconds;
  double? _coreTemp;

  bool _ledEnabled = true;
  double _ledBrightness = 80.0;
  bool _adaptiveBrightness = true;
  bool _nightMode = false;
  double _nightBrightness = 10.0;

  Map<String, String> get _authHeaders => {
    'Authorization': 'Bearer ${widget.token}',
    'Content-Type': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_fetchDeviceInfo(), _fetchDeviceSettings()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchDeviceInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/api/device/${widget.macAddress}'),
        headers: _authHeaders,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final telemetry = data['telemetry'] as Map<String, dynamic>? ?? {};
        setState(() {
          _status = data['status'] ?? 'offline';
          _lastSeen = data['last_seen'] ?? 'Never';
          _firmwareVersion = data['firmware_version'] ?? 'Unknown';
          _batteryLevel = data['battery_level'];
          _wifiSsid = telemetry['ssid'];
          _rssi = telemetry['rssi'];
          _uptimeSeconds = data['uptime_s'];
          _coreTemp = (telemetry['core_temp'] as num?)?.toDouble();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load device info: $e')));
      }
    }
  }

  Future<void> _fetchDeviceSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/api/device/${widget.macAddress}/settings'),
        headers: _authHeaders,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _showDateIfNotToday = data['show_date_if_not_today'] ?? true;
          _showWiFi = data['show_wifi'] ?? true;
          _showTime = data['show_time'] ?? true;
          _showWeather = data['show_weather'] ?? true;
          _showSunriseSunset = data['show_sunrise_sunset'] ?? true;
          _showDailyMessage = data['show_daily_message'] ?? true;
          _showTamagotchi = data['show_tamagotchi'] ?? true;
          _showDoodle = data['show_doodle'] ?? true;
          _showCountdown = data['show_countdown'] ?? true;
          _showLiveLocation = data['show_live_location'] ?? true;

          _ledEnabled = data['led_enabled'] ?? true;
          _ledBrightness = (data['led_brightness'] as num?)?.toDouble() ?? 80.0;
          _adaptiveBrightness = data['adaptive_brightness'] ?? true;
          _nightMode = data['night_mode'] ?? false;
          _nightBrightness = (data['night_brightness'] as num?)?.toDouble() ?? 10.0;

          _autoUpdate = data['auto_update'] ?? true;
          _updateTime = TimeOfDay(
            hour: data['update_hour'] ?? 3,
            minute: data['update_minute'] ?? 0,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load settings: $e')));
      }
    }
  }

  Future<void> _patchSettings(Map<String, dynamic> data) async {
    try {
      final response = await http.patch(
        Uri.parse('$backendUrl/api/device/${widget.macAddress}/settings'),
        headers: _authHeaders,
        body: jsonEncode(data),
      );
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save setting: $e')));
      }
    }
  }

  void _syncSetting(String key, dynamic value) {
    _patchSettings({key: value});
  }

  Future<void> _executeCommand(String command) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/device/${widget.macAddress}/command?command=$command'),
        headers: _authHeaders,
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Command "$command" sent.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Command failed (${response.statusCode}).')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Command error: $e')));
      }
    }
  }

  String _formatUptime(int? seconds) {
    if (seconds == null) return "Unknown";
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return "$days Days, $hours Hours and $minutes Minutes";
  }

  String _formatWifiStrength(int? rssi) {
    if (rssi == null) return "Unknown";
    if (rssi >= -60) return "Excellent";
    if (rssi >= -70) return "Good";
    if (rssi >= -80) return "Fair";
    return "Poor";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.deviceName} Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          children: [
            ExpansionTile(
              leading: const Icon(Icons.dashboard),
              title: const Text("Display Elements"),
              children: [
                SwitchListTile(title: const Text("Show Date (If not today)"), value: _showDateIfNotToday, onChanged: (v) { setState(() => _showDateIfNotToday = v); _syncSetting('show_date_if_not_today', v); }),
                SwitchListTile(title: const Text("Show WiFi Indicator"), value: _showWiFi, onChanged: (v) { setState(() => _showWiFi = v); _syncSetting('show_wifi', v); }),
                SwitchListTile(title: const Text("Show Time"), value: _showTime, onChanged: (v) { setState(() => _showTime = v); _syncSetting('show_time', v); }),
                SwitchListTile(title: const Text("Show Weather & Temp"), value: _showWeather, onChanged: (v) { setState(() => _showWeather = v); _syncSetting('show_weather', v); }),
                SwitchListTile(title: const Text("Show Sunrise/Sunset (30 min)"), value: _showSunriseSunset, onChanged: (v) { setState(() => _showSunriseSunset = v); _syncSetting('show_sunrise_sunset', v); }),
                SwitchListTile(title: const Text("Show Daily Message"), value: _showDailyMessage, onChanged: (v) { setState(() => _showDailyMessage = v); _syncSetting('show_daily_message', v); }),
                SwitchListTile(title: const Text("Show Tamagotchi (Mood/Sleep)"), value: _showTamagotchi, onChanged: (v) { setState(() => _showTamagotchi = v); _syncSetting('show_tamagotchi', v); }),
                SwitchListTile(title: const Text("Show Daily Doodle"), value: _showDoodle, onChanged: (v) { setState(() => _showDoodle = v); _syncSetting('show_doodle', v); }),
                SwitchListTile(title: const Text("Show Countdown"), value: _showCountdown, onChanged: (v) { setState(() => _showCountdown = v); _syncSetting('show_countdown', v); }),
                SwitchListTile(title: const Text("Show Live Location"), value: _showLiveLocation, onChanged: (v) { setState(() => _showLiveLocation = v); _syncSetting('show_live_location', v); }),
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
                  subtitle: Slider(
                    value: _ledBrightness,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: "${_ledBrightness.round()}%",
                    onChanged: _ledEnabled && !_adaptiveBrightness ? (v) { setState(() => _ledBrightness = v); } : null,
                    onChangeEnd: (v) => _syncSetting('led_brightness', v.round()),
                  ),
                ),
                const Divider(),
                SwitchListTile(title: const Text("Night Mode"), value: _nightMode, onChanged: (v) { setState(() => _nightMode = v); _syncSetting('night_mode', v); }),
                ListTile(
                  title: const Text("Night Brightness"),
                  subtitle: Slider(
                    value: _nightBrightness,
                    min: 0,
                    max: 50,
                    divisions: 50,
                    label: "${_nightBrightness.round()}%",
                    onChanged: _nightMode ? (v) { setState(() => _nightBrightness = v); } : null,
                    onChangeEnd: (v) => _syncSetting('night_brightness', v.round()),
                  ),
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
                      _patchSettings({'update_hour': time.hour, 'update_minute': time.minute});
                    }
                  },
                ),
              ],
            ),
            ExpansionTile(
              leading: const Icon(Icons.wifi),
              title: const Text("Network & System Actions"),
              initiallyExpanded: true,
              children: [
                ListTile(title: const Text("Status"), trailing: Text(_status == 'online' ? 'Online' : 'Offline')),
                ListTile(title: const Text("Last Seen"), trailing: Text(_lastSeen)),
                ListTile(title: const Text("Connected WiFi"), trailing: Text(_wifiSsid ?? 'Unknown')),
                ListTile(title: const Text("WiFi Strength"), trailing: Text(_formatWifiStrength(_rssi))),
                ListTile(title: const Text("Uptime"), trailing: Text(_formatUptime(_uptimeSeconds))),
                ListTile(title: const Text("Temperature"), trailing: Text(_coreTemp != null ? "${_coreTemp!.toStringAsFixed(1)}°C" : 'Unknown')),
                ListTile(title: const Text("Battery"), trailing: Text(_batteryLevel != null ? "$_batteryLevel%" : 'Unknown')),
                ListTile(
                  leading: const Icon(Icons.restart_alt, color: Colors.teal),
                  title: const Text("Restart Device"),
                  onTap: () => _executeCommand('restart'),
                ),
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
      ),
    );
  }
}