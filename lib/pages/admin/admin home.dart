import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:resqmob/pages/admin/resources/police%20stations.dart';
import 'dart:async';

import '../../backend/firebase config/Authentication.dart';
import '../profile/profile.dart';

class BasicFlutterMapPage extends StatefulWidget {
  const BasicFlutterMapPage({super.key});

  @override
  State<BasicFlutterMapPage> createState() => _BasicFlutterMapPageState();
}

class _BasicFlutterMapPageState extends State<BasicFlutterMapPage> {
  final List<Marker> _markers = [];
  LatLng? _currentPosition;
  late final MapController _mapController;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<Position>? _positionStream;
  bool _isMapReady = false;

  StreamSubscription<QuerySnapshot>? _stationsSubscription;
  StreamSubscription<QuerySnapshot>? _usersSubscription;

  bool _showingStations = false; // Track what type of markers are shown

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeMap();
    _loadAllUserMarkers();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _stationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    try {
      // First check location permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled.';
          _currentPosition = const LatLng(23.769224, 90.425574); // Fallback to Dhaka
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permissions are denied';
            _currentPosition = const LatLng(23.769224, 90.425574); // Fallback to Dhaka
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permissions are permanently denied';
          _currentPosition = const LatLng(23.769224, 90.425574); // Fallback to Dhaka
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _errorMessage = null;
      });

      // Start listening for position updates
      _startLocationTracking();

      await _loadAllUserMarkers();

      // Wait a bit for map to be ready, then fit markers
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && _isMapReady) {
        _fitMarkersInView();
      }

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location: ${e.toString()}';
        _currentPosition = const LatLng(23.769224, 90.425574); // Fallback to Dhaka
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update when moved 10 meters
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      }
    });
  }

  Future<void> _loadAllUserMarkers() async {
    // Cancel any existing subscription
    _stationsSubscription?.cancel();

    try {
      print('Starting to load user markers...');
      _stationsSubscription = await FirebaseFirestore.instance
          .collection('Users')
          .snapshots()
          .listen((QuerySnapshot querySnapshot) {
        if (!mounted) return;

        print('Received ${querySnapshot.docs.length} user documents');
        final List<Marker> loadedMarkers = [];
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        for (var doc in querySnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            final docId = doc.id;
            print('Processing user document $docId: ${data}');

            // Skip current user
            if (docId == currentUserId) {
              print('Skipping current user');
              continue;
            }

            // Location parsing
            final location = data['location'];
            if (location == null) {
              print('No location field found for user $docId');
              continue;
            }

            double? latitude;
            double? longitude;

            // Handle different location data structures
            if (location is Map<String, dynamic>) {
              latitude = location['latitude']?.toDouble();
              longitude = location['longitude']?.toDouble();
            } else if (location is List && location.length >= 2) {
              latitude = location[0]?.toDouble();
              longitude = location[1]?.toDouble();
            }

            print('User $docId - Lat: $latitude, Lng: $longitude');

            if (latitude == null || longitude == null) {
              print('Invalid coordinates for user $docId');
              continue;
            }

            // Validate coordinates
            if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
              print('Invalid coordinate range for user $docId');
              continue;
            }

            final marker = Marker(
              width: 40,
              height: 40,
              point: LatLng(latitude, longitude),
              child: GestureDetector(
                onTap: () => _showUserInfoDialog(data),
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            );
            loadedMarkers.add(marker);
            print('Added marker for user $docId');

          } catch (e) {
            print('Error processing user ${doc.id}: $e');
          }
        }

        print('Total user markers loaded: ${loadedMarkers.length}');

        if (!mounted) return;
        setState(() {
          _markers.clear();
          _markers.addAll(loadedMarkers);
          _showingStations = false;
        });

        // Fit markers to view after update
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isMapReady) {
            print('Fitting user markers to view...');
            _fitMarkersInView();
          }
        });
      },
          onError: (error) {
            print('User markers stream error: $error');
            if (!mounted) return;
            setState(() {
              _errorMessage = 'Error loading users: ${error.toString()}';
            });
          });
    } catch (e) {
      print('User markers setup error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to setup user markers stream: ${e.toString()}';
      });
    }
  }

  Future<void> _loadAllStationMarkers() async {
    // Cancel any existing subscription
    _stationsSubscription?.cancel();

    try {
      print('Starting to load station markers...');
      _stationsSubscription =await FirebaseFirestore.instance
          .collection('/Resources/PoliceStations/Stations')
          .snapshots()
          .listen((QuerySnapshot querySnapshot) {
        if (!mounted) return;

        print('Received ${querySnapshot.docs.length} station documents');
        final List<Marker> loadedMarkers = [];

        for (var doc in querySnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            print('Processing station document ${doc.id}: ${data}');

            // More flexible location parsing
            final location = data['location'];
            if (location == null) {
              print('No location field found for station ${doc.id}');
              continue;
            }

            double? latitude;
            double? longitude;

            // Handle different location data structures
            if (location is Map<String, dynamic>) {
              latitude = location['latitude']?.toDouble();
              longitude = location['longitude']?.toDouble();
            } else if (location is List && location.length >= 2) {
              // Handle array format [lat, lng]
              latitude = location[0]?.toDouble();
              longitude = location[1]?.toDouble();
            }

            print('Station ${doc.id} - Lat: $latitude, Lng: $longitude');

            if (latitude == null || longitude == null) {
              print('Invalid coordinates for station ${doc.id}');
              continue;
            }

            // Validate coordinates are reasonable
            if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
              print('Invalid coordinate range for station ${doc.id}');
              continue;
            }

            final marker = Marker(
              width: 40,
              height: 40,
              point: LatLng(latitude, longitude),
              child: GestureDetector(
                onTap: () => _showUserInfoDialog(data),
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            );
            loadedMarkers.add(marker);
            print('Added marker for station ${doc.id}');

          } catch (e) {
            print('Error processing station ${doc.id}: $e');
          }
        }

        print('Total markers loaded: ${loadedMarkers.length}');

        if (!mounted) return;
        setState(() {
          _markers.clear();
          _markers.addAll(loadedMarkers);
          _showingStations = true;
        });

        // Optionally fit markers to view after update
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isMapReady) {
            print('Fitting markers to view...');
            _fitMarkersInView();
          }
        });
      },
          onError: (error) {
            print('Stream error: $error');
            if (!mounted) return;
            setState(() {
              _errorMessage = 'Error loading stations: ${error.toString()}';
            });
          });
    } catch (e) {
      print('Setup error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to setup station stream: ${e.toString()}';
      });
    }
  }

  void _showUserInfoDialog(Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(userData['stationName'] ?? 'Unknown User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(userData['email'] ?? 'No email available'),
            if (userData['phone'] != null) Text(userData['phone']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _fitMarkersInView() {
    if (!mounted || !_isMapReady) return;

    List<LatLng> points = [];

    // Add all marker points
    for (Marker marker in _markers) {
      points.add(marker.point);
    }

    // Add current position if available
    if (_currentPosition != null) {
      points.add(_currentPosition!);
    }

    if (points.isEmpty) return;

    try {
      if (points.length == 1) {
        // If only one point, center on it
        _mapController.move(points.first, 15.0);
        return;
      }

      // Calculate bounds
      double minLat = points.first.latitude;
      double maxLat = points.first.latitude;
      double minLng = points.first.longitude;
      double maxLng = points.first.longitude;

      for (LatLng point in points) {
        minLat = minLat < point.latitude ? minLat : point.latitude;
        maxLat = maxLat > point.latitude ? maxLat : point.latitude;
        minLng = minLng < point.longitude ? minLng : point.longitude;
        maxLng = maxLng > point.longitude ? maxLng : point.longitude;
      }

      // Add some padding to bounds
      double latPadding = (maxLat - minLat) * 0.1;
      double lngPadding = (maxLng - minLng) * 0.1;

      LatLngBounds bounds = LatLngBounds(
        LatLng(minLat - latPadding, minLng - lngPadding),
        LatLng(maxLat + latPadding, maxLng + lngPadding),
      );

      _mapController.fitBounds(
        bounds,
        options: const FitBoundsOptions(
          padding: EdgeInsets.all(50),
          maxZoom: 17.0,
        ),
      );
    } catch (e) {
      debugPrint('Error fitting bounds: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map View'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _initializeMap();
            },
          ),
          SizedBox(width: 16,),
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection("Users")
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  child: CircularProgressIndicator(
                    padding: EdgeInsets.all(13),
                    strokeWidth: 0.7,
                  ),
                );
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return InkWell(
                  splashFactory: NoSplash.splashFactory,
                  radius: 50,
                  onTap: (){

                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[300],
                    child: Icon(Icons.person, size: 20, color: Colors.white),
                  ),
                );
              }
              String? imageUrl = snapshot.data!.get("profileImageUrl");
              return PopupMenuButton<int>(
                color: Colors.white,
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                elevation: 2,
                itemBuilder: (context) => [
                  PopupMenuItem<int>(
                    value: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const SizedBox(
                      width: 120,
                      child: Row(
                        children: [
                          Text("Your Profile",
                              style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuItem<int>(
                    value: 1,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const SizedBox(
                      width: 120,
                      child: Row(
                        children: [

                          Text("Sign Out",
                              style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 0) {
                    if (FirebaseAuth.instance.currentUser != null) {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => profile(
                              uid: FirebaseAuth.instance.currentUser!.uid
                          )
                      ));
                    }
                  } else if (value == 1) {
                    Authentication().signout(context);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                        ? NetworkImage(imageUrl)
                        : null,
                    backgroundColor: Colors.grey[300],
                    child: (imageUrl == null || imageUrl.isEmpty)
                        ? Icon(Icons.person, size: 20, color: Colors.white)
                        : null,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildMapContent(),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "toggle_markers",
            onPressed: (){
              Navigator.push(context, MaterialPageRoute(
                  builder: (context) => AddPoliceStations()
              ));
            },
            backgroundColor: _showingStations ? Colors.red : Colors.blue,
            child: Icon(
              _showingStations ? Icons.people : Icons.local_police_outlined,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "center_markers",
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

  Widget _buildMapContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!),
            ElevatedButton(
              onPressed: _initializeMap,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Map Layer
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            center: _currentPosition ?? const LatLng(23.769224, 90.425574),
            zoom: 14,
            onMapReady: () {
              _isMapReady = true;
              Future.delayed(const Duration(milliseconds: 100), () {
                _fitMarkersInView();
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.resqmob',
            ),
            MarkerLayer(
              markers: [
                if (_currentPosition != null)
                  Marker(
                    width: 40,
                    height: 40,
                    point: _currentPosition!,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ..._markers,
              ],
            ),
          ],
        ),

        // Compact Bottom Controls
        Positioned(
          bottom: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCompactButton('Stations', _loadAllStationMarkers),
                const SizedBox(width: 8),
                _buildCompactButton('Users', _loadAllUserMarkers),
                const SizedBox(width: 8),
                _buildCompactButton('HQ', () {}),
              ],
            ),
          ),
        ),
      ],
    );


  }
  Widget _buildCompactButton(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF333333),
        ),
      ),
    );
  }
}



