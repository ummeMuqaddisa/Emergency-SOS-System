import 'dart:convert';

import 'package:http/http.dart' as http;

Future<void> sendSos(
    List<String> contacts, String name, double lat, double lng) async {
  final url = Uri.parse(
      'https://us-central1-resq-mob.cloudfunctions.net/sendSosSms');

  final body = {
    "contacts": contacts,
    "name": name,
    "latitude": lat,
    "longitude": lng,
  };

  try {
    final response = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body));

    if (response.statusCode == 200) {
      print("✅ SOS SMS Sent");
      print(response.body);
    } else {
      print("❌ Failed: ${response.statusCode}");
      print(response.body);
    }
  } catch (e) {
    print("❌ Network error: $e");
    throw Exception("Network error: $e");
  }
}
