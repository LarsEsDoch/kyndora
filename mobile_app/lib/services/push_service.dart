import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'push_web_selector.dart' as web_push;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
}

Future<void> initPushNotifications(String authToken) async {
  if (kIsWeb) {
    await web_push.initWebPush(authToken);
    return;
  }
  await _initFcm(authToken);
}

Future<void> _initFcm(String authToken) async {
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    final token = await messaging.getToken();
    if (token != null) await _registerFcmToken(authToken, token);

    messaging.onTokenRefresh.listen((t) => _registerFcmToken(authToken, t));
  } catch (e) {
    debugPrint('FCM init failed: $e');
  }
}

Future<void> _registerFcmToken(String authToken, String token) async {
  try {
    await http.post(
      Uri.parse('$backendUrl/api/push/register/fcm'),
      headers: {'Authorization': 'Bearer $authToken', 'Content-Type': 'application/json'},
      body: jsonEncode({'token': token}),
    );
  } catch (e) {
    debugPrint('FCM token registration failed: $e');
  }
}