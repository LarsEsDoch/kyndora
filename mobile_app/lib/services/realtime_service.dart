import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants.dart';

class RealtimeService {
  RealtimeService._internal();
  static final RealtimeService instance = RealtimeService._internal();

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _eventController;
  String? _token;
  bool _shouldReconnect = false;
  int _reconnectAttempt = 0;

  Stream<Map<String, dynamic>> get events =>
      _eventController?.stream ?? const Stream.empty();

  void connect(String token) {
    if (_token == token && _channel != null) return;
    disconnect();

    _token = token;
    _shouldReconnect = true;
    _eventController ??= StreamController<Map<String, dynamic>>.broadcast();
    _openSocket();
  }

  void _openSocket() {
    if (_token == null) return;
    try {
      final uri = Uri.parse('$backendWsUrl/ws/events?token=$_token');
      _channel = WebSocketChannel.connect(uri);
      _reconnectAttempt = 0;

      _channel!.stream.listen(
            (message) {
          try {
            final decoded = jsonDecode(message) as Map<String, dynamic>;
            _eventController?.add(decoded);
          } catch (_) {
          }
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectAttempt++;
    final delaySeconds = _reconnectAttempt.clamp(1, 30);
    Future.delayed(Duration(seconds: delaySeconds), () {
      if (_shouldReconnect) _openSocket();
    });
  }

  void disconnect() {
    _shouldReconnect = false;
    _channel?.sink.close();
    _channel = null;
  }
}