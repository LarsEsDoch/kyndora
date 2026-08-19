import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class PendingPartnerRequest {
  final int id;
  final String senderUsername;
  final DateTime createdAt;

  PendingPartnerRequest({
    required this.id,
    required this.senderUsername,
    required this.createdAt,
  });

  factory PendingPartnerRequest.fromJson(Map<String, dynamic> json) {
    return PendingPartnerRequest(
      id: json['id'],
      senderUsername: json['sender_username'] ?? 'Unknown',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

Future<List<PendingPartnerRequest>> fetchPendingPartnerRequests(String token) async {
  final response = await http.get(
    Uri.parse('$backendUrl/api/partners/requests/pending'),
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to load pending requests (${response.statusCode})');
  }

  final List<dynamic> data = jsonDecode(response.body);
  return data.map((e) => PendingPartnerRequest.fromJson(e)).toList();
}

Future<void> acceptPartnerRequest(String token, int requestId) async {
  final response = await http.post(
    Uri.parse('$backendUrl/api/partners/accept/$requestId'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (response.statusCode != 200) {
    throw Exception('Failed to accept request (${response.statusCode})');
  }
}

Future<void> declinePartnerRequest(String token, int requestId) async {
  final response = await http.post(
    Uri.parse('$backendUrl/api/partners/decline/$requestId'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (response.statusCode != 200) {
    throw Exception('Failed to decline request (${response.statusCode})');
  }
}