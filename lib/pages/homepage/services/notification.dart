// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:latlong2/latlong.dart';
//
// class notification {
//
//   void _checkInitialMessage(context) async {
//     RemoteMessage? initialMessage =
//     await FirebaseMessaging.instance.getInitialMessage();
//
//     if (initialMessage != null) {
//       print("🧊 App opened from terminated state via notification");
//       _handleMessage(initialMessage,context);
//     }
//   }
//
//   void _handleMessage(RemoteMessage message,context) {
//     final data = message.data;
//
//     final title = message.notification?.title ?? 'Notification';
//     final body = message.notification?.body ?? '';
//
//     if (context.mounted) {
//       _showNotificationDialog(title, body, data,context); // or navigate, etc.
//     }
//   }
//
//
//   void _showNotificationDialog(String title, String body, Map<String, dynamic> data,context) {
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text(title),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(body),
//                 const SizedBox(height: 12),
//                 if (data.isNotEmpty) ...[
//                   const Text('Additional Data:', style: TextStyle(fontWeight: FontWeight.bold)),
//                   ...data.entries.map((entry) => Text('${entry.key}: ${entry.value}')),
//                 ],
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () async {
//                 Navigator.of(context).pop();
//
//                 final userId = FirebaseAuth.instance.currentUser?.uid;
//                 final double? lat = double.tryParse(data['latitude'].toString());
//                 final double? lng = double.tryParse(data['longitude'].toString());
//                 final String? alertId = data['alertId'];
//                 if (userId != null && alertId != null) {
//                   try {
//                     final alertRef = FirebaseFirestore.instance.collection('Alerts').doc(alertId);
//                     await alertRef.set({
//                       'responders': [],
//                     }, SetOptions(merge: true));
//
//
//                     await alertRef.update({
//                       'responders': FieldValue.arrayUnion([userId]),
//                     });
//
//                     print("User $userId added to responders of alert $alertId");
//
//
//                   } catch (e) {
//                     print("Failed to add responder: $e");
//                   }
//                 } else {
//                   print("Missing userId or alertId");
//                 }
//
//                 if (lat != null && lng != null && _currentPosition != null) {
//                   print("Getting directions...");
//                   _navigationDestination = LatLng(lat, lng);
//                   await _getDirections(
//                     LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
//                     LatLng(lat, lng),
//                   );
//                   _checkDanger(alertId!);
//                 } else {
//                   print("Invalid or missing coordinates.");
//                 }
//               },
//
//               child: const Text('Help'),
//             ),
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('Close'),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//
// }