import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'dart:typed_data';

Future<void> initWebPush(String authToken) async {
  if (!html.Notification.supported) {
    print('[Push] Notifications not supported in this browser.');
    return;
  }

  final permission = await html.Notification.requestPermission();
  print('[Push] Permission result: $permission');
  if (permission != 'granted') return;

  if (html.window.navigator.serviceWorker == null) {
    print('[Push] serviceWorker API not available (not a secure context?).');
    return;
  }

  html.ServiceWorkerRegistration registration;
  try {
    registration = await html.window.navigator.serviceWorker!.register('push-sw.js');
    print('[Push] Service worker registered: ${registration.scope}');
  } catch (e) {
    print('[Push] Service worker registration FAILED: $e');
    return;
  }

  await html.window.navigator.serviceWorker!.ready;

  final existing = await registration.pushManager?.getSubscription();
  if (existing != null) {
    print('[Push] Existing subscription found, re-sending to backend.');
    await _sendSubscription(authToken, existing);
    return;
  }

  final keyResponse = await http.get(Uri.parse('$backendUrl/api/push/vapid-public-key'));
  final publicKey = jsonDecode(keyResponse.body)['public_key'] as String?;
  print('[Push] VAPID public key fetched: $publicKey');
  if (publicKey == null) return;

  try {
    final subscription = await registration.pushManager?.subscribe({
      'userVisibleOnly': true,
      'applicationServerKey': publicKey,
    });

    if (subscription != null) {
      print('[Push] Subscribed: ${subscription.endpoint}');
      await _sendSubscription(authToken, subscription);
    }
  } catch (e) {
    print('[Push] pushManager.subscribe FAILED: $e');
  }
}

Future<void> _sendSubscription(String authToken, html.PushSubscription sub) async {
  String bufferToBase64Url(ByteBuffer? buffer) {
    if (buffer == null) return '';
    final uint8List = buffer.asUint8List();
    return base64UrlEncode(uint8List).replaceAll('=', '');
  }

  final p256dhBuffer = sub.getKey('p256dh');
  final authBuffer = sub.getKey('auth');

  final subJson = {
    'endpoint': sub.endpoint,
    'keys': {
      'p256dh': bufferToBase64Url(p256dhBuffer),
      'auth': bufferToBase64Url(authBuffer),
    }
  };

  final response = await http.post(
    Uri.parse('$backendUrl/api/push/register/webpush'),
    headers: {
      'Authorization': 'Bearer $authToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(subJson),
  );
  print('[Push] Backend registration response: ${response.statusCode} ${response.body}');
}