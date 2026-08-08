import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

class FeedTab extends StatefulWidget {
  final String token;
  const FeedTab({super.key, required this.token});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  List<dynamic> _feedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFeed();
  }

  Future<void> _fetchFeed() async {
    try {
      //FETCH: http.get('$backendUrl/api/feed')
      final response = await http.get(
        Uri.parse('$backendUrl/api/feed'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        setState(() => _feedItems = jsonDecode(response.body));
      }
    } catch (e) {
      throw Exception(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _fetchFeed,
      child: _feedItems.isEmpty
          ? const Center(child: Text("No messages yet."))
          : ListView.builder(
        itemCount: _feedItems.length,
        itemBuilder: (context, index) {
          final item = _feedItems[index];
          final isDoodle = item['content_type'] == 'doodle';

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isDoodle ? Icons.draw : Icons.message, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      Text(
                        isDoodle ? "Daily Doodle" : "Message",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  isDoodle
                      ? Center(
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                      child: CustomPaint(
                        size: const Size(160, 160),
                        painter: DoodleDisplayPainter(hexString: item['payload'], gridSize: 80),
                      ),
                    ),
                  )
                      : Text(item['payload'] ?? '', style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class DoodleDisplayPainter extends CustomPainter {
  final String hexString;
  final int gridSize;

  DoodleDisplayPainter({required this.hexString, required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;

    if (hexString.length != (gridSize * gridSize) / 4) return;

    int charIdx = 0;
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x += 8) {
        String hexByte = hexString.substring(charIdx, charIdx + 2);
        int val = int.parse(hexByte, radix: 16);
        for (int b = 0; b < 8; b++) {
          if ((val & (1 << (7 - b))) != 0) {
            canvas.drawRect(
              Rect.fromLTWH((x + b) * cellWidth, y * cellHeight, cellWidth, cellHeight),
              paint,
            );
          }
        }
        charIdx += 2;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DoodleDisplayPainter oldDelegate) => oldDelegate.hexString != hexString;
}