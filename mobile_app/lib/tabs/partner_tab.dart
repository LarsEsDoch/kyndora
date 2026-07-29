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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: ${response.body}')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nachricht an Partner gesendet!')));
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
              ElevatedButton(
                onPressed: _sendPartnerRequest,
                child: const Text('Anfragen'),
              )
            ],
          ),
          const Divider(height: 48),
          const Text("Nachricht auf Display senden", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Was möchtest du senden?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send),
            label: const Text('Senden'),
          ),
        ],
      ),
    );
  }
}