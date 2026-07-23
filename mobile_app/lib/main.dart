import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const KyndoraApp());
}

class KyndoraApp extends StatelessWidget {
  const KyndoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kyndora Setup',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const ProvisioningScreen(),
    );
  }
}

class ProvisioningScreen extends StatefulWidget {
  const ProvisioningScreen({super.key});

  @override
  State<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends State<ProvisioningScreen> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  String _statusMessage = "Ready to connect.";
  bool _isProcessing = false;

  // Die UUIDs exakt wie in deiner C++ Datei
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
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> _startProvisioning() async {
    if (_ssidController.text.isEmpty || _passController.text.isEmpty || _tokenController.text.isEmpty) {
      setState(() => _statusMessage = "Please fill in all fields.");
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = "Scanning for Kyndora-Setup...";
    });

    try {
      // 1. Scan starten
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

      // Warte kurz, bis der Scan abgeschlossen ist
      await Future.delayed(const Duration(seconds: 4));

      if (kyndoraDevice == null) {
        setState(() => _statusMessage = "Kyndora Box not found. Is BLE running?");
        return;
      }

      setState(() => _statusMessage = "Connecting to ${kyndoraDevice!.platformName}...");

      // 2. Verbinden
      await kyndoraDevice!.connect(license: License.free);

      setState(() => _statusMessage = "Discovering services...");
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

      setState(() => _statusMessage = "Sending data to Kyndora...");

      // 3. Charakteristiken finden und beschreiben
      for (var characteristic in targetService.characteristics) {
        String uuid = characteristic.uuid.toString();

        if (uuid == charUuidSsid) {
          await characteristic.write(utf8.encode(_ssidController.text));
        } else if (uuid == charUuidPass) {
          await characteristic.write(utf8.encode(_passController.text));
        } else if (uuid == charUuidToken) {
          await characteristic.write(utf8.encode(_tokenController.text));
        }
      }

      setState(() => _statusMessage = "Provisioning sent! Watch your ESP32 console.");

      // 4. Verbindung sauber trennen
      await Future.delayed(const Duration(seconds: 1));
      await kyndoraDevice!.disconnect();

    } catch (e) {
      setState(() => _statusMessage = "Error: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kyndora Provisioning'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ssidController,
              decoration: const InputDecoration(labelText: 'Wi-Fi Name (SSID)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passController,
              decoration: const InputDecoration(labelText: 'Wi-Fi Password'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                  labelText: 'Registration Token (Test: 1234)',
                  hintText: 'Paste backend token here'
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isProcessing ? null : _startProvisioning,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Provision Device', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
          ],
        ),
      ),
    );
  }
}