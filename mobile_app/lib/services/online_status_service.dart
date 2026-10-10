import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

Future<void> sendOnlineStatus() async {
  final prefs = await SharedPreferences.getInstance();

  final token = prefs.getString('user_jwt');
  if (token == null) return;
  try {

    await http.post(
      Uri.parse('$backendUrl/api/partners/last-seen-at'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }
    );
  } catch (e) {
    print("Location Error: $e");
  }
}