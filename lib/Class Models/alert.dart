import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String alertId;
  final String userId;
  final String userName;
  final String userPhone;
  final double latitude;
  final double longitude;
  final String? address; // Optional: reverse geocoded location
  final String? message;
  final String status; // 'active', 'resolved', 'ignored'
  final Timestamp timestamp;
  final int severity; // 1 (low) to 5 (extreme)
  final List<String>? responders; // Nearby users or admins who responded

  AlertModel({
    required this.alertId,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.latitude,
    required this.longitude,
    this.address,
    this.message,
    required this.status,
    required this.timestamp,
    required this.severity,
     this.responders,
  });

  // Firestore -> AlertModel
  factory AlertModel.fromJson(Map<String, dynamic> json, String docId) {
    return AlertModel(
      alertId: docId,
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userPhone: json['userPhone'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      address: json['address'] ?? '',
      message: json['message'] ?? '',
      status: json['status'] ?? 'active',
      timestamp: json['timestamp'] ?? Timestamp.now(),
      severity: json['severity'] ?? 1,
      responders: List<String>.from(json['responders'] ?? []),
    );
  }

  // AlertModel -> Firestore
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'message': message,
      'status': status,
      'timestamp': timestamp,
      'severity': severity,
      'responders': responders,
    };
  }
}
