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
      // Endpoint im Backend anpassen, falls er anders heißt!
      final response = await http.get(
        Uri.parse('$backendUrl/api/feed/history'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        setState(() => _feedItems = jsonDecode(response.body));
      }
    } catch (e) {
      print("Feed Error: $e");
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
          ? const Center(child: Text("Noch keine Nachrichten."))
          : ListView.builder(
        itemCount: _feedItems.length,
        itemBuilder: (context, index) {
          final item = _feedItems[index];
          // Simples Layout für den Feed
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.message),
              title: Text(item['payload'] ?? ''),
              subtitle: Text(item['content_type'] ?? 'text'),
            ),
          );
        },
      ),
    );
  }
}