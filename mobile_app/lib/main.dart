import 'package:kyndora/screens/auth_screen.dart';
import 'package:kyndora/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:kyndora/services/online_status_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (!kIsWeb) await initLocationBackgroundTask();
  } catch (e) {
    debugPrint('Workmanager init failed: $e');
  }
  runApp(const KyndoraApp());
  sendCurrentLocation();
  sendOnlineStatus();
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