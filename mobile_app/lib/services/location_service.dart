import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../constants.dart';

const String locationTaskKey = "kyndora_location_task";

Future<bool> ensureLocationPermission() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return false;

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return false;
  }

  if (permission == LocationPermission.deniedForever) return false;

  return true;
}

Future<void> sendCurrentLocation() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('user_jwt');
  if (token == null) return;

  final hasPermission = await ensureLocationPermission();
  if (!hasPermission) return;

  try {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    );

    await http.post(
      Uri.parse('$backendUrl/api/users/location'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'latitude': position.latitude,
        'longitude': position.longitude,
      }),
    );
  } catch (e) {
    print("Location Error: $e");
  }
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await sendCurrentLocation();
    return Future.value(true);
  });
}

Future<void> initLocationBackgroundTask() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    locationTaskKey,
    locationTaskKey,
    frequency: const Duration(minutes: 1),
    constraints: Constraints(networkType: NetworkType.connected),
  );
}