import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';
import '../screens/provisioning_screen.dart';

class DevicesTab extends StatefulWidget {
  final String token;
  const DevicesTab({super.key, required this.token});

  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> {
  List<dynamic> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  Future<void> _fetchDevices() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/api/device'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        setState(() => _devices = jsonDecode(response.body));
      }
    } catch (e) {
      print("Device Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restartDevice(String macAddress) async {
    try {
      await http.post(
        Uri.parse('$backendUrl/api/device/$macAddress/command?command=restart'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restart Befehl gesendet')));
    } catch (e) {
      print("Restart Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchDevices,
        child: _devices.isEmpty
            ? const Center(child: Text("Keine Geräte gefunden."))
            : ListView.builder(
          itemCount: _devices.length,
          itemBuilder: (context, index) {
            final dev = _devices[index];
            return ExpansionTile(
              leading: const Icon(Icons.developer_board),
              title: Text(dev['name'] ?? dev['mac_address']),
              subtitle: Text(dev['status'] == 'online' ? 'Online' : 'Offline'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Hier würdest du echte Telemetrie aus dem Dev-Objekt holen
                      Column(children: const [Icon(Icons.wifi), Text("-65 dBm")]),
                      Column(children: const [Icon(Icons.memory), Text("45°C")]),
                      IconButton(
                        icon: const Icon(Icons.restart_alt, color: Colors.red),
                        onPressed: () => _restartDevice(dev['mac_address']),
                        tooltip: 'ESP32 Neustarten',
                      )
                    ],
                  ),
                )
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProvisioningScreen(token: widget.token)))
              .then((_) => _fetchDevices());
        },
        label: const Text('Add Device'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}