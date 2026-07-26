import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String backendUrl = "http://192.168.178.100:8000";

void main() {
  runApp(const KyndoraApp());
}

class KyndoraApp extends StatelessWidget {
  const KyndoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kyndora',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('user_jwt');
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_token != null) return DashboardScreen(token: _token!);
    return const AuthScreen();
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      http.Response response;

      if (_isLogin) {
        response = await http.post(
          Uri.parse('$backendUrl/auth/login'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'username': _emailController.text, // Muss "username" heißen, auch wenn es eine Mail ist!
            'password': _passController.text,
          },
        );
      } else {
        response = await http.post(
          Uri.parse('$backendUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': _emailController.text,
            'password': _passController.text,
          }),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!_isLogin) {
          setState(() {
            _isLogin = true;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created. Please log in.')));
          return;
        }

        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_jwt', data['access_token']);

        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DashboardScreen(token: data['access_token'])));
        }
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Register')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: _passController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading ? const CircularProgressIndicator() : Text(_isLogin ? 'Login' : 'Sign Up'),
            ),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(_isLogin ? 'Need an account? Register' : 'Have an account? Login'),
            )
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final String token;
  const DashboardScreen({super.key, required this.token});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
        Uri.parse('http://192.168.178.100:8000/api/device'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        setState(() => _devices = jsonDecode(response.body));
      }
    } catch (e) {
      print("Fetch devices error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_jwt');
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Kyndora Devices'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchDevices,
        child: _devices.isEmpty
            ? const Center(child: Text("No devices found. Add one!"))
            : ListView.builder(
          itemCount: _devices.length,
          itemBuilder: (context, index) {
            final dev = _devices[index];
            return ListTile(
              leading: const Icon(Icons.devices),
              title: Text(dev['name'] ?? dev['mac_address'] ?? 'Unknown Device'),
              subtitle: const Text('Connected'),
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
        Uri.parse('http://192.168.178.100:8000/api/device/ticket'),
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