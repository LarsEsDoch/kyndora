import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

class PartnerTab extends StatefulWidget {
  final String token;
  const PartnerTab({super.key, required this.token});

  @override
  State<PartnerTab> createState() => _PartnerTabState();
}

class _PartnerTabState extends State<PartnerTab> {
  final _usernameController = TextEditingController();
  final _messageController = TextEditingController();

  final GlobalKey _paintKey = GlobalKey();

  final int _gridSize = 80;
  late List<List<bool>> _pixels;
  bool _isSendingDoodle = false;

  Point<int>? _lastPoint;

  @override
  void initState() {
    super.initState();
    _clearDoodle();
  }

  void _clearDoodle() {
    setState(() {
      _pixels = List.generate(_gridSize, (_) => List.filled(_gridSize, false));
      _lastPoint = null;
    });
  }

  void _drawPixelBlock(int x, int y) {
    if (x >= 0 && x < _gridSize && y >= 0 && y < _gridSize) {
      _pixels[y][x] = true;
      if (x < _gridSize - 1) _pixels[y][x + 1] = true;
      if (y < _gridSize - 1) _pixels[y + 1][x] = true;
      if (x < _gridSize - 1 && y < _gridSize - 1) _pixels[y + 1][x + 1] = true;
    }
  }

  void _drawLine(Point<int> p1, Point<int> p2) {
    int x1 = p1.x;
    int y1 = p1.y;
    int x2 = p2.x;
    int y2 = p2.y;

    int dx = (x2 - x1).abs();
    int dy = (y2 - y1).abs();
    int sx = x1 < x2 ? 1 : -1;
    int sy = y1 < y2 ? 1 : -1;
    int err = dx - dy;

    while (true) {
      _drawPixelBlock(x1, y1);

      if (x1 == x2 && y1 == y2) break;
      int e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x1 += sx;
      }
      if (e2 < dx) {
        err += dx;
        y1 += sy;
      }
    }
  }

  void _handleGesture(Offset globalPosition, {bool isNewStroke = false}) {
    final RenderBox? box = _paintKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final Offset localPosition = box.globalToLocal(globalPosition);
    final Size size = box.size;

    int x = (localPosition.dx / size.width * _gridSize).floor();
    int y = (localPosition.dy / size.height * _gridSize).floor();

    if (x >= 0 && x < _gridSize && y >= 0 && y < _gridSize) {
      setState(() {
        Point<int> currentPoint = Point(x, y);

        if (isNewStroke || _lastPoint == null) {
          _drawPixelBlock(x, y);
        } else {
          _drawLine(_lastPoint!, currentPoint);
        }
        _lastPoint = currentPoint;
      });
    }
  }

  String _generateHexPayload() {
    String hexString = "";
    for (int y = 0; y < _gridSize; y++) {
      for (int x = 0; x < _gridSize; x += 8) {
        int byte = 0;
        for (int b = 0; b < 8; b++) {
          if (_pixels[y][x + b]) {
            byte |= (1 << (7 - b));
          }
        }
        hexString += byte.toRadixString(16).padLeft(2, '0');
      }
    }
    return hexString;
  }

  Future<void> _sendDoodle() async {
    setState(() => _isSendingDoodle = true);
    final payload = _generateHexPayload();

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/feed/?content_type=doodle&payload=$payload'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doodle gesendet!')));
        _clearDoodle();
      }
    } catch (e) {
      print("Doodle Error: $e");
    } finally {
      setState(() => _isSendingDoodle = false);
    }
  }

  Future<void> _sendPartnerRequest() async {
    final username = _usernameController.text;
    if (username.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/partners/request?target_username=$username'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anfrage gesendet!')));
        _usernameController.clear();
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text;
    if (text.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/feed/?content_type=text&payload=$text'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nachricht gesendet!')));
        _messageController.clear();
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Partner hinzufügen", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username des Partners', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _sendPartnerRequest, child: const Text('Anfragen'))
            ],
          ),

          const Divider(height: 48),

          const Text("Nachricht senden", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Textnachricht', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send),
            label: const Text('Text senden'),
          ),

          const Divider(height: 48),

          const Text("Doodle zeichnen (80x80)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          Center(
            child: Container(
              key: _paintKey,
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400, width: 2),
                color: Colors.white,
              ),
              child: GestureDetector(
                onPanDown: (details) => _handleGesture(details.globalPosition, isNewStroke: true),
                onPanUpdate: (details) => _handleGesture(details.globalPosition),
                onPanEnd: (_) => _lastPoint = null,
                child: CustomPaint(
                  painter: DoodlePainter(pixels: _pixels, gridSize: _gridSize),
                  size: const Size(240, 240),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _clearDoodle,
                icon: const Icon(Icons.clear),
                label: const Text('Löschen'),
              ),
              ElevatedButton.icon(
                onPressed: _isSendingDoodle ? null : _sendDoodle,
                icon: _isSendingDoodle
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.draw),
                label: const Text('Doodle senden'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DoodlePainter extends CustomPainter {
  final List<List<bool>> pixels;
  final int gridSize;

  DoodlePainter({required this.pixels, required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;

    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if (pixels[y][x]) {
          canvas.drawRect(
            Rect.fromLTWH(x * cellWidth, y * cellHeight, cellWidth, cellHeight),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant DoodlePainter oldDelegate) => true;
}