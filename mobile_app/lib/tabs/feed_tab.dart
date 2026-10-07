import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../services/realtime_service.dart';

class FeedTab extends StatefulWidget {
  final String token;
  const FeedTab({super.key, required this.token});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<dynamic> _feedItems = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _requestGeneration = 0;
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;

  Map<String, String> get _authHeaders => {'Authorization': 'Bearer ${widget.token}'};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _refreshFeed();
    _eventSubscription = RealtimeService.instance.events.listen((event) {
      if (event['type'] == 'feed_updated' && mounted) {
        _refreshFeed();
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<List<dynamic>> _fetchPage(int offset) async {
    final response = await http.get(
      Uri.parse('$backendUrl/api/feed?limit=$_pageSize&offset=$offset'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw Exception('Feed request failed (${response.statusCode})');
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<void> _refreshFeed() async {
    final generation = ++_requestGeneration;
    try {
      final page = await _fetchPage(0);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _feedItems
          ..clear()
          ..addAll(page);
        _hasMore = page.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (mounted && generation == _requestGeneration) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load feed: $e')));
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    final generation = _requestGeneration;
    setState(() => _isLoadingMore = true);
    try {
      final page = await _fetchPage(_feedItems.length);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _feedItems.addAll(page);
        _hasMore = page.length == _pageSize;
      });
    } catch (e) {
      if (mounted && generation == _requestGeneration) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load more: $e')));
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _refreshFeed,
      child: _feedItems.isEmpty
          ? ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: Text("No messages yet.")),
        ],
      )
          : ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _feedItems.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _feedItems.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final item = _feedItems[index];
          final isDoodle = item['content_type'] == 'doodle';
          final isDisplayed = item['is_displayed'] == true;

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
                        "${isDoodle ? "Daily Doodle" : "Message"} (${item['direction'] ?? 'unknown'})",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (isDisplayed) ...[
                        const SizedBox(width: 8),
                        const Tooltip(
                          message: 'Shown on the display',
                          child: Icon(Icons.visibility, size: 18, color: Colors.green),
                        ),
                      ],
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