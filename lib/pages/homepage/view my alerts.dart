import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';

import '../../Class Models/alert.dart';

class AlertHistoryScreen extends StatefulWidget {
  const AlertHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  List<AlertModel> alerts = [];
  bool isLoading = true;
  Map<String, String> cachedAddresses = {};
  String selectedStatus = 'All';
  final List<String> statusOptions = ['All', 'danger', 'safe'];

  @override
  void initState() {
    super.initState();
    fetchAlerts();
  }

  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return "${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}";
      }
      return "Unknown location";
    } catch (e) {
      return "Unknown location";
    }
  }

  Future<String> getLocationForAlert(AlertModel alert) async {
    if (alert.address != null && alert.address!.isNotEmpty) {
      return alert.address!;
    }

    if (alert.location != null &&
        alert.location!['latitude'] != null &&
        alert.location!['longitude'] != null) {
      final lat = alert.location!['latitude'] as double;
      final lng = alert.location!['longitude'] as double;
      final cacheKey = '${lat}_$lng';

      if (cachedAddresses.containsKey(cacheKey)) {
        return cachedAddresses[cacheKey]!;
      }

      final address = await getAddressFromLatLng(lat, lng);
      cachedAddresses[cacheKey] = address;
      return address;
    }

    return "Location not available";
  }

  Future<void> fetchAlerts() async {
    try {
      setState(() => isLoading = true);

      final alertSnapshot = await FirebaseFirestore.instance
          .collection('Alerts')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        alerts = alertSnapshot.docs
            .map((doc) => AlertModel.fromJson(doc.data(), doc.id))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading alerts: $e')),
      );
    }
  }

  String formatDuration(AlertModel alert) {
    if (alert.safeTime == null) {
      final duration = DateTime.now().difference(alert.timestamp.toDate());
      return _formatDurationString(duration);
    } else {
      final duration = alert.safeTime!.toDate().difference(alert.timestamp.toDate());
      return _formatDurationString(duration);
    }
  }

  String _formatDurationString(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'danger': return Colors.red;
      case 'safe': return Colors.green;
      default: return Colors.grey;
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

  List<AlertModel> get filteredAlerts {
    if (selectedStatus == 'All') return alerts;
    return alerts.where((alert) => alert.status == selectedStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Alert History'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchAlerts,
          ),
        ],
      ),
      body: Column(
        children: [

          // Alert count
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${filteredAlerts.length} alerts',
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
                    Icons.history,
                    size: 60,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No alerts found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: fetchAlerts,
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
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            // Status indicator
            Container(
              width: 8,
              height: 40,
              decoration: BoxDecoration(
                color: getStatusColor(alert.status),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),

            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.etype?.toUpperCase() ?? 'ALERT',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: getSeverityColor(alert.severity).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          getSeverityText(alert.severity),
                          style: TextStyle(
                            color: getSeverityColor(alert.severity),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM dd, hh:mm a').format(alert.timestamp.toDate()),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Duration
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatDuration(alert),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${alert.notified} notified',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (alert.message != null && alert.message!.isNotEmpty) ...[
                  _buildDetailRow('Message', alert.message!),
                  const SizedBox(height: 16),
                ],

                // Location section
                FutureBuilder<String>(
                  future: getLocationForAlert(alert),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              const Text(
                                'Loading location...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }

                    final location = snapshot.data ?? 'Location not available';
                    return Column(
                      children: [
                        _buildDetailRow('Location', location),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),

                // Timeline
                Row(
                  children: [
                    Expanded(
                        child: _buildDetailRow(
                          'Started',
                          DateFormat('MMM dd, hh:mm a').format(alert.timestamp.toDate()),
                        ), )
                    ,
                        if (alert.safeTime != null)
                    Expanded(
                      child: _buildDetailRow(
                        'Ended',
                        DateFormat('MMM dd, hh:mm a').format(alert.safeTime!.toDate()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Additional info
                Row(
                  children: [
                    if (alert.responders != null && alert.responders!.isNotEmpty)
                      Expanded(
                        child: _buildDetailRow(
                          'Responders',
                          '${alert.responders!.length} contacts',
                        ),
                      ),
                    Expanded(
                      child: _buildDetailRow(
                        'Notified',
                        '${alert.notified} contacts',
                      ),
                    ),
                  ],
                ),

                if (alert.pstation != null && alert.pstation!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildDetailRow('Police Station', alert.pstation!),
                ],

                if (alert.hpital != null && alert.hpital!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildDetailRow('Hospital', alert.hpital!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}