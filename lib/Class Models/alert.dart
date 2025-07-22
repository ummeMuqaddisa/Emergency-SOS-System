import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String alertId;
  final String userId;
  final String userName;
  final String userPhone;
  final String? address; // Optional: reverse geocoded location
  final String? message;
  final String status; // 'active', 'resolved', 'ignored'
  final Timestamp timestamp;
  final int severity; // 1 (low) to 5 (extreme)
  final List<String>? responders; // Nearby users or admins who responded
  final Map<String, dynamic>? location;

  AlertModel({
    required this.alertId,
    required this.userId,
    required this.userName,
    required this.userPhone,
    this.address,
    this.message,
    required this.status,
    required this.timestamp,
    required this.severity,
     this.responders,
    this.location
  });

  // Firestore -> AlertModel
  factory AlertModel.fromJson(Map<String, dynamic> json, String docId) {
    return AlertModel(
      alertId: docId,
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userPhone: json['userPhone'] ?? '',
      address: json['address'] ?? '',
      message: json['message'] ?? '',
      status: json['status'] ?? 'active',
      timestamp: json['timestamp'] ?? Timestamp.now(),
      severity: json['severity'] ?? 1,
      responders: List<String>.from(json['responders'] ?? []),
      location: {
        'latitude': json['longitude']  ,
        'longitude': json['longitude'] ,
      }
    );
  }

  // AlertModel -> Firestore
  Map<String, dynamic> toJson() {
    return {
      'alertId':alertId,
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'address': address,
      'message': message,
      'status': status,
      'timestamp': timestamp,
      'severity': severity,
      'responders': responders,
      'location': location,
    };
  }
}
