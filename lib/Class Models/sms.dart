import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> sendSos({
  required String phone,
  required String name,
  required double lat,
  required double lng,
}) async {
  final url = Uri.parse("https://us-central1-resq-mob.cloudfunctions.net/sendSosSms");

  try {
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "to": phone,
        "name": name,
        "latitude": lat,
        "longitude": lng,
      }),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200) {
      print("✅ SMS sent! SID: ${responseData['sid']}");
      // You might want to return the SID for tracking
      return responseData['sid'];
    } else {
      print("❌ Failed: ${responseData['error'] ?? response.body}");
      throw Exception(responseData['error'] ?? 'Failed to send SMS');
    }
  } catch (e) {
    print("❌ Network error: $e");
    throw Exception('Network error: $e');
  }
}