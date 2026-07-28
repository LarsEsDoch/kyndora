import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../constants.dart';

class ProvisioningScreen extends StatefulWidget {
  final String token;
  const ProvisioningScreen({super.key, required this.token});

  @override
  State<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends State<ProvisioningScreen> {
  final _ssidController = TextEditingController();
  final _passController = TextEditingController();
  String _statusMessage = "Ready to connect.";
  bool _isProcessing = false;

  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String charUuidSsid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  final String charUuidPass = "beb5483f-36e1-4688-b7f5-ea07361b26a8";
  final String charUuidToken = "beb54840-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
  }

  Future<String?> _fetchProvisioningTicket() async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/device/ticket'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['ticket_token'];
      } else {
        setState(() => _statusMessage = "API Error: ${response.statusCode}");
        print("Ticket Error Body: ${response.body}");
      }
    } catch (e) {
      setState(() => _statusMessage = "Failed to fetch ticket: $e");
    }
    return null;
  }

  Future<void> _startProvisioning() async {
    if (_ssidController.text.isEmpty || _passController.text.isEmpty) {
      setState(() => _statusMessage = "Please enter Wi-Fi credentials.");
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = "Fetching secure ticket...";
    });

    final ticketToken = await _fetchProvisioningTicket();
    if (ticketToken == null) {
      setState(() => _isProcessing = false);
      return;
    }

    setState(() => _statusMessage = "Scanning for Kyndora-Setup...");

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      BluetoothDevice? kyndoraDevice;

      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.platformName == "Kyndora-Setup") {
            kyndoraDevice = r.device;
            FlutterBluePlus.stopScan();
          }
        }
      });

      await Future.delayed(const Duration(seconds: 4));

      if (kyndoraDevice == null) {
        setState(() => _statusMessage = "Kyndora Box not found. Is BLE running?");
        return;
      }

      setState(() => _statusMessage = "Connecting to ${kyndoraDevice!.platformName}...");
      await kyndoraDevice!.connect(license: License.free);

      List<BluetoothService> services = await kyndoraDevice!.discoverServices();
      BluetoothService? targetService;
      for (var service in services) {
        if (service.uuid.toString() == serviceUuid) {
          targetService = service;
        }
      }

      if (targetService == null) {
        setState(() => _statusMessage = "Kyndora Service not found.");
        await kyndoraDevice!.disconnect();
        return;
      }

      setState(() => _statusMessage = "Sending credentials and ticket...");

      for (var characteristic in targetService.characteristics) {
        String uuid = characteristic.uuid.toString();
        if (uuid == charUuidSsid) {
          await characteristic.write(utf8.encode(_ssidController.text));
        } else if (uuid == charUuidPass) {
          await characteristic.write(utf8.encode(_passController.text));
        } else if (uuid == charUuidToken) {
          await characteristic.write(utf8.encode(ticketToken));
        }
      }

      setState(() => _statusMessage = "Data sent to Kyndora. Finalizing...");

      await Future.delayed(const Duration(seconds: 3));

      await kyndoraDevice!.disconnect();

      setState(() {
        _isProcessing = false;
        _statusMessage = "Provisioning successful!";
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Success!"),
            content: const Text("Kyndora is provisioned and connecting to Wi-Fi."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      setState(() => _statusMessage = "Error: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Kyndora Device')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _ssidController, decoration: const InputDecoration(labelText: 'Wi-Fi Name (SSID)')),
            const SizedBox(height: 12),
            TextField(controller: _passController, decoration: const InputDecoration(labelText: 'Wi-Fi Password'), obscureText: true),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isProcessing ? null : _startProvisioning,
              child: _isProcessing
                  ? const CircularProgressIndicator()
                  : const Text('Provision Device'),
            ),
            const SizedBox(height: 24),
            Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}