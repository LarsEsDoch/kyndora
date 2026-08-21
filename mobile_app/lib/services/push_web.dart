import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../constants.dart';

Future<void> initWebPush(String authToken) async {
  if (!html.Notification.supported) return;

  final permission = await html.Notification.requestPermission();
  if (permission != 'granted') return;

  final registration = await html.window.navigator.serviceWorker?.register('push-sw.js');
  if (registration == null) return;

  final existing = await registration.pushManager?.getSubscription();
  if (existing != null) {
    await _sendSubscription(authToken, existing);
    return;
  }

  final keyResponse = await http.get(Uri.parse('$backendUrl/api/push/vapid-public-key'));
  final publicKey = jsonDecode(keyResponse.body)['public_key'] as String?;
  if (publicKey == null) return;

  final subscription = await registration.pushManager?.subscribe({
    'userVisibleOnly': true,
    'applicationServerKey': _urlBase64ToUint8List(publicKey),
  });

  if (subscription != null) {
    await _sendSubscription(authToken, subscription);
  }
}

Future<void> _sendSubscription(String authToken, html.PushSubscription sub) async {
  final endpoint = sub.endpoint;
  if (endpoint == null) return;

  final p256dhBuffer = sub.getKey('p256dh');
  final authBuffer = sub.getKey('auth');
  if (p256dhBuffer == null || authBuffer == null) return;

  final p256dh = _base64UrlEncode(p256dhBuffer);
  final authKey = _base64UrlEncode(authBuffer);

  await http.post(
    Uri.parse('$backendUrl/api/push/register/webpush'),
    headers: {
      'Authorization': 'Bearer $authToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'endpoint': endpoint,
      'keys': {'p256dh': p256dh, 'auth': authKey},
    }),
  );
}

String _base64UrlEncode(ByteBuffer buffer) {
  final bytes = buffer.asUint8List();
  return base64Url.encode(bytes).replaceAll('=', '');
}

List<int> _urlBase64ToUint8List(String base64String) {
  final padding = '=' * ((4 - base64String.length % 4) % 4);
  final base64 = (base64String + padding).replaceAll('-', '+').replaceAll('_', '/');
  return base64Decode(base64);
}