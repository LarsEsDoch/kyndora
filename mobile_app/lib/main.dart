import 'package:kyndora/screens/auth_screen.dart';
import 'package:kyndora/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    initLocationBackgroundTask();
  }
  sendCurrentLocation();
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