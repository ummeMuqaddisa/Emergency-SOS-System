import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HeatmapPage extends StatefulWidget {
  const HeatmapPage({super.key});

  @override
  State<HeatmapPage> createState() => _HeatmapPageState();
}

class _HeatmapPageState extends State<HeatmapPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  List<LatLng> _heatmapData = [];
  bool _isLoading = true;
  bool _showHeatmap = true;

  // Default map center (you can adjust this to your preferred location)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(37.7749, -122.4194), // San Francisco
    zoom: 10,
  );

  @override
  void initState() {
    super.initState();
    _loadLocationData();
  }

  Future<void> _loadLocationData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final querySnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .get();

      Set<Marker> loadedMarkers = {};
      List<LatLng> heatmapPoints = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();

        if (data.containsKey('location')) {
          final location = data['location'];
          final latitude = location['latitude'];
          final longitude = location['longitude'];

          if (latitude != null && longitude != null) {
            final latLng = LatLng(latitude, longitude);

            // Add marker
            final marker = Marker(
              markerId: MarkerId(doc.id),
              position: latLng,
              infoWindow: InfoWindow(
                title: data['name'] ?? 'Unknown User',
                snippet: data['email'] ?? '',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRose,
              ),
            );
            loadedMarkers.add(marker);

            // Add heatmap point
            heatmapPoints.add(latLng);
          }
        }
      }

      setState(() {
        _markers = loadedMarkers;
        _heatmapData = heatmapPoints;
        _isLoading = false;
      });

      // Adjust camera to show all markers if any exist
      if (loadedMarkers.isNotEmpty && _mapController != null) {
        _fitMarkersInView();
      }

      debugPrint("Location data loaded: ${loadedMarkers.length} points");
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading location data: $e');

      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading location data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _fitMarkersInView() {
    if (_markers.isEmpty || _mapController == null) return;

    double minLat = _markers.first.position.latitude;
    double maxLat = _markers.first.position.latitude;
    double minLng = _markers.first.position.longitude;
    double maxLng = _markers.first.position.longitude;

    for (Marker marker in _markers) {
      minLat = minLat < marker.position.latitude ? minLat : marker.position.latitude;
      maxLat = maxLat > marker.position.latitude ? maxLat : marker.position.latitude;
      minLng = minLng < marker.position.longitude ? minLng : marker.position.longitude;
      maxLng = maxLng > marker.position.longitude ? maxLng : marker.position.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100.0, // padding
      ),
    );
  }

  void _toggleHeatmap() {
    setState(() {
      _showHeatmap = !_showHeatmap;
    });
  }

  // Create a simple heatmap effect using circles
  Set<Circle> _createHeatmapCircles() {
    Set<Circle> circles = {};

    for (int i = 0; i < _heatmapData.length; i++) {
      final point = _heatmapData[i];

      // Create multiple circles with different radii for heat effect
      circles.add(
        Circle(
          circleId: CircleId('heat_${i}_outer'),
          center: point,
          radius: 2000, // 2km radius
          fillColor: Colors.red.withOpacity(0.1),
          strokeColor: Colors.red.withOpacity(0.3),
          strokeWidth: 1,
        ),
      );

      circles.add(
        Circle(
          circleId: CircleId('heat_${i}_middle'),
          center: point,
          radius: 1000, // 1km radius
          fillColor: Colors.orange.withOpacity(0.2),
          strokeColor: Colors.orange.withOpacity(0.4),
          strokeWidth: 1,
        ),
      );

      circles.add(
        Circle(
          circleId: CircleId('heat_${i}_inner'),
          center: point,
          radius: 500, // 500m radius
          fillColor: Colors.yellow.withOpacity(0.3),
          strokeColor: Colors.yellow.withOpacity(0.5),
          strokeWidth: 2,
        ),
      );
    }

    return circles;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Location Heatmap'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showHeatmap ? Icons.visibility : Icons.visibility_off),
            onPressed: _toggleHeatmap,
            tooltip: _showHeatmap ? 'Hide Heatmap' : 'Show Heatmap',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocationData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              if (_markers.isNotEmpty) {
                _fitMarkersInView();
              }
            },
            markers: _showHeatmap ? {} : _markers,
            circles: _showHeatmap ? _createHeatmapCircles() : {},
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            compassEnabled: true,
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading location data...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Info panel
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total Users: ${_markers.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _showHeatmap ? 'Heatmap View' : 'Marker View',
                    style: TextStyle(
                      color: _showHeatmap ? Colors.red : Colors.blue,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Legend for heatmap
          if (_showHeatmap)
            Positioned(
              bottom: 100,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Heat Intensity',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.yellow.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('High', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('Medium', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('Low', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),

      // Floating action button to toggle view
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "toggle",
            onPressed: _toggleHeatmap,
            backgroundColor: _showHeatmap ? Colors.red : Colors.blue,
            child: Icon(
              _showHeatmap ? Icons.scatter_plot : Icons.whatshot,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "center",
            onPressed: _fitMarkersInView,
            backgroundColor: Colors.green,
            child: const Icon(
              Icons.center_focus_strong,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}