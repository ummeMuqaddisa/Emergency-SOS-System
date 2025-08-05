import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../Class Models/alert.dart';


class ViewActiveAlertsScreen extends StatefulWidget {
  final Position? currentPosition;

  const ViewActiveAlertsScreen({Key? key, this.currentPosition}) : super(key: key);

  @override
  State<ViewActiveAlertsScreen> createState() => _ViewActiveAlertsScreenState();
}

class _ViewActiveAlertsScreenState extends State<ViewActiveAlertsScreen> {
  List<AlertModel> activeAlerts = [];
  bool isLoading = true;
  String selectedSeverity = 'All';
  final List<String> severityOptions = ['All', '1', '2', '3'];

  @override
  void initState() {
    super.initState();
    fetchActiveAlerts();
  }

  Future<void> fetchActiveAlerts() async {
    try {
      setState(() => isLoading = true);

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      final alertSnapshot = await FirebaseFirestore.instance
          .collection('Alerts')
          .where('status', isEqualTo: 'danger')
          .orderBy('timestamp', descending: true)
          .get();

      List<AlertModel> alerts = [];

      for (var doc in alertSnapshot.docs) {
        final data = doc.data();

        // Skip current user's alerts and admin alerts
        if (data['userId'] == currentUserId || data['admin'] == true) {
          continue;
        }

        final alert = AlertModel.fromJson(data, doc.id);
        alerts.add(alert);
      }

      setState(() {
        activeAlerts = alerts;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading alerts: $e')),
        );
      }
    }
  }

  List<AlertModel> get filteredAlerts {
    if (selectedSeverity == 'All') return activeAlerts;
    return activeAlerts.where((alert) =>
    alert.severity.toString() == selectedSeverity).toList();
  }

  String formatDuration(AlertModel alert) {
    final duration = DateTime.now().difference(alert.timestamp.toDate());
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h ago';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m ago';
    } else {
      return '${duration.inMinutes}m ago';
    }
  }

  String calculateDistance(AlertModel alert) {
    if (widget.currentPosition == null || alert.location == null) {
      return 'Distance unknown';
    }

    try {
      final alertLat = alert.location!['latitude'];
      final alertLng = alert.location!['longitude'];

      if (alertLat == null || alertLng == null) {
        return 'Distance unknown';
      }

      final distance = Geolocator.distanceBetween(
        widget.currentPosition!.latitude,
        widget.currentPosition!.longitude,
        alertLat is double ? alertLat : double.parse(alertLat.toString()),
        alertLng is double ? alertLng : double.parse(alertLng.toString()),
      );

      if (distance >= 1000) {
        return '${(distance / 1000).toStringAsFixed(1)} km away';
      } else {
        return '${distance.toInt()} m away';
      }
    } catch (e) {
      return 'Distance unknown';
    }
  }

  Color getSeverityColor(int severity) {
    switch (severity) {
      case 1: return Colors.orange;
      case 2: return Colors.deepOrange;
      case 3: return Colors.red;
      default: return Colors.grey;
    }
  }

  String getSeverityText(int severity) {
    switch (severity) {
      case 1: return 'Low';
      case 2: return 'Medium';
      case 3: return 'High';
      default: return 'Unknown';
    }
  }

  Future<void> respondToAlert(AlertModel alert) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Add current user to responders list
      await FirebaseFirestore.instance
          .collection('Alerts')
          .doc(alert.alertId)
          .update({
        'responders': FieldValue.arrayUnion([currentUserId])
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are now responding to this alert')),
        );
      }

      // Refresh the alerts list
      fetchActiveAlerts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error responding to alert: $e')),
        );
      }
    }
  }

  bool isUserResponding(AlertModel alert) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return alert.responders?.contains(currentUserId) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Active Alerts'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchActiveAlerts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Severity: ',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: severityOptions.map((severity) {
                        final isSelected = selectedSeverity == severity;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(severity),
                            selected: isSelected,
                            onSelected: (bool selected) {
                              setState(() {
                                selectedSeverity = severity;
                              });
                            },
                            selectedColor: Colors.red[100],
                            checkmarkColor: Colors.red[800],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Alert count
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${filteredAlerts.length} active alerts',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Alerts List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : filteredAlerts.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.crisis_alert,
                    size: 60,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No active alerts found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: fetchActiveAlerts,
              color: Colors.red,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredAlerts.length,
                itemBuilder: (context, index) {
                  final alert = filteredAlerts[index];
                  return _buildAlertCard(alert);
                },
              ),
            ),
          ),
        ],
      ),

    );
  }

  Widget _buildAlertCard(AlertModel alert) {
    final isResponding = isUserResponding(alert);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with severity indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: getSeverityColor(alert.severity).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: getSeverityColor(alert.severity),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'SEVERITY ${alert.severity}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  formatDuration(alert),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Alert content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (alert.etype != null)
                            Text(
                              alert.etype!.toUpperCase(),
                              style: TextStyle(
                                color: getSeverityColor(alert.severity),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      calculateDistance(alert),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (alert.message != null && alert.message!.isNotEmpty) ...[
                  Text(
                    alert.message!,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                ],

                if (alert.address != null && alert.address!.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          alert.address!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  children: [
                    Text(
                      'Notified: ${alert.notified}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Responders: ${alert.responders?.length ?? 0}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(
                          isResponding ? Icons.check : Icons.volunteer_activism,
                          size: 18,
                        ),
                        label: Text(isResponding ? 'Responding' : 'Respond'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isResponding ? Colors.green : Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: isResponding ? null : () => respondToAlert(alert),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.navigation, size: 18),
                        label: const Text('Navigate'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          // Navigate to the alert location
                          // You can implement navigation logic here
                          // similar to your existing _showNavigationBottomSheet
                          if (alert.location != null) {
                            final lat = alert.location!['latitude'];
                            final lng = alert.location!['longitude'];

                            if (lat != null && lng != null) {
                              // Close this screen and trigger navigation on the map
                              Navigator.pop(context, {
                                'navigate': true,
                                'destination': {
                                  'latitude':lat,
                                  'longitude':lng
                                },
                                'alertData': alert.toJson(),
                              });
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}