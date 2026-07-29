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
  Map<String, dynamic>? _deviceDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDeviceDetails();
  }

  Future<void> _fetchDeviceDetails() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/api/device/${widget.macAddress}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _deviceDetails = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print("Error fetching details: $e");
    }
  }

  Future<void> _restartDevice() async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/device/${widget.macAddress}/command?command=restart'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restart-Befehl an ESP gesendet!')));
      }
    } catch (e) {
      print("Restart Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchDeviceDetails();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deviceDetails == null
          ? const Center(child: Text("Gerätedaten konnten nicht geladen werden."))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildTelemetryCard(),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _restartDevice,
              icon: const Icon(Icons.restart_alt),
              label: const Text("Gerät neustarten"),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red.shade600,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = _deviceDetails!['status'] ?? 'unknown';
    final lastSeen = _deviceDetails!['last_seen'] ?? 'Nie';

    return Card(
      child: ListTile(
        leading: Icon(
          Icons.circle,
          color: status == 'online' ? Colors.green : Colors.grey,
          size: 16,
        ),
        title: Text("Status: ${status.toUpperCase()}"),
        subtitle: Text("Zuletzt gemeldet: $lastSeen"),
      ),
    );
  }

  Widget _buildTelemetryCard() {
    final telemetry = _deviceDetails!['telemetry'] ?? {};
    final rssi = telemetry['rssi']?.toString() ?? 'N/A';
    final uptime = telemetry['uptime_s']?.toString() ?? 'N/A';
    final freeHeap = telemetry['free_heap']?.toString() ?? 'N/A';
    final temp = telemetry['temperature']?.toString() ?? 'N/A';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Telemetrie & Health", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.wifi),
              title: const Text("WLAN Signal (RSSI)"),
              trailing: Text("$rssi dBm"),
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text("Uptime"),
              trailing: Text("$uptime s"),
            ),
            ListTile(
              leading: const Icon(Icons.memory),
              title: const Text("Freier Speicher (RAM)"),
              trailing: Text("$freeHeap Bytes"),
            ),
            ListTile(
              leading: const Icon(Icons.thermostat),
              title: const Text("ESP Temperatur"),
              trailing: Text("$temp °C"),
            ),
          ],
        ),
      ),
    );
  }
}