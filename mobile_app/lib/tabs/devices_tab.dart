import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../screens/provisioning_screen.dart';
import '../screens/device_detail_screen.dart';

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
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.developer_board),
                title: Text(dev['name'] ?? dev['mac_address']),
                subtitle: Text(dev['status'] == 'online' ? 'Online' : 'Offline'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeviceDetailScreen(
                        token: widget.token,
                        macAddress: dev['mac_address'],
                        deviceName: dev['name'] ?? dev['mac_address'],
                      ),
                    ),
                  ).then((_) => _fetchDevices());
                },
              ),
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