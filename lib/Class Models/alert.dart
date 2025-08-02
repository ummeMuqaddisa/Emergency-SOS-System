import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String alertId;
  final String userId;
  final String userName;
  final String userPhone;
  final String? address; // Optional: reverse geocoded location
  final String? pstation;
  final String? hpital;
  final String? message;
  final String? etype;
  final String status; // 'active', 'resolved', 'ignored'
  final Timestamp timestamp;
  final Timestamp? safeTime;
  final int severity; // 1 (low) to 5 (extreme)
  final List<String>? responders; // Nearby users or admins who responded
  final Map<String, dynamic>? location;

  AlertModel({
    required this.alertId,
    required this.userId,
    required this.userName,
    required this.userPhone,
    this.address,
    this.pstation,
    this.hpital,
    this.message,
    this.etype,
    required this.status,
    required this.timestamp,
    this.safeTime,
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
      pstation: json['pstation'] ?? '',
      hpital: json['hpital'] ?? '',
      message: json['message'] ?? '',
      etype: json['etype'] ?? 'unknown',
      status: json['status'] ?? 'active',
      timestamp: json['timestamp'] ?? Timestamp.now(),
      safeTime: json['safeTime'] ?? null,
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
      'pstation': pstation,
      'hpital': hpital,
      'message': message,
      'etype': etype,
      'status': status,
      'timestamp': timestamp,
      'safeTime': safeTime,
      'severity': severity,
      'responders': responders,
      'location': location,
    };
  }
}
