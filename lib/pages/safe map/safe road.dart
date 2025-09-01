import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:hugeicons/hugeicons.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:resqmob/backend/api%20keys.dart';
import 'package:resqmob/pages/safe%20map/safety%20module.dart';
import '../../Class Models/Danger zone.dart';
import '../../Class Models/user.dart';
import '../homepage/drawer.dart';

class SafetyMap extends StatefulWidget {
  final UserModel? currentUser;
  const SafetyMap({Key? key, required this.currentUser}) : super(key: key);

  @override
  _SafetyMapState createState() => _SafetyMapState();
}

class _SafetyMapState extends State<SafetyMap> with TickerProviderStateMixin {
  // Controllers and Completers
  final Completer<GoogleMapController> _controller = Completer();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final DraggableScrollableController _draggableController =
  DraggableScrollableController();

  // Animation Controllers (Only keep necessary ones)
  late AnimationController _routeLoadingController;
  late Animation<double> _routeLoadingAnimation;

  int selectedRouteIndex = 0;
  Timer? _debounceTimer;
  bool _isSearchExpanded = true; // NEW: Search box toggle state

  // Google API Key
  String googleApiKey = apiKey.getKey();

  // Map and Location Variables
  GoogleMapController? mapController;
  Position? currentPosition;
  LatLng? destinationLocation;
  List<DangerZone> dangerZones = [];
  Set<Circle> circles = {};
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  List<PlaceSuggestion> suggestions = [];
  bool showSuggestions = false;
  bool showcircle = true;

  // *** NEW STATE FOR NAVIGATION ***
  bool _isNavigating = false;
  bool isLoading = false;
  List<RouteInfo> availableRoutes = [];

  // Professional color scheme
  static const Color primaryColor = Color(0xff25282b);
  static const Color secondaryColor = Color(0xFF059669);
  static const Color surfaceColor = Color(0xFFD5C4A1);
  static const Color errorColor = Color(0xFFDC2626);
  static const Color warningColor = Color(0xFFF59E0B);

  // Initial camera position - Dhaka, Bangladesh
  static const CameraPosition _kDhakaPosition = CameraPosition(
    target: LatLng(23.8103, 90.4125),
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    _initializeAnimations(); // Only initialize necessary animations
    _getCurrentLocation();
    _initializeDataFromFirebase();
    _searchFocusNode.addListener(() {
      setState(() {
        showSuggestions =
            _searchFocusNode.hasFocus && suggestions.isNotEmpty;
      });
    });
  }

  void _initializeAnimations() {
    _routeLoadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _routeLoadingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _routeLoadingController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _routeLoadingController.dispose();
    super.dispose();
  }

  // NEW: Toggle search box visibility
  void _toggleSearchBox() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (!_isSearchExpanded) {
        // Collapse search
        showSuggestions = false;
        _searchFocusNode.unfocus();
      }
    });
  }

  // Get current location (keeping your existing implementation)
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Location services are disabled', warningColor);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permission denied', errorColor);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permission permanently denied', errorColor);
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      setState(() {
        currentPosition = position;
      });
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15.0,
          ),
        ),
      );
    } catch (e) {
      print('Error getting location: $e');
      _showSnackBar('Could not get location', errorColor);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(
              color == errorColor
                  ? Icons.error_outline
                  : color == warningColor
                  ? Icons.warning_outlined
                  : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Search places (keeping your existing implementation but with improved loading)
  void _searchPlaces(String query) {
    if (query.isEmpty) {
      setState(() {
        suggestions.clear();
        showSuggestions = false;
      });
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchPlaceSuggestions(query);
    });
  }

  Future<void> _fetchPlaceSuggestions(String query) async {
    setState(() {
      isLoading = true;
    });
    try {
      String baseUrl =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json';
      String request =
          '$baseUrl?input=${Uri.encodeQueryComponent(query)}'
          '&key=$googleApiKey'
          '&components=country:bd'
          '&types=establishment|geocode'
          '&fields=place_id,description,structured_formatting'
          '&language=en';
      if (currentPosition != null) {
        request +=
        '&location=${currentPosition!.latitude},${currentPosition!.longitude}'
            '&radius=50000';
      }
      final response = await http.get(
        Uri.parse(request),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          List<PlaceSuggestion> newSuggestions = [];
          for (var prediction in data['predictions']) {
            newSuggestions.add(
              PlaceSuggestion(
                placeId: prediction['place_id'],
                description: prediction['description'],
                mainText: prediction['structured_formatting']['main_text'],
                secondaryText:
                prediction['structured_formatting']['secondary_text'] ??
                    '',
                types: List<String>.from(prediction['types'] ?? []),
              ),
            );
          }
          setState(() {
            suggestions = newSuggestions;
            showSuggestions =
                suggestions.isNotEmpty && _searchFocusNode.hasFocus;
            isLoading = false;
          });
        } else {
          String errorMessage = 'Search failed: ${data['status']}';
          if (data['error_message'] != null) {
            errorMessage += ' - ${data['error_message']}';
          }
          _showSnackBar(errorMessage, errorColor);
          setState(() {
            isLoading = false;
            suggestions.clear();
            showSuggestions = false;
          });
        }
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      _showSnackBar('Network error: ${e.toString()}', errorColor);
      setState(() {
        isLoading = false;
        suggestions.clear();
        showSuggestions = false;
      });
    }
  }

  Future<void> _initializeDataFromFirebase() async {
    print(dangerZones.toString());
    print(circles.toString());
    try {
      // 1. Get reference to the Firestore collection
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Resources/DangerPoints/dangerpoints')
          .get();
      if (snapshot.docs.isEmpty) {
        print("No data found in Firestore.");
        setState(() => isLoading = false);
        return;
      }
      // 2. Create temporary lists to hold the fetched data
      final List<DangerZone> fetchedZones = [];
      final Set<Circle> fetchedCircles = {};

      // 3. Loop through documents and populate the lists
      for (var i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        final data = doc.data() as Map<String, dynamic>;
        // Create a DangerZone object
        final zone = DangerZone.fromJson(data);
        fetchedZones.add(zone);
        // Create a corresponding Circle object
        fetchedCircles.add(
          Circle(
            circleId: CircleId('dz_$i'), // Unique ID for each circle
            center: LatLng(zone.lat, zone.lon),
            radius: zone.radius,
            fillColor: Colors.yellow.withOpacity(0.2),
            strokeColor: Colors.red.withOpacity(0.2),
            strokeWidth: 20,
          ),
        );
      }
      // 4. Update the state to reflect the fetched data
      setState(() {
        dangerZones = fetchedZones;
        circles = fetchedCircles;
        isLoading = false;
      });
    } catch (e) {
      print("Error initializing data: $e");
      setState(() => isLoading = false);
      // Optionally, show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load map data.')),
      );
    }
  }

  // Keep your existing _selectPlace, _initializeDataFromFirebase, and _getDirections methods
  // (I'm keeping them the same but with improved UI feedback)
  Future<void> _getDirections() async {
    _getCurrentLocation();
    if (currentPosition == null || destinationLocation == null) return;
    try {
      setState(() {
        polylines.clear();
        availableRoutes.clear();
        _isNavigating = false; // Reset navigation state
      });
      _showSnackBar('Finding routes...', Colors.black);
      // Strategy 1: Make 2-3 concurrent requests with different parameters
      List<Future<List<RouteInfo>>> routeRequests = [
        // Primary request - fastest/default
        _getSingleRouteSet({
          'avoid': '',
          'description': 'Fastest routes',
          'priority': 1
        }),
        // Secondary request - avoid tolls (most common alternative)
        _getSingleRouteSet({
          'avoid': 'tolls',
          'description': 'Toll-free routes',
          'priority': 2
        }),
      ];
      // Add third request only for longer distances
      double distanceKm = _getDistanceKm();
      if (distanceKm > 5) {
        routeRequests.add(_getSingleRouteSet({
          'avoid': 'highways',
          'description': 'Local roads',
          'priority': 3
        }));
      }
      // Execute all requests concurrently with timeout
      List<List<RouteInfo>> allRouteLists = await Future.wait(
        routeRequests,
        eagerError: false, // Continue even if some requests fail
      ).timeout(
        Duration(seconds: 10), // Overall timeout
        onTimeout: () => routeRequests.map((e) => <RouteInfo>[]).toList(),
      );
      // Combine and deduplicate routes
      Set<String> uniquePolylines = <String>{};
      List<RouteInfo> allRoutes = [];
      for (List<RouteInfo> routeList in allRouteLists) {
        for (RouteInfo route in routeList) {
          // Use a simplified polyline hash for deduplication
          String routeHash = _generateRouteHash(route.points);
          if (!uniquePolylines.contains(routeHash)) {
            uniquePolylines.add(routeHash);
            // Create new RouteInfo with updated index
            RouteInfo updatedRoute = RouteInfo(
              routeIndex: allRoutes.length,
              distance: route.distance,
              duration: route.duration,
              summary: route.summary,
              points: route.points,
              safetyPercentage: route.safetyPercentage,
              totalDistance: route.totalDistance,
            );
            allRoutes.add(updatedRoute);
          }
        }
      }
      // Sort routes by priority (fastest first, then by safety)
      allRoutes.sort((a, b) {
        // Extract priority from summary (hack, but works)
        int priorityA = a.summary.contains('Fastest')
            ? 1
            : a.summary.contains('Toll-free')
            ? 2
            : 3;
        int priorityB = b.summary.contains('Fastest')
            ? 1
            : b.summary.contains('Toll-free')
            ? 2
            : 3;
        if (priorityA != priorityB) return priorityA.compareTo(priorityB);
        // Within same priority, sort by safety percentage (higher first)
        return b.safetyPercentage.compareTo(a.safetyPercentage);
      });
      // Limit to maximum 8 routes to keep UI manageable
      if (allRoutes.length > 8) {
        allRoutes = allRoutes.sublist(0, 8);
      }
      // Update UI
      setState(() {
        availableRoutes = allRoutes;
        // Add polylines with distinct colors
        _updatePolylines(); // Use helper to manage polyline display
      });
      if (allRoutes.isNotEmpty) {
        _showSnackBar('${allRoutes.length} routes found', Colors.green);
        print('Found ${allRoutes.length} unique routes');
      } else {
        _showSnackBar('No routes found', Colors.orange);
      }
    } catch (e) {
      print('Error getting directions: ${e.toString()}');
      _showSnackBar('Error getting directions: ${e.toString()}', Colors.red);
    }
  }

  // *** HELPER TO MANAGE POLYLINE DISPLAY ***
  void _updatePolylines() {
    Set<Polyline> newPolylines = <Polyline>{};
    List<Color> routeColors = [
      primaryColor, // Primary (Selected)
      Colors.green, // Secondary
      Colors.orange, // Third
      Colors.purple, // Fourth
      Colors.red, // Fifth
      Colors.teal, // Sixth
      Colors.brown, // Seventh
      Colors.pink, // Eighth
    ];

    if (_isNavigating && selectedRouteIndex < availableRoutes.length) {
      // Show only the selected route when navigating
      RouteInfo selectedRoute = availableRoutes[selectedRouteIndex];
      newPolylines.add(
        Polyline(
          polylineId: PolylineId('route_${selectedRoute.routeIndex}'),
          points: selectedRoute.points,
          color: primaryColor, // Highlight selected route
          width: 6,
        ),
      );
    } else {
      // Show all available routes (default view)
      for (int i = 0; i < availableRoutes.length; i++) {
        RouteInfo route = availableRoutes[i];
        newPolylines.add(
          Polyline(
            polylineId: PolylineId('route_${route.routeIndex}'),
            points: route.points,
            color: routeColors[i % routeColors.length],
            width: i == selectedRouteIndex ? 6 : 4,
            patterns: i == selectedRouteIndex
                ? []
                : [PatternItem.dash(10), PatternItem.gap(5)],
          ),
        );
      }
    }
    setState(() {
      polylines = newPolylines;
    });
  }


// Helper function to get routes from a single API request
  Future<List<RouteInfo>> _getSingleRouteSet(Map<String, dynamic> params) async {
    List<RouteInfo> routes = [];
    try {
      String baseUrl =
          'https://maps.googleapis.com/maps/api/directions/json';
      String request =
          '$baseUrl?origin=${currentPosition!.latitude},${currentPosition!.longitude}'
          '&destination=${destinationLocation!.latitude},${destinationLocation!.longitude}'
          '&alternatives=true'
          '&region=bd'
          '&language=en'
          '&traffic_model=best_guess'
          '&departure_time=now'
          '&key=$googleApiKey';
      if (params['avoid']?.isNotEmpty == true) {
        request += '&avoid=${params['avoid']}';
      }
      print('API Request (${params['description']}): $request');
      final response = await http.get(Uri.parse(request)).timeout(
        Duration(seconds: 8), // Individual request timeout
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'] != null) {
          for (int i = 0; i < data['routes'].length; i++) {
            try {
              var route = data['routes'][i];
              String encodedPolyline = route['overview_polyline']['points'];
              List<LatLng> routePoints = _decodePolyline(encodedPolyline);
              var leg = route['legs'][0];
              String distance = leg['distance']['text'] ?? 'Unknown';
              String duration = leg['duration']['text'] ?? 'Unknown';
              String summary =
                  '${params['description']} - ${route['summary'] ?? 'Route ${i + 1}'}';
              // Quick safety calculation (simplified for speed)
              double safetyPercentage = 100.0;
              double totalDistance = 0.0;
              try {
                // Use faster calculation if available, or fallback
                if (dangerZones.isEmpty) {
                  // No danger zones, skip safety calculation
                  totalDistance = _calculateFallbackDistance(routePoints);
                } else {
                  // Quick safety check (sample every 10th point for speed)
                  Map<String, dynamic> safetyInfo =
                  _quickSafetyCalculation(routePoints, dangerZones);
                  safetyPercentage = (safetyInfo['safety_percentage'] ??
                      100.0)
                      .toDouble()
                      .clamp(0.0, 100.0);
                  totalDistance = (safetyInfo['total_distance'] ??
                      _calculateFallbackDistance(routePoints))
                      .toDouble();
                }
              } catch (e) {
                safetyPercentage = 100.0;
                totalDistance = _calculateFallbackDistance(routePoints);
              }
              RouteInfo routeInfo = RouteInfo(
                routeIndex: i,
                distance: distance,
                duration: duration,
                summary: summary,
                points: routePoints,
                safetyPercentage: safetyPercentage,
                totalDistance: totalDistance,
              );
              routes.add(routeInfo);
            } catch (routeError) {
              print('Error processing route $i: $routeError');
              continue;
            }
          }
        }
      }
    } catch (e) {
      print('Error in ${params['description']} request: $e');
    }
    return routes;
  }

// Fast safety calculation (samples points instead of checking every segment)
  Map<String, dynamic> _quickSafetyCalculation(
      List<LatLng> polyline, List<DangerZone> dangerZones) {
    if (polyline.length < 2) {
      return {'safety_percentage': 100.0, 'total_distance': 0.0};
    }
    double totalDistance = _calculateFallbackDistance(polyline);
    // Sample every 10th point or minimum 10 points for speed
    int sampleStep = math.max(1, polyline.length ~/ 10);
    double unsafeDistance = 0.0;
    for (int i = 0; i < polyline.length - sampleStep; i += sampleStep) {
      LatLng point1 = polyline[i];
      LatLng point2 = polyline[
      math.min(i + sampleStep, polyline.length - 1)];
      double segmentDistance = haversineDistance(point1, point2);
      // Check if this segment intersects any danger zone
      for (DangerZone zone in dangerZones) {
        LatLng zoneCenter = LatLng(zone.lat, zone.lon);
        if (segmentIntersectsCircle(
            point1, point2, zoneCenter, zone.radius)) {
          unsafeDistance += math.min(segmentDistance, zone.radius * 2);
          break;
        }
      }
    }
    double safetyPercentage = totalDistance > 0
        ? ((totalDistance - unsafeDistance) / totalDistance) * 100
        : 100.0;
    return {
      'safety_percentage': math.max(0, math.min(100, safetyPercentage)),
      'total_distance': totalDistance,
    };
  }

// Generate a simple hash for route deduplication
  String _generateRouteHash(List<LatLng> points) {
    if (points.length < 4) return points.toString();
    // Use start, two middle points, and end for quick comparison
    int mid1 = points.length ~/ 3;
    int mid2 = (points.length * 2) ~/ 3;
    return '${points.first.latitude.toStringAsFixed(4)}_${points.first.longitude.toStringAsFixed(4)}_'
        '${points[mid1].latitude.toStringAsFixed(4)}_${points[mid1].longitude.toStringAsFixed(4)}_'
        '${points[mid2].latitude.toStringAsFixed(4)}_${points[mid2].longitude.toStringAsFixed(4)}_'
        '${points.last.latitude.toStringAsFixed(4)}_${points.last.longitude.toStringAsFixed(4)}';
  }

// Helper function to calculate distance between current position and destination
  double _getDistanceKm() {
    if (currentPosition == null || destinationLocation == null) return 0;
    return haversineDistance(
        LatLng(currentPosition!.latitude, currentPosition!.longitude),
        destinationLocation!) /
        1000;
  }

// Helper function to calculate fallback distance
  double _calculateFallbackDistance(List<LatLng> routePoints) {
    if (routePoints.length < 2) return 0.0;
    double distance = 0.0;
    for (int i = 0; i < routePoints.length - 1; i++) {
      distance += haversineDistance(routePoints[i], routePoints[i + 1]);
    }
    return distance;
  }

  // Decode polyline string to LatLng points
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polylinePoints = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      polylinePoints.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polylinePoints;
  }

  // Move camera to show both current location and destination
  void _moveCameraToShowBothLocations() async {
    if (currentPosition == null || destinationLocation == null) return;
    final GoogleMapController controller = await _controller.future;
    double minLat =
    math.min(currentPosition!.latitude, destinationLocation!.latitude);
    double maxLat =
    math.max(currentPosition!.latitude, destinationLocation!.latitude);
    double minLng =
    math.min(currentPosition!.longitude, destinationLocation!.longitude);
    double maxLng =
    math.max(currentPosition!.longitude, destinationLocation!.longitude);
    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  Future<void> _selectPlace(PlaceSuggestion suggestion) async {
    setState(() {
      showSuggestions = false;
      isLoading = true;
    });
    _routeLoadingController.repeat();
    _searchController.text = suggestion.mainText;
    _searchFocusNode.unfocus();
    try {
      String baseUrl =
          'https://maps.googleapis.com/maps/api/place/details/json';
      String request = '$baseUrl?place_id=${suggestion.placeId}'
          '&key=$googleApiKey'
          '&fields=name,formatted_address,geometry';
      final response = await http
          .get(Uri.parse(request))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          final name = data['result']['name'] ?? suggestion.mainText;
          final address =
              data['result']['formatted_address'] ?? suggestion.description;
          destinationLocation = LatLng(location['lat'], location['lng']);
          setState(() {
            markers.removeWhere(
                    (marker) => marker.markerId.value == 'destination');
            markers.add(
              Marker(
                markerId: const MarkerId('destination'),
                position: destinationLocation!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(
                  title: name,
                  snippet: address,
                ),
              ),
            );
          });
          if (currentPosition != null) {
            await _getDirections();
          } else {
            _showSnackBar('Destination selected', primaryColor);
          }
          if (currentPosition != null) {
            _moveCameraToShowBothLocations();
          } else {
            final GoogleMapController controller = await _controller.future;
            controller.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: destinationLocation!, zoom: 15.0),
              ),
            );
          }
        } else {
          _showSnackBar(
              'Failed to get place details: ${data['status']}', errorColor);
        }
      }
    } catch (e) {
      print('Error selecting place: $e');
      _showSnackBar('Error selecting place: ${e.toString()}', errorColor);
    } finally {
      setState(() {
        isLoading = false;
      });
      _routeLoadingController.stop();
    }
  }

  // *** NEW METHOD TO START NAVIGATION ***
  void _startNavigation() {
    if (availableRoutes.isEmpty) return;
    setState(() {
      _isNavigating = true;
    });
    _updatePolylines(); // Update map to show only the selected route
    // You can add actual navigation logic here (e.g., turn-by-turn instructions)
    _showSnackBar('Navigation started!', secondaryColor);
  }

  // *** METHOD TO STOP NAVIGATION ***
  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
    });
    _updatePolylines(); // Show all routes again
    _showSnackBar('Navigation stopped.', primaryColor);
  }

  // Keep your existing Firebase and direction methods but add the improved UI methods below
  Widget _buildCustomAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          right: 20,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.white.withOpacity(0.9),
              Colors.white.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [

            const SizedBox(width: 50),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Safe Map',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Navigate to the safest route',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildSearchContainer() {
    return Positioned(
      top: 100, // Fixed position
      left: 20,
      right: 20,
      child: Column(
        children: [
          // NEW: Toggle button for search box
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _toggleSearchBox,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _isSearchExpanded ? Icons.expand_less : Icons.search,
                  color: primaryColor,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Search box (conditionally visible)
          if (_isSearchExpanded) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Where would you like to go?',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.search_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _clearSearch,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.clear_rounded,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                      ),
                    ),
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                onChanged: _searchPlaces,
              ),
            ),
            // Enhanced Suggestions List
            if (showSuggestions) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: suggestions.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Colors.grey.shade200,
                      indent: 60,
                    ),
                    itemBuilder: (context, index) {
                      final suggestion = suggestions[index];
                      IconData icon = _getPlaceIcon(suggestion.types);
                      return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _selectPlace(suggestion),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      icon,
                                      color: primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          suggestion.mainText,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                        if (suggestion.secondaryText.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            suggestion.secondaryText,
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.grey.shade400,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ));
                      }
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  IconData _getPlaceIcon(List<String> types) {
    if (types.contains('restaurant') || types.contains('meal_takeaway')) {
      return Icons.restaurant_rounded;
    } else if (types.contains('hospital')) {
      return Icons.local_hospital_rounded;
    } else if (types.contains('school') || types.contains('university')) {
      return Icons.school_rounded;
    } else if (types.contains('shopping_mall')) {
      return Icons.shopping_bag_rounded;
    } else if (types.contains('gas_station')) {
      return Icons.local_gas_station_rounded;
    }
    return Icons.place_rounded;
  }

  Widget _buildRoutePanel() {
    // Simplified panel logic
    if (availableRoutes.isEmpty) {
      return const SizedBox.shrink(); // Don't show if no routes
    }

    return DraggableScrollableSheet(
      controller: _draggableController,
      initialChildSize: 0.15,
      minChildSize: 0.15,
      maxChildSize: _isNavigating ? 0.3 : 0.6, // Adjust max size based on state
      snap: true,
      snapSizes: _isNavigating
          ? const [0.15, 0.3]
          : const [0.15, 0.4, 0.6], // Different snap sizes for navigation
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Content
              Expanded(
                child: _isNavigating
                    ? _buildNavigationState(scrollController)
                    : _buildRouteSelectionState(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteSelectionState(ScrollController scrollController) {
    // Show route selection UI
    final selectedRoute = availableRoutes[selectedRouteIndex];
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Header with selected route info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected Route',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getSafetyColor(selectedRoute.safetyPercentage),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${selectedRoute.safetyPercentage.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildQuickStat(Icons.directions_rounded, selectedRoute.distance, 'Distance'),
                  const SizedBox(width: 20),
                  _buildQuickStat(Icons.access_time_rounded, selectedRoute.duration, 'Duration'),
                  const SizedBox(width: 20),
                  _buildQuickStat(Icons.security_rounded, _getSafetyRating(selectedRoute.safetyPercentage), 'Safety'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startNavigation,
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('Start Navigation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Route cards for switching
        Text(
          'Other Routes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: availableRoutes.length,
            itemBuilder: (context, index) {
              if (index == selectedRouteIndex) return const SizedBox.shrink(); // Hide selected in list
              final route = availableRoutes[index];
              final safetyColor = _getSafetyColor(route.safetyPercentage);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedRouteIndex = index;
                    _updatePolylines(); // Update map when route changes
                  });
                },
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Safety badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: safetyColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.security_rounded,
                                size: 12,
                                color: safetyColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${route.safetyPercentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: safetyColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Route info
                        Text(
                          route.distance,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          route.duration,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),
                        // Route type indicator
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getRouteTypeFromSummary(route.summary),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildNavigationState(ScrollController scrollController) {
    // Show minimal navigation UI
    final selectedRoute = availableRoutes[selectedRouteIndex];
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Navigating',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getSafetyColor(selectedRoute.safetyPercentage),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${selectedRoute.safetyPercentage.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildQuickStat(Icons.directions_rounded, selectedRoute.distance, 'Distance'),
                  const SizedBox(width: 20),
                  _buildQuickStat(Icons.access_time_rounded, selectedRoute.duration, 'Duration'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _stopNavigation, // Stop navigation button
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop Navigation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: errorColor, // Red stop button
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStat(IconData icon, String value, String label) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalControlButtons() {
    return Positioned(
      bottom: availableRoutes.isNotEmpty ? 140 : 40,
        right: 16,
      child: Column(
        children: [
          FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () {
              setState(() {
                showcircle = !showcircle;
              });
            },
            heroTag: "toggle_danger_points",
            child: HugeIcon(
              icon: showcircle
                  ? HugeIcons.strokeRoundedView
                  : HugeIcons.strokeRoundedViewOffSlash,
              color:showcircle
                  ? Colors.red : Colors.black,
            ),
          ),

          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: _getCurrentLocation,
            heroTag: "location_3",
            child: HugeIcon(icon:HugeIcons.strokeRoundedGps01 , color: Colors.black),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () async {
              final GoogleMapController controller = await _controller.future;
              controller.animateCamera(
                CameraUpdate.newCameraPosition(_kDhakaPosition),
              );
            },
            heroTag: "location_4",
            child:HugeIcon(icon:HugeIcons.strokeRoundedMapsLocation02 , color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalLoadingIndicator() {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _routeLoadingAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _routeLoadingAnimation.value * 2 * math.pi,
                        child: Icon(
                          Icons.route_rounded,
                          color: primaryColor,
                          size: 24,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Finding optimal routes...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Analyzing safety data',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Keep all your existing helper methods but update the colors and styling
  void _clearSearch() {
    setState(() {
      availableRoutes.clear();
      _searchController.clear();
      suggestions.clear();
      showSuggestions = false;
      destinationLocation = null;
      polylines.clear();
      availableRoutes.clear;
      markers.removeWhere((marker) => marker.markerId.value == 'destination');
      _isNavigating = false; // Stop navigation if search is cleared
    });
  }

  // Removed _selectRoute method (handled by _updatePolylines and direct setState)
  Color _getSafetyColor(double percentage) {
    if (percentage >= 80) return const Color(0xFF059669); // Green
    if (percentage >= 60) return const Color(0xFF0891B2); // Teal
    if (percentage >= 40) return const Color(0xFFF59E0B); // Yellow
    if (percentage >= 20) return const Color(0xFFEA580C); // Orange
    return const Color(0xFFDC2626); // Red
  }

  String _getSafetyRating(double percentage) {
    if (percentage >= 80) return 'Very Safe';
    if (percentage >= 60) return 'Safe';
    if (percentage >= 40) return 'Moderate';
    if (percentage >= 20) return 'Risky';
    return 'Dangerous';
  }

  String _getRouteTypeFromSummary(String summary) {
    if (summary.toLowerCase().contains('fastest')) return 'Fastest';
    if (summary.toLowerCase().contains('toll')) return 'Toll-free';
    if (summary.toLowerCase().contains('highway')) return 'Highway';
    if (summary.toLowerCase().contains('local')) return 'Local Roads';
    return 'Alternative';
  }

  // Keep your existing API methods (_initializeDataFromFirebase, _getDirections, etc.)
  // but update any UI feedback to use the new professional styling
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        activePage: 1,
        currentUser: widget.currentUser,
      ),
      backgroundColor: surfaceColor,
      body: Stack(
        children: [
          // Google Map with enhanced styling
          GoogleMap(
            style: '''
            [
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#ebe3cd"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#523735"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#f5f1e6"
      }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#c9b2a6"
      }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#dcd2be"
      }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#ae9e90"
      }
    ]
  },
  {
    "featureType": "landscape.natural",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#dfd2ae"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#dfd2ae"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#93817c"
      }
    ]
  },
  {
    "featureType": "poi.business",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#a5b076"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#447530"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#f5f1e6"
      }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#fdfcf8"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#f8c967"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#e9bc62"
      }
    ]
  },
  {
    "featureType": "road.highway.controlled_access",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#e98d58"
      }
    ]
  },
  {
    "featureType": "road.highway.controlled_access",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#db8555"
      }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#806b63"
      }
    ]
  },
  {
    "featureType": "transit.line",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#dfd2ae"
      }
    ]
  },
  {
    "featureType": "transit.line",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8f7d77"
      }
    ]
  },
  {
    "featureType": "transit.line",
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#ebe3cd"
      }
    ]
  },
  {
    "featureType": "transit.station",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#dfd2ae"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#b9d3c2"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#92998d"
      }
    ]
  }
]
            ''',
            mapType: MapType.normal,
            initialCameraPosition: _kDhakaPosition,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              mapController = controller;
            },
            markers: markers,
            circles:showcircle? circles: {},
            polylines: polylines, // Polylines managed by _updatePolylines
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            trafficEnabled: false,
          ),

          _buildCustomAppBar(),
          // Search (conditionally visible)
          _buildSearchContainer(),
          // Enhanced control buttons
          _buildMinimalControlButtons(),
          // Professional loading indicator
          if (isLoading) _buildProfessionalLoadingIndicator(),
          // Route panel (simplified and context-aware)
          if (availableRoutes.isNotEmpty) _buildRoutePanel(),
        ],
      ),
    );
  }
}

// Place suggestion model
class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final List<String> types;
  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    required this.types,
  });
}

// Route information model
class RouteInfo {
  final int routeIndex;
  final String distance;
  final String duration;
  final String summary;
  final List<LatLng> points;
  final double safetyPercentage; // Add this
  final double totalDistance; // Add this
  RouteInfo({
    required this.routeIndex,
    required this.distance,
    required this.duration,
    required this.summary,
    required this.points,
    required this.safetyPercentage, // Add this
    required this.totalDistance, // Add this
  });
}

//
// final firestore = FirebaseFirestore.instance;
// final collectionRef = firestore.collection('Resources/DangerPoints/dangerpoints');
//
// print("Checking for existing data in 'danger_zones' collection...");
//
// // SAFETY CHECK: Prevents re-uploading if data already exists.
// final snapshot = await collectionRef.limit(1).get();
// if (snapshot.docs.isNotEmpty) {
// print("Data already exists in the 'danger_zones' collection. Aborting upload.");
// return;
// }
//
// print("No existing data found. Starting batch upload...");
//
// // A batch write is more efficient for multiple operations.
// final batch = firestore.batch();
//
// for (final zone in dangerZones) {
//
// final docRef = collectionRef.doc();
// // Add the set operation to the batch.
// batch.set(docRef, zone.toJson());
// }
//
// try {
// // Commit the batch to Firestore.
// await batch.commit();
// print("✅ Success: Uploaded ${dangerZones.length} danger zones to Firestore.");
// } catch (e) {
// print("❌ Error during batch upload: $e");
// }





// List<DangerZone> dangerZones = [DangerZone(lat: 23.767210638688493, lon: 90.35838621347095, radius: 50.0),
//   DangerZone(lat: 23.769512, lon: 90.359721, radius: 50.0),
//   DangerZone(lat: 23.765932, lon: 90.357254, radius: 50.0),
//   DangerZone(lat: 23.770821, lon: 90.360892, radius: 50.0),
//   DangerZone(lat: 23.766182, lon: 90.361224, radius: 50.0),
//   DangerZone(lat: 23.768415, lon: 90.362918, radius: 50.0),
//   DangerZone(lat: 23.764892, lon: 90.359442, radius: 50.0),
//   DangerZone(lat: 23.769942, lon: 90.356731, radius: 50.0),
//   DangerZone(lat: 23.771255, lon: 90.358415, radius: 50.0),
//   DangerZone(lat: 23.763875, lon: 90.358754, radius: 50.0),
//   DangerZone(lat: 23.768622, lon: 90.354981, radius: 50.0),
//   DangerZone(lat: 23.772104, lon: 90.360214, radius: 50.0),
//   DangerZone(lat: 23.767985, lon: 90.363842, radius: 50.0),
//   DangerZone(lat: 23.765214, lon: 90.362155, radius: 50.0),
//   DangerZone(lat: 23.769451, lon: 90.363112, radius: 50.0),
//   DangerZone(lat: 23.770942, lon: 90.355915, radius: 50.0),
//   DangerZone(lat: 23.764385, lon: 90.355842, radius: 50.0),
//   DangerZone(lat: 23.773125, lon: 90.358722, radius: 50.0),
//   DangerZone(lat: 23.762985, lon: 90.360145, radius: 50.0),
//   DangerZone(lat: 23.771925, lon: 90.362215, radius: 50.0),
//   DangerZone(lat: 23.765732, lon: 90.364421, radius: 50.0),
//   DangerZone(lat: 23.861233, lon: 90.366754, radius: 50.0),
//   DangerZone(lat: 23.858012, lon: 90.366184, radius: 50.0),
//   DangerZone(lat: 23.860721, lon: 90.367892, radius: 50.0),
//   DangerZone(lat: 23.857182, lon: 90.363224, radius: 50.0),
//   DangerZone(lat: 23.862415, lon: 90.368918, radius: 50.0),
//   DangerZone(lat: 23.857892, lon: 90.361442, radius: 50.0),
//   DangerZone(lat: 23.861942, lon: 90.362731, radius: 50.0),
//   DangerZone(lat: 23.863255, lon: 90.364415, radius: 50.0),
//   DangerZone(lat: 23.857875, lon: 90.364754, radius: 50.0),
//   DangerZone(lat: 23.859622, lon: 90.361981, radius: 50.0),
//   DangerZone(lat: 23.863104, lon: 90.367214, radius: 50.0),
//   DangerZone(lat: 23.859985, lon: 90.369842, radius: 50.0),
//   DangerZone(lat: 23.857214, lon: 90.368155, radius: 50.0),
//   DangerZone(lat: 23.861451, lon: 90.369112, radius: 50.0),
//   DangerZone(lat: 23.862942, lon: 90.362915, radius: 50.0),
//   DangerZone(lat: 23.858385, lon: 90.362842, radius: 50.0),
//   DangerZone(lat: 23.864125, lon: 90.365722, radius: 50.0),
//   DangerZone(lat: 23.859985, lon: 90.370145, radius: 50.0),
//   DangerZone(lat: 23.861925, lon: 90.367215, radius: 50.0),
//   DangerZone(lat: 23.858422, lon: 90.366721, radius: 50.0),
//   DangerZone(lat: 23.782015, lon: 90.427115, radius: 50.0),
//   DangerZone(lat: 23.779725, lon: 90.426842, radius: 50.0),
//   DangerZone(lat: 23.781952, lon: 90.424385, radius: 50.0),
//   DangerZone(lat: 23.778944, lon: 90.425112, radius: 50.0),
//   DangerZone(lat: 23.782841, lon: 90.426952, radius: 50.0),
//   DangerZone(lat: 23.780125, lon: 90.428214, radius: 50.0),
//   DangerZone(lat: 23.779452, lon: 90.423985, radius: 50.0),
//   DangerZone(lat: 23.782544, lon: 90.423711, radius: 50.0),
//   DangerZone(lat: 23.781125, lon: 90.428841, radius: 50.0),
//   DangerZone(lat: 23.778721, lon: 90.426512, radius: 50.0),
//   DangerZone(lat: 23.783154, lon: 90.425221, radius: 50.0),
//   DangerZone(lat: 23.779985, lon: 90.422942, radius: 50.0),
//   DangerZone(lat: 23.783422, lon: 90.428015, radius: 50.0),
//   DangerZone(lat: 23.782952, lon: 90.427415, radius: 50.0),
//   DangerZone(lat: 23.781444, lon: 90.423421, radius: 50.0),
//   DangerZone(lat: 23.780215, lon: 90.427715, radius: 50.0),
//   DangerZone(lat: 23.783812, lon: 90.426242, radius: 50.0),
//   DangerZone(lat: 23.779841, lon: 90.428985, radius: 50.0),
//   DangerZone(lat: 23.782185, lon: 90.424915, radius: 50.0),
//   DangerZone(lat: 23.780685, lon: 90.423614, radius: 50.0),
//   DangerZone(lat: 23.799452, lon: 90.415842, radius: 50.0),
//   DangerZone(lat: 23.797125, lon: 90.415214, radius: 50.0),
//   DangerZone(lat: 23.798985, lon: 90.416512, radius: 50.0),
//   DangerZone(lat: 23.796954, lon: 90.414125, radius: 50.0),
//   DangerZone(lat: 23.799815, lon: 90.413852, radius: 50.0),
//   DangerZone(lat: 23.798544, lon: 90.417215, radius: 50.0),
//   DangerZone(lat: 23.800214, lon: 90.415325, radius: 50.0),
//   DangerZone(lat: 23.797842, lon: 90.416942, radius: 50.0),
//   DangerZone(lat: 23.796885, lon: 90.413421, radius: 50.0),
//   DangerZone(lat: 23.799944, lon: 90.416115, radius: 50.0),
//   DangerZone(lat: 23.797521, lon: 90.417425, radius: 50.0),
//   DangerZone(lat: 23.798741, lon: 90.413214, radius: 50.0),
//   DangerZone(lat: 23.800452, lon: 90.414842, radius: 50.0),
//   DangerZone(lat: 23.796625, lon: 90.415512, radius: 50.0),
//   DangerZone(lat: 23.799124, lon: 90.417985, radius: 50.0),
//   DangerZone(lat: 23.797285, lon: 90.412985, radius: 50.0),
//   DangerZone(lat: 23.800821, lon: 90.415942, radius: 50.0),
//   DangerZone(lat: 23.796985, lon: 90.416214, radius: 50.0),
//   DangerZone(lat: 23.799385, lon: 90.413842, radius: 50.0),
//   DangerZone(lat: 23.798185, lon: 90.418214, radius: 50.0),
//   DangerZone(lat: 23.746215, lon: 90.373285, radius: 50.0),
//   DangerZone(lat: 23.744512, lon: 90.373452, radius: 50.0),
//   DangerZone(lat: 23.746852, lon: 90.371942, radius: 50.0),
//   DangerZone(lat: 23.744985, lon: 90.371214, radius: 50.0),
//   DangerZone(lat: 23.745842, lon: 90.373815, radius: 50.0),
//   DangerZone(lat: 23.743925, lon: 90.372452, radius: 50.0),
//   DangerZone(lat: 23.747125, lon: 90.372985, radius: 50.0),
//   DangerZone(lat: 23.744421, lon: 90.371842, radius: 50.0),
//   DangerZone(lat: 23.746425, lon: 90.373125, radius: 50.0),
//   DangerZone(lat: 23.745315, lon: 90.374214, radius: 50.0),
//   DangerZone(lat: 23.744842, lon: 90.370985, radius: 50.0),
//   DangerZone(lat: 23.746852, lon: 90.374452, radius: 50.0),
//   DangerZone(lat: 23.743985, lon: 90.371625, radius: 50.0),
//   DangerZone(lat: 23.747215, lon: 90.373521, radius: 50.0),
//   DangerZone(lat: 23.744652, lon: 90.374115, radius: 50.0),
//   DangerZone(lat: 23.745985, lon: 90.370842, radius: 50.0),
//   DangerZone(lat: 23.746521, lon: 90.374985, radius: 50.0),
//   DangerZone(lat: 23.743785, lon: 90.372985, radius: 50.0),
//   DangerZone(lat: 23.747421, lon: 90.371942, radius: 50.0),
//   DangerZone(lat: 23.744214, lon: 90.373785, radius: 50.0),
//   DangerZone(lat: 23.75684527394259, lon: 90.46392165354208, radius: 50.0),
//   DangerZone(lat: 23.756145273942596, lon: 90.46372165354209, radius: 50.0),
//   DangerZone(lat: 23.756445273942598, lon: 90.46402165354208, radius: 50.0),
//   DangerZone(lat: 23.756745273942597, lon: 90.46362165354207, radius: 50.0),
//   DangerZone(lat: 23.756245273942596, lon: 90.46392165354206, radius: 50.0),
//   DangerZone(lat: 23.756545273942594, lon: 90.46342165354208, radius: 50.0),
//   DangerZone(lat: 23.756645273942596, lon: 90.46372165354205, radius: 50.0),
//   DangerZone(lat: 23.756045273942595, lon: 90.46352165354209, radius: 50.0),
//   DangerZone(lat: 23.756945273942596, lon: 90.46382165354206, radius: 50.0),
//   DangerZone(lat: 23.756345273942596, lon: 90.46412165354208, radius: 50.0),
//   DangerZone(lat: 23.75654527394259, lon: 90.46422165354209, radius: 50.0),
//   DangerZone(lat: 23.756145273942598, lon: 90.46402165354207, radius: 50.0),
//   DangerZone(lat: 23.756745273942596, lon: 90.46342165354206, radius: 50.0),
//   DangerZone(lat: 23.756245273942594, lon: 90.46362165354205, radius: 50.0),
//   DangerZone(lat: 23.75644527394259, lon: 90.46412165354207, radius: 50.0),
//   DangerZone(lat: 23.75664527394259, lon: 90.4635216535421, radius: 50.0),
//   DangerZone(lat: 23.756845273942597, lon: 90.46372165354207, radius: 50.0),
//   DangerZone(lat: 23.756045273942596, lon: 90.46392165354209, radius: 50.0),
//   DangerZone(lat: 23.75694527394259, lon: 90.46362165354208, radius: 50.0),
//   DangerZone(lat: 23.75634527394259, lon: 90.46332165354206, radius: 50.0),
//   DangerZone(lat: 23.729454126104426, lon: 90.41938950725988, radius: 50.0),
//   DangerZone(lat: 23.728454126104426, lon: 90.41838950725988, radius: 50.0),
//   DangerZone(lat: 23.729954126104426, lon: 90.41988950725988, radius: 50.0),
//   DangerZone(lat: 23.728954126104426, lon: 90.41788950725988, radius: 50.0),
//   DangerZone(lat: 23.730454126104426, lon: 90.41888950725988, radius: 50.0),
//   DangerZone(lat: 23.728454126104426, lon: 90.41988950725988, radius: 50.0),
//   DangerZone(lat: 23.729454126104426, lon: 90.41788950725988, radius: 50.0),
//   DangerZone(lat: 23.730954126104426, lon: 90.41938950725988, radius: 50.0),
//   DangerZone(lat: 23.727954126104426, lon: 90.41838950725988, radius: 50.0),
//   DangerZone(lat: 23.729954126104426, lon: 90.42038950725988, radius: 50.0),
//   DangerZone(lat: 23.730454126104426, lon: 90.42088950725988, radius: 50.0),
//   DangerZone(lat: 23.727454126104426, lon: 90.41788950725988, radius: 50.0),
//   DangerZone(lat: 23.730954126104426, lon: 90.41788950725988, radius: 50.0),
//   DangerZone(lat: 23.727954126104426, lon: 90.42038950725988, radius: 50.0),
//   DangerZone(lat: 23.729954126104426, lon: 90.41738950725988, radius: 50.0),
//   DangerZone(lat: 23.728454126104426, lon: 90.41688950725988, radius: 50.0),
//   DangerZone(lat: 23.731454126104426, lon: 90.41988950725988, radius: 50.0),
//   DangerZone(lat: 23.729454126104426, lon: 90.42138950725988, radius: 50.0),
//   DangerZone(lat: 23.731954126104426, lon: 90.41888950725988, radius: 50.0),
//   DangerZone(lat: 23.727954126104426, lon: 90.41738950725988, radius: 50.0),
//   DangerZone(lat: 23.79548294208009, lon: 90.34614617670126, radius: 50.0),
//   DangerZone(lat: 23.79348294208009, lon: 90.34414617670126, radius: 50.0),
//   DangerZone(lat: 23.79498294208009, lon: 90.34714617670126, radius: 50.0),
//   DangerZone(lat: 23.79398294208009, lon: 90.34314617670126, radius: 50.0),
//   DangerZone(lat: 23.79598294208009, lon: 90.34564617670126, radius: 50.0),
//   DangerZone(lat: 23.79448294208009, lon: 90.34814617670126, radius: 50.0),
//   DangerZone(lat: 23.79648294208009, lon: 90.34414617670126, radius: 50.0),
//   DangerZone(lat: 23.79398294208009, lon: 90.34614617670126, radius: 50.0),
//   DangerZone(lat: 23.79548294208009, lon: 90.34364617670126, radius: 50.0),
//   DangerZone(lat: 23.79498294208009, lon: 90.34464617670126, radius: 50.0),
//   DangerZone(lat: 23.79648294208009, lon: 90.34664617670126, radius: 50.0),
//   DangerZone(lat: 23.79348294208009, lon: 90.34564617670126, radius: 50.0),
//   DangerZone(lat: 23.79598294208009, lon: 90.34714617670126, radius: 50.0),
//   DangerZone(lat: 23.79448294208009, lon: 90.34364617670126, radius: 50.0),
//   DangerZone(lat: 23.79648294208009, lon: 90.34514617670126, radius: 50.0),
//   DangerZone(lat: 23.79398294208009, lon: 90.34714617670126, radius: 50.0),
//   DangerZone(lat: 23.79548294208009, lon: 90.34464617670126, radius: 50.0),
//   DangerZone(lat: 23.79498294208009, lon: 90.34664617670126, radius: 50.0),
//   DangerZone(lat: 23.79648294208009, lon: 90.34764617670126, radius: 50.0),
//   DangerZone(lat: 23.79348294208009, lon: 90.34414617670126, radius: 50.0),
//   DangerZone(lat: 23.854262689364894, lon: 90.3884472638953, radius: 77.05291085405463),
//   DangerZone(lat: 23.763391478912983, lon: 90.35003007519339, radius: 37.346457943981136),
//   DangerZone(lat: 23.660627128987066, lon: 90.4564738122924, radius: 59.168718945649246),
//   DangerZone(lat: 23.89530655785806, lon: 90.40188331012561, radius: 72.42855035253562),
//   DangerZone(lat: 23.89027481067819, lon: 90.3984091356647, radius: 49.303328004986255),
//   DangerZone(lat: 23.823566316944795, lon: 90.4422998780587, radius: 45.59911091710917),
//   DangerZone(lat: 23.755170285025862, lon: 90.39547134776618, radius: 61.56207990238147),
//   DangerZone(lat: 23.779529632649734, lon: 90.41283274228105, radius: 67.05643388118061),
//   DangerZone(lat: 23.721145742709712, lon: 90.45551256599742, radius: 67.98233867485132),
//   DangerZone(lat: 23.82823730705207, lon: 90.35964989872402, radius: 54.70005989862519),
//   DangerZone(lat: 23.759573900867437, lon: 90.42731304688519, radius: 49.96866807943938),
//   DangerZone(lat: 23.891924232100628, lon: 90.3910556023441, radius: 50.20607900861593),
//   DangerZone(lat: 23.88166728277413, lon: 90.38742423557824, radius: 38.17871970230097),
//   DangerZone(lat: 23.679353666549574, lon: 90.43002705576023, radius: 62.01738843645221),
//   DangerZone(lat: 23.741416790789597, lon: 90.42347533046045, radius: 53.024081086879384),
//   DangerZone(lat: 23.729548881380016, lon: 90.3396022281376, radius: 36.060357493324624),
//   DangerZone(lat: 23.8752724422756, lon: 90.33672364292917, radius: 31.784415939446077),
//   DangerZone(lat: 23.684525692434345, lon: 90.46503155339208, radius: 43.542260458627304),
//   DangerZone(lat: 23.781735055738334, lon: 90.43610073143383, radius: 61.155139658907764),
//   DangerZone(lat: 23.779892840281455, lon: 90.43660385645185, radius: 71.83452520139807),
//   DangerZone(lat: 23.847653922020246, lon: 90.33330734134425, radius: 55.39956636833965),
//   DangerZone(lat: 23.67770336680485, lon: 90.47813161398199, radius: 39.12565787158054),
//   DangerZone(lat: 23.806251984779724, lon: 90.36309258815986, radius: 68.39490515954927),
//   DangerZone(lat: 23.716924121397515, lon: 90.33034322516262, radius: 63.53416925811736),
//   DangerZone(lat: 23.854814213468973, lon: 90.33705443107306, radius: 48.46879367317989),
//   DangerZone(lat: 23.702679795990324, lon: 90.38620098652817, radius: 43.50173868246541),
//   DangerZone(lat: 23.79099206796124, lon: 90.3797160244484, radius: 59.66685878047012),
//   DangerZone(lat: 23.740176544461736, lon: 90.38597429426349, radius: 62.69720646094261),
//   DangerZone(lat: 23.754691917439484, lon: 90.47178184189693, radius: 63.57121849244195),
//   DangerZone(lat: 23.74918478718909, lon: 90.44471640814209, radius: 45.002372660207975),
//   DangerZone(lat: 23.867639656081142, lon: 90.39285956694889, radius: 50.99643278766575),
//   DangerZone(lat: 23.82268691326673, lon: 90.3568033244674, radius: 52.994055150409196),
//   DangerZone(lat: 23.829408671260374, lon: 90.47955258245533, radius: 60.10663353969037),
//   DangerZone(lat: 23.745211364381834, lon: 90.35963747204542, radius: 65.95485808974396),
//   DangerZone(lat: 23.733658819099535, lon: 90.35788520339469, radius: 75.85389271132244),
//   DangerZone(lat: 23.748870283147486, lon: 90.44084334210599, radius: 69.10196504279477),
//   DangerZone(lat: 23.855850981837644, lon: 90.46924017518243, radius: 38.25576368286268),
//   DangerZone(lat: 23.858114267095104, lon: 90.35344039621123, radius: 61.94603988013813),
//   DangerZone(lat: 23.864669916047507, lon: 90.39567712926994, radius: 76.93363443547435),
//   DangerZone(lat: 23.82899852537848, lon: 90.44356429427437, radius: 79.69442375341185),
//   DangerZone(lat: 23.698779729704885, lon: 90.47310224764749, radius: 78.3608572474826),
//   DangerZone(lat: 23.878262312499682, lon: 90.42010813591133, radius: 75.12015550457882),
//   DangerZone(lat: 23.693884004013807, lon: 90.4589310212065, radius: 32.427241796563685),
//   DangerZone(lat: 23.868501739769414, lon: 90.49763896483505, radius: 33.917908775155766),
//   DangerZone(lat: 23.837096767929186, lon: 90.49686882134384, radius: 56.497786721729945),
//   DangerZone(lat: 23.877484301491968, lon: 90.49675165459435, radius: 46.80993737956102),
//   DangerZone(lat: 23.862553513708136, lon: 90.43195140229267, radius: 78.3152330836156),
//   DangerZone(lat: 23.800804446935963, lon: 90.43699945344012, radius: 58.75207416535207),
//   DangerZone(lat: 23.790558545436046, lon: 90.38571470064878, radius: 69.0311467093191),
//   DangerZone(lat: 23.724139572325175, lon: 90.4691366865171, radius: 45.81501900399563),
//   DangerZone(lat: 23.815076014320983, lon: 90.45040695814394, radius: 72.34964938720924),
//   DangerZone(lat: 23.793329016078676, lon: 90.36785913925642, radius: 47.702442222872975),
//   DangerZone(lat: 23.82489867366748, lon: 90.49326226370924, radius: 33.31496373894301),
//   DangerZone(lat: 23.8778775714476, lon: 90.37859314860499, radius: 46.375279508251474),
//   DangerZone(lat: 23.784713226805465, lon: 90.43176056236021, radius: 70.52936506966954),
//   DangerZone(lat: 23.82053870431129, lon: 90.49399197560818, radius: 30.03478206497946),
//   DangerZone(lat: 23.89612085469279, lon: 90.46924418862524, radius: 54.399960416363086),
//   DangerZone(lat: 23.86991294208962, lon: 90.47189174201726, radius: 37.411123813621614),
//   DangerZone(lat: 23.728216119136736, lon: 90.3441988360276, radius: 52.53930498947558),
//   DangerZone(lat: 23.7021405989386, lon: 90.46063828921966, radius: 36.12252729714061),
//   DangerZone(lat: 23.80522826531573, lon: 90.40846975625016, radius: 48.73583121286196),
//   DangerZone(lat: 23.808604028386828, lon: 90.45736613918204, radius: 41.388178272842254),
//   DangerZone(lat: 23.694762172615295, lon: 90.33506460802462, radius: 71.15595579238368),
//   DangerZone(lat: 23.704454721413335, lon: 90.34530105799111, radius: 35.10335764403619),
//   DangerZone(lat: 23.84385245681548, lon: 90.36328949373781, radius: 42.913328183190046),
//   DangerZone(lat: 23.72722015468074, lon: 90.35892052753618, radius: 32.075074981926086),
//   DangerZone(lat: 23.81712723037594, lon: 90.40094238385731, radius: 30.382724261270173),
//   DangerZone(lat: 23.77066998561471, lon: 90.47197202458266, radius: 31.580060639170377),
//   DangerZone(lat: 23.685728193111505, lon: 90.38952092035369, radius: 40.47896034952224),
//   DangerZone(lat: 23.814821326679056, lon: 90.38865393422599, radius: 40.733683040679594),
//   DangerZone(lat: 23.799192893139395, lon: 90.46614850775455, radius: 42.10533990789886),
//   DangerZone(lat: 23.88033592211059, lon: 90.42793871228761, radius: 55.646610147184944),
//   DangerZone(lat: 23.746479797268897, lon: 90.44061347509685, radius: 64.98803864460257),
//   DangerZone(lat: 23.845425303446763, lon: 90.41636182244851, radius: 57.92871773518777),
//   DangerZone(lat: 23.83708775587229, lon: 90.4638333435036, radius: 51.70050256199651),
//   DangerZone(lat: 23.831026519656017, lon: 90.33461417020128, radius: 44.37791477280605),
//   DangerZone(lat: 23.762403608833846, lon: 90.4832703542335, radius: 33.51375635399539),
//   DangerZone(lat: 23.794278361406935, lon: 90.4971417656768, radius: 66.59593389120008),
//   DangerZone(lat: 23.8569881483401, lon: 90.33953655541809, radius: 31.262068667853022),
//   DangerZone(lat: 23.742496278679493, lon: 90.41619568460217, radius: 73.49309735693491),
//   DangerZone(lat: 23.744524943490834, lon: 90.42090170341102, radius: 68.9233294555335),
//   DangerZone(lat: 23.728755646666677, lon: 90.4201032837253, radius: 50.098708968380066),
//   DangerZone(lat: 23.699436847227307, lon: 90.4377667696718, radius: 47.95328661381056),
//   DangerZone(lat: 23.757352981520604, lon: 90.40226819773713, radius: 55.33074126191819),
//   DangerZone(lat: 23.780833782151607, lon: 90.4858899739508, radius: 63.20245472246078),
//   DangerZone(lat: 23.800417517552052, lon: 90.3597170441381, radius: 39.504462119821696),
//   DangerZone(lat: 23.80513998836549, lon: 90.49659300928013, radius: 53.03839371187601),
//   DangerZone(lat: 23.83247668791555, lon: 90.3706943136834, radius: 79.04076605410967),
//   DangerZone(lat: 23.814925219101934, lon: 90.43652874104342, radius: 51.188891587745566),
//   DangerZone(lat: 23.67085433515414, lon: 90.38600965851069, radius: 30.592529019503317),
//   DangerZone(lat: 23.824395162853712, lon: 90.46278878015187, radius: 61.43879805406557),
//   DangerZone(lat: 23.767709250585707, lon: 90.37736143462186, radius: 63.7427709993916),
//   DangerZone(lat: 23.862389661764343, lon: 90.4945025111741, radius: 73.93074389941589),
//   DangerZone(lat: 23.84094259817668, lon: 90.38764506108701, radius: 71.81392030705388),
//   DangerZone(lat: 23.744240478222135, lon: 90.4388695974412, radius: 70.36356776536418),
//   DangerZone(lat: 23.673970727021036, lon: 90.34312454844216, radius: 34.610009914003044),
//   DangerZone(lat: 23.699002919396424, lon: 90.3854185474682, radius: 38.210458335542356),
//   DangerZone(lat: 23.815141198275477, lon: 90.38765702618632, radius: 39.408318165028625),
//   DangerZone(lat: 23.885240223928072, lon: 90.46834042307653, radius: 42.78561924705801),
//   DangerZone(lat: 23.897571474243158, lon: 90.39307541296427, radius: 72.60359843398177),
//   DangerZone(lat: 23.73658945074609, lon: 90.34704330502487, radius: 32.498083319857784),
//   DangerZone(lat: 23.794576457957444, lon: 90.46815108543595, radius: 78.98942856429369),
//   DangerZone(lat: 23.82947223088983, lon: 90.36531228751198, radius: 65.38172083816833),
//   DangerZone(lat: 23.676579054080495, lon: 90.41057840294472, radius: 53.80486664898655),
//   DangerZone(lat: 23.66860535446607, lon: 90.48310632556658, radius: 73.94989705752779),
//   DangerZone(lat: 23.759210966804915, lon: 90.42913973286888, radius: 65.26104543275225),
//   DangerZone(lat: 23.812177997702626, lon: 90.40877141944839, radius: 63.94128232252978),
//   DangerZone(lat: 23.786440488702947, lon: 90.45092617463807, radius: 33.890378986606194),
//   DangerZone(lat: 23.886027320348855, lon: 90.4427856542381, radius: 32.53506790517309),
//   DangerZone(lat: 23.865571036112726, lon: 90.45465362666073, radius: 51.30785149393156),
//   DangerZone(lat: 23.72325721792509, lon: 90.337189852958, radius: 75.18923474006753),
//   DangerZone(lat: 23.788136347171417, lon: 90.36584712769637, radius: 37.60043679807511),
//   DangerZone(lat: 23.86616425873542, lon: 90.4170964416316, radius: 78.17376841465823),
//   DangerZone(lat: 23.6949814792108, lon: 90.36993889991632, radius: 44.76589693348271),
//   DangerZone(lat: 23.68926066084182, lon: 90.46583596122562, radius: 36.697898065904724),
//   DangerZone(lat: 23.89002525083037, lon: 90.3380663100737, radius: 30.256807287171334),
//   DangerZone(lat: 23.756116630493853, lon: 90.44979872292784, radius: 42.94384220839236),
//   DangerZone(lat: 23.887843894603993, lon: 90.41202724568367, radius: 62.08187508736465),
//   DangerZone(lat: 23.76196623674419, lon: 90.47105315163023, radius: 30.645082692547394),
//   DangerZone(lat: 23.82519327104692, lon: 90.36481086320572, radius: 78.23235957436705),
//   DangerZone(lat: 23.782770845536177, lon: 90.34436981706955, radius: 55.6680386241207),
//   DangerZone(lat: 23.838724123847836, lon: 90.46403783888996, radius: 66.51824120995988),
//   DangerZone(lat: 23.773220840495576, lon: 90.38350215463736, radius: 45.75923605165697),
//   DangerZone(lat: 23.89175666769019, lon: 90.37613076553589, radius: 56.53664755561105),
//   DangerZone(lat: 23.6756469471513, lon: 90.40711057441202, radius: 32.19599222687754),
//   DangerZone(lat: 23.89364450415646, lon: 90.44780374898775, radius: 76.61269739966116),
//   DangerZone(lat: 23.728940058800628, lon: 90.37545322805343, radius: 74.96675421908682),
//   DangerZone(lat: 23.78228467976051, lon: 90.45544982520568, radius: 79.68541313900397),
//   DangerZone(lat: 23.868206661936735, lon: 90.34984263941627, radius: 59.91839534853506),
//   DangerZone(lat: 23.815142087105947, lon: 90.38189840770335, radius: 46.88894199673307),
//   DangerZone(lat: 23.801877061974622, lon: 90.42112433729262, radius: 56.441115145173754),
//   DangerZone(lat: 23.8267552122619, lon: 90.48552901010497, radius: 50.27844532281046),
//   DangerZone(lat: 23.849578521559852, lon: 90.49869031185703, radius: 49.086287719205004),
//   DangerZone(lat: 23.78663102740274, lon: 90.40889502721733, radius: 30.66941718808971),
//   DangerZone(lat: 23.669467528071618, lon: 90.3882077432778, radius: 67.09546172304022),
//   DangerZone(lat: 23.669834612273387, lon: 90.43295906701245, radius: 33.5677765425997),
//   DangerZone(lat: 23.87977608199115, lon: 90.48705540055984, radius: 63.52602785718652),
//   DangerZone(lat: 23.689572480809353, lon: 90.47953489008144, radius: 39.255087428478205),
//   DangerZone(lat: 23.697855896555847, lon: 90.38308080815341, radius: 64.53223111875286),
//   DangerZone(lat: 23.70270372222549, lon: 90.41891115250843, radius: 50.79250862701799),
//   DangerZone(lat: 23.730316327922168, lon: 90.4084721213657, radius: 53.131418430587075),
//   DangerZone(lat: 23.899317224331007, lon: 90.33567932071618, radius: 31.161630779638966),
//   DangerZone(lat: 23.897323827615796, lon: 90.3528778841156, radius: 49.54820900266097),
//   DangerZone(lat: 23.84376631756742, lon: 90.48856929403408, radius: 50.36802674044488),
//   DangerZone(lat: 23.83402905542777, lon: 90.39495874299438, radius: 32.09765957519061),
//   DangerZone(lat: 23.749789062246702, lon: 90.41102767834423, radius: 30.430027766986672),
//   DangerZone(lat: 23.758360848436816, lon: 90.44496951969758, radius: 45.48062056615357),
//   DangerZone(lat: 23.831153527048475, lon: 90.40569414047519, radius: 47.016504149165186),
//   DangerZone(lat: 23.665026898376745, lon: 90.41435234739616, radius: 75.60108406394043),
//   DangerZone(lat: 23.829521769106748, lon: 90.36057935104027, radius: 66.91563341568494),
//   DangerZone(lat: 23.677776311296597, lon: 90.48619769555674, radius: 61.35838577037934),
//   DangerZone(lat: 23.805915951949295, lon: 90.39029759763348, radius: 61.70769270017868),
//   DangerZone(lat: 23.866057025731415, lon: 90.49336859274635, radius: 34.38322782513096),
//   DangerZone(lat: 23.72640111449872, lon: 90.49697257391877, radius: 70.0988615928299),
//   DangerZone(lat: 23.80144604305107, lon: 90.33890209742755, radius: 79.58571240154913),
//   DangerZone(lat: 23.757958113724378, lon: 90.45225245399499, radius: 53.74106092611045),
//   DangerZone(lat: 23.737460155860106, lon: 90.41486783126673, radius: 60.84936543139453),
//   DangerZone(lat: 23.68984144333762, lon: 90.33010621248029, radius: 36.339944228105075),
//   DangerZone(lat: 23.804856906749773, lon: 90.43477941477695, radius: 37.45936918892376),
//   DangerZone(lat: 23.660891262142854, lon: 90.42662324332201, radius: 68.48294804200086),
//   DangerZone(lat: 23.866213779806813, lon: 90.3805574396146, radius: 35.26562431050024),
//   DangerZone(lat: 23.843595376442895, lon: 90.49177207619229, radius: 30.986171809672044),
//   DangerZone(lat: 23.84596122632743, lon: 90.37694097869955, radius: 44.436364171026014),
//   DangerZone(lat: 23.739202489580645, lon: 90.37017341490282, radius: 57.26457289562716),
//   DangerZone(lat: 23.78008585880681, lon: 90.35092360822298, radius: 53.668513767461384),
//   DangerZone(lat: 23.872228971373467, lon: 90.3915929567414, radius: 71.90716411393457),
//   DangerZone(lat: 23.884859713285504, lon: 90.38470439960754, radius: 42.41940428910241),
//   DangerZone(lat: 23.74873417101916, lon: 90.40401633229999, radius: 78.06924129476025),
//   DangerZone(lat: 23.874934671339645, lon: 90.48361497629931, radius: 79.6183887507556),
//   DangerZone(lat: 23.881849652818257, lon: 90.3966754197209, radius: 62.85670216174592),
//   DangerZone(lat: 23.85044988608085, lon: 90.4099272704138, radius: 42.3743782752241),
//   DangerZone(lat: 23.7297275676271, lon: 90.4376505054702, radius: 63.55650639256186),
//   DangerZone(lat: 23.86887636794993, lon: 90.48502164403382, radius: 49.19340929327029),
//   DangerZone(lat: 23.792463044678925, lon: 90.48182810837153, radius: 31.54989410455782),
//   DangerZone(lat: 23.837272320411966, lon: 90.41692635982834, radius: 45.598915271875256),
//   DangerZone(lat: 23.85674076659523, lon: 90.46982076906377, radius: 42.47682896147171),
//   DangerZone(lat: 23.664548583067628, lon: 90.39679392285248, radius: 51.83422759021469),
//   DangerZone(lat: 23.694197292436698, lon: 90.47431961396958, radius: 30.470872874296262),
//   DangerZone(lat: 23.89139042341064, lon: 90.33882574380564, radius: 70.59326423503944),
//   DangerZone(lat: 23.87704958496204, lon: 90.44159157542295, radius: 65.33870402401737),
//   DangerZone(lat: 23.68988062555188, lon: 90.40802865224124, radius: 54.96227583194247),
//   DangerZone(lat: 23.86063845369956, lon: 90.43925885561407, radius: 65.12415241211917),
//   DangerZone(lat: 23.75732905404222, lon: 90.48507362687556, radius: 76.58240148464768),
//   DangerZone(lat: 23.89982051973992, lon: 90.33026605377717, radius: 71.16629145900036),
//   DangerZone(lat: 23.74578600521311, lon: 90.48460490891424, radius: 71.37908648653215),
//   DangerZone(lat: 23.873458690097188, lon: 90.35246719141536, radius: 57.910538545058856),
//   DangerZone(lat: 23.793199371708404, lon: 90.42323426970215, radius: 50.90446429203873),
//   DangerZone(lat: 23.743910053492346, lon: 90.48501732706006, radius: 48.50796436674645),
//   DangerZone(lat: 23.800751748145817, lon: 90.41948526315983, radius: 44.73305928148967),
//   DangerZone(lat: 23.886728463705545, lon: 90.39155537294579, radius: 33.822990587132274),
//   DangerZone(lat: 23.781385751556233, lon: 90.34138502198164, radius: 50.95062312426849),
//   DangerZone(lat: 23.740110817822504, lon: 90.38782648534564, radius: 53.22596520237148),
//   DangerZone(lat: 23.869563754234733, lon: 90.46012770366913, radius: 46.03757752002676),
//   DangerZone(lat: 23.734969314112437, lon: 90.40713944969336, radius: 73.565462254747),
//   DangerZone(lat: 23.845851162619315, lon: 90.40180012395518, radius: 72.46625164401232),
//   DangerZone(lat: 23.72420042503735, lon: 90.34668884065026, radius: 68.34208884753349),
//   DangerZone(lat: 23.797429295980677, lon: 90.34175058302283, radius: 70.03984826811032),
//   DangerZone(lat: 23.877736103431054, lon: 90.36819869025442, radius: 61.659721405691286),
//   DangerZone(lat: 23.74746360903401, lon: 90.35675919696465, radius: 47.28901837754582),
//   DangerZone(lat: 23.706045173532267, lon: 90.3497855709579, radius: 43.93547062792268),
// ];
// Set<Circle> circles = {
//   // First cluster
//   Circle(circleId: const CircleId('c0'), center: const LatLng(23.767210638688493, 90.35838621347095), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c1'), center: const LatLng(23.769512, 90.359721), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c2'), center: const LatLng(23.765932, 90.357254), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c3'), center: const LatLng(23.770821, 90.360892), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c4'), center: const LatLng(23.766182, 90.361224), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c5'), center: const LatLng(23.768415, 90.362918), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c6'), center: const LatLng(23.764892, 90.359442), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c7'), center: const LatLng(23.769942, 90.356731), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c8'), center: const LatLng(23.771255, 90.358415), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c9'), center: const LatLng(23.763875, 90.358754), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c10'), center: const LatLng(23.768622, 90.354981), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c11'), center: const LatLng(23.772104, 90.360214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c12'), center: const LatLng(23.767985, 90.363842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c13'), center: const LatLng(23.765214, 90.362155), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c14'), center: const LatLng(23.769451, 90.363112), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c15'), center: const LatLng(23.770942, 90.355915), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c16'), center: const LatLng(23.764385, 90.355842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c17'), center: const LatLng(23.773125, 90.358722), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c18'), center: const LatLng(23.762985, 90.360145), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c19'), center: const LatLng(23.771925, 90.362215), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c20'), center: const LatLng(23.765732, 90.364421), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//
//   // Second cluster
//   Circle(circleId: const CircleId('c21'), center: const LatLng(23.861233, 90.366754), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c22'), center: const LatLng(23.858012, 90.366184), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c23'), center: const LatLng(23.860721, 90.367892), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c24'), center: const LatLng(23.857182, 90.363224), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c25'), center: const LatLng(23.862415, 90.368918), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c26'), center: const LatLng(23.857892, 90.361442), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c27'), center: const LatLng(23.861942, 90.362731), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c28'), center: const LatLng(23.863255, 90.364415), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c29'), center: const LatLng(23.857875, 90.364754), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c30'), center: const LatLng(23.859622, 90.361981), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c31'), center: const LatLng(23.863104, 90.367214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c32'), center: const LatLng(23.859985, 90.369842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c33'), center: const LatLng(23.857214, 90.368155), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c34'), center: const LatLng(23.861451, 90.369112), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c35'), center: const LatLng(23.862942, 90.362915), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c36'), center: const LatLng(23.858385, 90.362842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c37'), center: const LatLng(23.864125, 90.365722), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c38'), center: const LatLng(23.859985, 90.370145), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c39'), center: const LatLng(23.861925, 90.367215), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c40'), center: const LatLng(23.858422, 90.366721), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//
//   // Third cluster
//   Circle(circleId: const CircleId('c41'), center: const LatLng(23.782015, 90.427115), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c42'), center: const LatLng(23.779725, 90.426842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c43'), center: const LatLng(23.781952, 90.424385), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c44'), center: const LatLng(23.778944, 90.425112), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c45'), center: const LatLng(23.782841, 90.426952), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c46'), center: const LatLng(23.780125, 90.428214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c47'), center: const LatLng(23.779452, 90.423985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c48'), center: const LatLng(23.782544, 90.423711), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c49'), center: const LatLng(23.781125, 90.428841), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c50'), center: const LatLng(23.778721, 90.426512), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c51'), center: const LatLng(23.783154, 90.425221), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c52'), center: const LatLng(23.779985, 90.422942), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c53'), center: const LatLng(23.783422, 90.428015), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c54'), center: const LatLng(23.782952, 90.427415), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c55'), center: const LatLng(23.781444, 90.423421), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c56'), center: const LatLng(23.780215, 90.427715), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c57'), center: const LatLng(23.783812, 90.426242), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c58'), center: const LatLng(23.779841, 90.428985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c59'), center: const LatLng(23.782185, 90.424915), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c60'), center: const LatLng(23.780685, 90.423614), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//
//   // Fourth cluster
//   Circle(circleId: const CircleId('c61'), center: const LatLng(23.799452, 90.415842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c62'), center: const LatLng(23.797125, 90.415214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c63'), center: const LatLng(23.798985, 90.416512), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c64'), center: const LatLng(23.796954, 90.414125), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c65'), center: const LatLng(23.799815, 90.413852), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c66'), center: const LatLng(23.798544, 90.417215), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c67'), center: const LatLng(23.800214, 90.415325), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c68'), center: const LatLng(23.797842, 90.416942), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c69'), center: const LatLng(23.796885, 90.413421), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c70'), center: const LatLng(23.799944, 90.416115), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c71'), center: const LatLng(23.797521, 90.417425), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c72'), center: const LatLng(23.798741, 90.413214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c73'), center: const LatLng(23.800452, 90.414842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c74'), center: const LatLng(23.796625, 90.415512), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c75'), center: const LatLng(23.799124, 90.417985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c76'), center: const LatLng(23.797285, 90.412985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c77'), center: const LatLng(23.800821, 90.415942), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c78'), center: const LatLng(23.796985, 90.416214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c79'), center: const LatLng(23.799385, 90.413842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c80'), center: const LatLng(23.798185, 90.418214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//
//   // Fifth cluster
//   Circle(circleId: const CircleId('c81'), center: const LatLng(23.746215, 90.373285), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c82'), center: const LatLng(23.744512, 90.373452), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c83'), center: const LatLng(23.746852, 90.371942), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c84'), center: const LatLng(23.744985, 90.371214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c85'), center: const LatLng(23.745842, 90.373815), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c86'), center: const LatLng(23.743925, 90.372452), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c87'), center: const LatLng(23.747125, 90.372985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c88'), center: const LatLng(23.744421, 90.371842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c89'), center: const LatLng(23.746425, 90.373125), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c90'), center: const LatLng(23.745315, 90.374214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c91'), center: const LatLng(23.744842, 90.370985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c92'), center: const LatLng(23.746852, 90.374452), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c93'), center: const LatLng(23.743985, 90.371625), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c94'), center: const LatLng(23.747215, 90.373521), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c95'), center: const LatLng(23.744652, 90.374115), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c96'), center: const LatLng(23.745985, 90.370842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c97'), center: const LatLng(23.746521, 90.374985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c98'), center: const LatLng(23.743785, 90.372985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c99'), center: const LatLng(23.747421, 90.371942), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c100'), center: const LatLng(23.744214, 90.373785), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//
//   // Sixth cluster
//   Circle(circleId: const CircleId('c101'), center: const LatLng(23.75684527394259, 90.46392165354208), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c102'), center: const LatLng(23.756145273942596, 90.46372165354209), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c103'), center: const LatLng(23.756445273942598, 90.46402165354208), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c104'), center: const LatLng(23.756745273942597, 90.46362165354207), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c105'), center: const LatLng(23.756245273942596, 90.46392165354206), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c106'), center: const LatLng(23.756545273942594, 90.46342165354208), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c107'), center: const LatLng(23.756645273942596, 90.46372165354205), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c108'), center: const LatLng(23.756045273942595, 90.46352165354209), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c109'), center: const LatLng(23.756945273942596, 90.46382165354206), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c110'), center: const LatLng(23.756345273942596, 90.46412165354208), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c111'), center: const LatLng(23.75654527394259, 90.46422165354209), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c112'), center: const LatLng(23.756145273942598, 90.46402165354207), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c113'), center: const LatLng(23.756745273942596, 90.46342165354206), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c114'), center: const LatLng(23.756245273942594, 90.46362165354205), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c115'), center: const LatLng(23.75644527394259, 90.46412165354207), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c116'), center: const LatLng(23.75664527394259, 90.4635216535421), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c117'), center: const LatLng(23.756845273942597, 90.46372165354207), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c118'), center: const LatLng(23.756045273942596, 90.46392165354209), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c119'), center: const LatLng(23.75694527394259, 90.46362165354208), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c120'), center: const LatLng(23.75634527394259, 90.46332165354206), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//
//   // Seventh cluster
//   Circle(circleId: const CircleId('c121'), center: const LatLng(23.729454126104426, 90.41938950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c122'), center: const LatLng(23.728454126104426, 90.41838950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c123'), center: const LatLng(23.729954126104426, 90.41988950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c124'), center: const LatLng(23.728954126104426, 90.41788950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c125'), center: const LatLng(23.730454126104426, 90.41888950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c126'), center: const LatLng(23.728454126104426, 90.41988950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c127'), center: const LatLng(23.729454126104426, 90.41788950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c128'), center: const LatLng(23.730954126104426, 90.41938950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c129'), center: const LatLng(23.727954126104426, 90.41838950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c130'), center: const LatLng(23.729954126104426, 90.42038950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c131'), center: const LatLng(23.730454126104426, 90.42088950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c132'), center: const LatLng(23.727454126104426, 90.41788950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c133'), center: const LatLng(23.730954126104426, 90.41788950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c134'), center: const LatLng(23.727954126104426, 90.42038950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c135'), center: const LatLng(23.729954126104426, 90.41738950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c136'), center: const LatLng(23.728454126104426, 90.41688950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c137'), center: const LatLng(23.731454126104426, 90.41988950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c138'), center: const LatLng(23.729454126104426, 90.42138950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c139'), center: const LatLng(23.731954126104426, 90.41888950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c140'), center: const LatLng(23.727954126104426, 90.41738950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//
//   // Eighth cluster
//   Circle(circleId: const CircleId('c141'), center: const LatLng(23.79548294208009, 90.34614617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c142'), center: const LatLng(23.79348294208009, 90.34414617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c143'), center: const LatLng(23.79498294208009, 90.34714617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c144'), center: const LatLng(23.79398294208009, 90.34314617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c145'), center: const LatLng(23.79598294208009, 90.34564617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c146'), center: const LatLng(23.79448294208009, 90.34814617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c147'), center: const LatLng(23.79648294208009, 90.34414617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c148'), center: const LatLng(23.79398294208009, 90.34614617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c149'), center: const LatLng(23.79548294208009, 90.34364617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c150'), center: const LatLng(23.79498294208009, 90.34464617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c151'), center: const LatLng(23.79648294208009, 90.34664617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c152'), center: const LatLng(23.79348294208009, 90.34564617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c153'), center: const LatLng(23.79598294208009, 90.34714617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c154'), center: const LatLng(23.79448294208009, 90.34364617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c155'), center: const LatLng(23.79648294208009, 90.34514617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c156'), center: const LatLng(23.79398294208009, 90.34714617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c157'), center: const LatLng(23.79548294208009, 90.34464617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c158'), center: const LatLng(23.79498294208009, 90.34664617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c159'), center: const LatLng(23.79648294208009, 90.34764617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c160'), center: const LatLng(23.79348294208009, 90.34414617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
// };



//   Set<Marker> markers = {
//     Marker(
//       markerId: const MarkerId('m1'),
//       position: const LatLng(23.7421, 90.39849),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m2'),
//       position: const LatLng(23.7373, 90.4041),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//   };
//
// // Add corresponding circles
//   Set<Circle> circles = {
//     Circle(
//       circleId: const CircleId('c1'),
//       center: const LatLng(23.7421, 90.39849),
//       radius: 500, // in meters
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c2'),
//       center: const LatLng(23.7373, 90.4041),
//       radius: 500, // in meters
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//   };
//   Set<Polyline> polylines = {
//
//     Polyline(polylineId: const PolylineId('route_1'), points: [
//       LatLng(23.73731, 90.4041),
//       LatLng(23.73743, 90.40411),
//       LatLng(23.73757, 90.4041),
//       LatLng(23.73772, 90.40401),
//       LatLng(23.73793, 90.40392),
//       LatLng(23.73817, 90.40377),
//       LatLng(23.73838, 90.40362),
//       LatLng(23.73871, 90.40329),
//       LatLng(23.73893, 90.40306),
//       LatLng(23.73929, 90.40252),
//       LatLng(23.73968, 90.40188),
//       LatLng(23.74002, 90.40124),
//       LatLng(23.7403, 90.40065),
//       LatLng(23.74061, 90.39999),
//       LatLng(23.74073, 90.39979),
//       LatLng(23.74099, 90.39952),
//       LatLng(23.74167, 90.39887),
//       LatLng(23.7419, 90.39861),
//       LatLng(23.7419, 90.39858),
//       LatLng(23.74192, 90.39853),
//       LatLng(23.74196, 90.39848),
//       LatLng(23.74201, 90.39846),
//       LatLng(23.7421, 90.39849),
//       LatLng(23.74215, 90.39856),
//       LatLng(23.74215, 90.39862),
//       LatLng(23.74215, 90.39864),
//       LatLng(23.74225, 90.39877),
//       LatLng(23.74229, 90.3989),
//       LatLng(23.74231, 90.39904),
//       LatLng(23.74371, 90.40364),
//       LatLng(23.74388, 90.40432),
//       LatLng(23.74409, 90.40484),
//       LatLng(23.74435, 90.40484),
//       LatLng(23.74474, 90.40441),
//       LatLng(23.74491, 90.40427),
//       LatLng(23.74516, 90.40413),
//       LatLng(23.74587, 90.40403),
//       LatLng(23.74597, 90.40402),
//       LatLng(23.74653, 90.40398),
//       LatLng(23.74745, 90.40393),
//       LatLng(23.74799, 90.40385),
//       LatLng(23.74834, 90.40378),
//       LatLng(23.74843, 90.40375),
//       LatLng(23.74866, 90.40359),
//       LatLng(23.74878, 90.40352),
//       LatLng(23.74935, 90.40317),
//       LatLng(23.75023, 90.40266),
//       LatLng(23.75115, 90.4021),
//       LatLng(23.75222, 90.40149),
//       LatLng(23.75344, 90.40075),
//       LatLng(23.75366, 90.40059),
//       LatLng(23.75397, 90.40039),
//       LatLng(23.75445, 90.40013),
//       LatLng(23.75485, 90.3999),
//       LatLng(23.75523, 90.39975),
//       LatLng(23.75544, 90.39968),
//       LatLng(23.75561, 90.39961),
//       LatLng(23.75615, 90.39934),
//       LatLng(23.75659, 90.39911),
//       LatLng(23.75677, 90.39903),
//       LatLng(23.75693, 90.39899),
//       LatLng(23.75704, 90.39899),
//       LatLng(23.75725, 90.39899),
//       LatLng(23.75796, 90.39911),
//       LatLng(23.75863, 90.39917),
//       LatLng(23.75876, 90.39918),
//       LatLng(23.75943, 90.39927),
//       LatLng(23.76098, 90.39951),
//       LatLng(23.76116, 90.39954),
//       LatLng(23.76147, 90.39958),
//       LatLng(23.76217, 90.39974),
//       LatLng(23.76248, 90.39979),
//       LatLng(23.76363, 90.4),
//       LatLng(23.76448, 90.40011),
//       LatLng(23.76611, 90.40038),
//       LatLng(23.76827, 90.40071),
//       LatLng(23.76883, 90.4008),
//       LatLng(23.76913, 90.40086),
//       LatLng(23.7699, 90.40102),
//       LatLng(23.7705, 90.40111),
//       LatLng(23.77061, 90.40113),
//       LatLng(23.77116, 90.4011),
//       LatLng(23.77144, 90.40107),
//       LatLng(23.77206, 90.40088),
//       LatLng(23.77257, 90.40052),
//       LatLng(23.77307, 90.40019),
//       LatLng(23.77331, 90.4),
//       LatLng(23.7741, 90.39946),
//       LatLng(23.77452, 90.39917),
//       LatLng(23.77477, 90.39905),
//       LatLng(23.77529, 90.39879),
//       LatLng(23.77573, 90.39861),
//       LatLng(23.7769, 90.39834),
//       LatLng(23.77753, 90.39823),
//       LatLng(23.77775, 90.39817),
//       LatLng(23.77795, 90.39817),
//       LatLng(23.77833, 90.39819),
//       LatLng(23.77881, 90.39827),
//       LatLng(23.77902, 90.39827),
//       LatLng(23.77918, 90.39825),
//       LatLng(23.77932, 90.39828),
//       LatLng(23.77976, 90.39835),
//       LatLng(23.78106, 90.39859),
//       LatLng(23.78134, 90.39864),
//       LatLng(23.78241, 90.3988),
//       LatLng(23.7833, 90.39896),
//       LatLng(23.78352, 90.39901),
//       LatLng(23.78365, 90.3991),
//       LatLng(23.78588, 90.39946),
//       LatLng(23.7876, 90.39972),
//       LatLng(23.78804, 90.3998),
//       LatLng(23.78908, 90.39998),
//       LatLng(23.7906, 90.40024),
//       LatLng(23.7929, 90.40063),
//       LatLng(23.79392, 90.40084),
//       LatLng(23.79476, 90.40098),
//       LatLng(23.79842, 90.40157),
//       LatLng(23.80136, 90.40207),
//       LatLng(23.8031, 90.40236),
//       LatLng(23.80454, 90.40248),
//       LatLng(23.80483, 90.40255),
//       LatLng(23.80598, 90.40285),
//       LatLng(23.80644, 90.40292),
//       LatLng(23.80686, 90.40297),
//       LatLng(23.80702, 90.40303),
//       LatLng(23.80738, 90.40309),
//       LatLng(23.80758, 90.40312),
//       LatLng(23.80785, 90.40316),
//       LatLng(23.81035, 90.40357),
//       LatLng(23.81103, 90.40365),
//       LatLng(23.8128, 90.40398),
//       LatLng(23.81421, 90.40421),
//       LatLng(23.81496, 90.40434),
//       LatLng(23.8153, 90.40447),
//       LatLng(23.81548, 90.40456),
//       LatLng(23.81583, 90.40478),
//       LatLng(23.81606, 90.40496),
//       LatLng(23.81635, 90.40528),
//       LatLng(23.81657, 90.40557),
//       LatLng(23.81674, 90.40587),
//       LatLng(23.81684, 90.40606),
//       LatLng(23.81696, 90.40642),
//       LatLng(23.81703, 90.40679),
//       LatLng(23.81705, 90.40709),
//       LatLng(23.817, 90.4084),
//       LatLng(23.81689, 90.41039),
//       LatLng(23.81686, 90.41074),
//       LatLng(23.81688, 90.41123),
//       LatLng(23.81694, 90.41151),
//       LatLng(23.81706, 90.41183),
//       LatLng(23.8173, 90.41231),
//       LatLng(23.8174, 90.41247),
//       LatLng(23.81821, 90.41372),
//       LatLng(23.81894, 90.41484),
//       LatLng(23.81971, 90.41608),
//       LatLng(23.82106, 90.41815),
//       LatLng(23.82138, 90.41861),
//       LatLng(23.82162, 90.41891),
//       LatLng(23.82187, 90.41916),
//       LatLng(23.82226, 90.41946),
//       LatLng(23.82289, 90.41985),
//       LatLng(23.82338, 90.4201),
//       LatLng(23.82374, 90.42022),
//       LatLng(23.82428, 90.42034),
//       LatLng(23.82494, 90.42042),
//       LatLng(23.82553, 90.42041),
//       LatLng(23.82615, 90.42033),
//       LatLng(23.82715, 90.42015),
//       LatLng(23.82939, 90.4198),
//       LatLng(23.83206, 90.41934),
//       LatLng(23.8343, 90.41898),
//       LatLng(23.83575, 90.41872),
//       LatLng(23.8367, 90.41848),
//       LatLng(23.8372, 90.41833),
//       LatLng(23.83799, 90.41806),
//       LatLng(23.83857, 90.4178),
//       LatLng(23.83921, 90.41745),
//       LatLng(23.83945, 90.41729),
//       LatLng(23.8402, 90.41678),
//       LatLng(23.84055, 90.41649),
//       LatLng(23.84105, 90.41612),
//       LatLng(23.84284, 90.4148),
//       LatLng(23.84399, 90.41381),
//       LatLng(23.84517, 90.41284),
//       LatLng(23.84606, 90.41211),
//       LatLng(23.84751, 90.41092),
//       LatLng(23.8483, 90.41026),
//       LatLng(23.84843, 90.41015),
//       LatLng(23.84844, 90.40997),
//       LatLng(23.84843, 90.40983),
//       LatLng(23.84809, 90.40935),
//       LatLng(23.84757, 90.4086),
//       LatLng(23.84708, 90.4079),
//       LatLng(23.84645, 90.40693),
//     ], color: Colors.blue, width: 6),
//     Polyline(polylineId: const PolylineId('route_0'), points: [LatLng(23.73728, 90.40409), LatLng(23.73737, 90.40411), LatLng(23.73743, 90.40411), LatLng(23.73752, 90.40411), LatLng(23.73757, 90.4041), LatLng(23.73762, 90.40408), LatLng(23.73772, 90.40401), LatLng(23.73783, 90.40397), LatLng(23.73793, 90.40392), LatLng(23.73802, 90.40387), LatLng(23.73817, 90.40377), LatLng(23.73829, 90.40369), LatLng(23.73838, 90.40362), LatLng(23.73848, 90.40353), LatLng(23.73871, 90.40329), LatLng(23.73873, 90.40326), LatLng(23.73893, 90.40306), LatLng(23.73909, 90.40284), LatLng(23.73929, 90.40252), LatLng(23.73949, 90.40221), LatLng(23.73968, 90.40188), LatLng(23.73986, 90.40156), LatLng(23.74002, 90.40124), LatLng(23.74004, 90.4012), LatLng(23.7403, 90.40065), LatLng(23.74035, 90.40053), LatLng(23.74045, 90.40031), LatLng(23.74054, 90.40012), LatLng(23.74061, 90.39999), LatLng(23.74066, 90.39991), LatLng(23.74073, 90.39979), LatLng(23.74083, 90.39969), LatLng(23.74099, 90.39952), LatLng(23.74119, 90.39932), LatLng(23.74167, 90.39887), LatLng(23.7419, 90.39862)], color: Colors.red, width: 6),
//
//   };

//Set<Marker> markers = {};
//   Set<Marker> markers = {
//     Marker(
//       markerId: const MarkerId('m0'),
//       position: const LatLng(23.8748324308902, 90.3193790209598),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m1'),
//       position: const LatLng(23.723991414495334, 90.34487367430866),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//   };
//   Set<Circle> circles = {
//     Circle(
//       circleId: const CircleId('c0'),
//       center: const LatLng(23.791659300779475, 90.31407823387542),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c1'),
//       center: const LatLng(23.83089018654928, 90.38621399885903),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//   };
//Set<Polyline> polylines = {};
// Set<Polyline> polylines = {
//   Polyline(
//     polylineId: const PolylineId('route_0'),
//     points: [
//       LatLng(23.827927692117992, 90.46827062827272),
//       LatLng(23.717780289334947, 90.47180242384806),
//       LatLng(23.898770940568056, 90.43989356382797),
//       LatLng(23.80203433502629, 90.44576252518225),
//       LatLng(23.84993206425131, 90.40562704538193),
//       LatLng(23.777015912574996, 90.46507055604579),
//       LatLng(23.730400385711256, 90.38994298860604),
//       LatLng(23.7604275454169, 90.41959254135777),
//       LatLng(23.899707719628385, 90.47470052714806),
//       LatLng(23.77048348832185, 90.32914603040443),
//       LatLng(23.73709264911446, 90.43713298423029),
//       LatLng(23.873158684234763, 90.30085984411623),
//       LatLng(23.832638697224798, 90.31982939569858),
//       LatLng(23.843949686840297, 90.39976639076286),
//       LatLng(23.748975117224887, 90.48336071869959),
//       LatLng(23.86599184295084, 90.30071892061811),
//       LatLng(23.79358629001891, 90.49746688265964),
//       LatLng(23.875744526218885, 90.46305339837996),
//       LatLng(23.762565861748268, 90.35119491486623),
//       LatLng(23.77359509553105, 90.31169058658462),
//       LatLng(23.729318203233362, 90.48955979421133),
//       LatLng(23.867850045475436, 90.3881313290381),
//       LatLng(23.888096588123712, 90.40544562225391),
//       LatLng(23.837177548535642, 90.43896503179319),
//       LatLng(23.88422246417672, 90.37042166948929),
//       LatLng(23.785486704148983, 90.31794271990255),
//       LatLng(23.757504225042364, 90.3353703314164),
//       LatLng(23.853406232457992, 90.49811976148787),
//       LatLng(23.728891857809664, 90.44880086633428),
//       LatLng(23.871774893692145, 90.41680673387252),
//       LatLng(23.8321086993572, 90.35204049508756),
//       LatLng(23.755338920396063, 90.48183989085756),
//       LatLng(23.70752441176325, 90.39138610052896),
//       LatLng(23.714254993351897, 90.31860511483546),
//       LatLng(23.89742705864709, 90.4507109969639),
//       LatLng(23.885186764042185, 90.39611675195242),
//       LatLng(23.713520995817895, 90.37823361363465),
//       LatLng(23.825708309406522, 90.3398849598368),
//       LatLng(23.717930567498694, 90.3234187340253),
//       LatLng(23.898662381831976, 90.43786108560343),
//       LatLng(23.87174842909956, 90.37469303988311),
//       LatLng(23.872842937055058, 90.33253683690876),
//       LatLng(23.728524419038763, 90.45334794316659),
//       LatLng(23.778561960827442, 90.37988898017613),
//       LatLng(23.702098142635695, 90.42711171319282),
//       LatLng(23.86854835977331, 90.39021877899897),
//       LatLng(23.736205152517538, 90.42789793528861),
//       LatLng(23.76653263227957, 90.47837302171544),
//       LatLng(23.83854634771865, 90.43701743306332),
//       LatLng(23.85726443543567, 90.33649289227391),
//       LatLng(23.74081428235824, 90.48750915690094),
//       LatLng(23.724524173553757, 90.40204546697557),
//       LatLng(23.818374524858726, 90.41414823703954),
//       LatLng(23.855770213213276, 90.34177702089467),
//       LatLng(23.892627245097593, 90.49888653729074),
//       LatLng(23.826212191993204, 90.38143418305243),
//       LatLng(23.86232109026882, 90.48616516923357),
//       LatLng(23.73582194400702, 90.41052432649087),
//       LatLng(23.896188719412603, 90.30108258775188),
//       LatLng(23.785185100431075, 90.3862422253244),
//       LatLng(23.739655815259482, 90.4600212009454),
//       LatLng(23.70019164949297, 90.30317893417325),
//       LatLng(23.76972318689497, 90.42443618902126),
//       LatLng(23.816532456295413, 90.33016721933791),
//       LatLng(23.725777329919172, 90.37595045753004),
//       LatLng(23.81697038195652, 90.4205597160272),
//       LatLng(23.838908224020734, 90.43517780349882),
//       LatLng(23.791291849777938, 90.44288633440517),
//       LatLng(23.786409567867732, 90.48232128095972),
//       LatLng(23.867748668236775, 90.31381883930494),
//       LatLng(23.898812914906195, 90.34697867803838),
//       LatLng(23.744285047941315, 90.33267013117373),
//       LatLng(23.712807156732488, 90.40630074791353),
//       LatLng(23.80387151016009, 90.34776784172628),
//       LatLng(23.817215414234667, 90.4863090378719),
//       LatLng(23.708839740905997, 90.39623796279594),
//       LatLng(23.73564815732891, 90.38572367203284),
//       LatLng(23.757486451911735, 90.45086490022089),
//       LatLng(23.79212094361852, 90.37505737647196),
//       LatLng(23.87375635813678, 90.47828306788658),
//       LatLng(23.722143281439376, 90.46030991384393),
//       LatLng(23.846295380979512, 90.44034437143513),
//       LatLng(23.761570421038815, 90.34876253319828),
//       LatLng(23.745221024523833, 90.41637331011984),
//       LatLng(23.870762424864918, 90.33211306424988),
//       LatLng(23.70993198296298, 90.49301925944964),
//       LatLng(23.849452943621145, 90.49969717960526),
//       LatLng(23.740341685561642, 90.36883002370276),
//       LatLng(23.710462478759872, 90.49126105753577),
//       LatLng(23.823622612789567, 90.49703015565994),
//       LatLng(23.805664708576767, 90.318790267735),
//       LatLng(23.77812254846297, 90.40809562644051),
//       LatLng(23.880820635199402, 90.40862610305992),
//       LatLng(23.70965808210814, 90.30993759870945),
//       LatLng(23.878435384220488, 90.42750169186556),
//       LatLng(23.767773796303825, 90.44951497514249),
//       LatLng(23.75573718359476, 90.44163274189204),
//       LatLng(23.86539679347229, 90.38125796773265),
//       LatLng(23.752392634352994, 90.4472713704782),
//       LatLng(23.87686684798841, 90.36516391289776),
//     ],
//     color: Colors.green,
//     width: 6,
//   ),
// };

// // Search and Suggestions
// Set<Circle> circles = {
//   // First cluster
//   Circle(circleId: const CircleId('c0'), center: const LatLng(23.767210638688493, 90.35838621347095), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c1'), center: const LatLng(23.769512, 90.359721), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c2'), center: const LatLng(23.765932, 90.357254), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c3'), center: const LatLng(23.770821, 90.360892), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c4'), center: const LatLng(23.766182, 90.361224), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c5'), center: const LatLng(23.768415, 90.362918), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c6'), center: const LatLng(23.764892, 90.359442), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c7'), center: const LatLng(23.769942, 90.356731), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c8'), center: const LatLng(23.771255, 90.358415), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c9'), center: const LatLng(23.763875, 90.358754), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c10'), center: const LatLng(23.768622, 90.354981), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c11'), center: const LatLng(23.772104, 90.360214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c12'), center: const LatLng(23.767985, 90.363842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c13'), center: const LatLng(23.765214, 90.362155), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c14'), center: const LatLng(23.769451, 90.363112), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c15'), center: const LatLng(23.770942, 90.355915), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c16'), center: const LatLng(23.764385, 90.355842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c17'), center: const LatLng(23.773125, 90.358722), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c18'), center: const LatLng(23.762985, 90.360145), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c19'), center: const LatLng(23.771925, 90.362215), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c20'), center: const LatLng(23.765732, 90.364421), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//
//   // Second cluster
//   Circle(circleId: const CircleId('c21'), center: const LatLng(23.861233, 90.366754), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c22'), center: const LatLng(23.858012, 90.366184), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c23'), center: const LatLng(23.860721, 90.367892), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c24'), center: const LatLng(23.857182, 90.363224), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c25'), center: const LatLng(23.862415, 90.368918), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c26'), center: const LatLng(23.857892, 90.361442), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c27'), center: const LatLng(23.861942, 90.362731), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c28'), center: const LatLng(23.863255, 90.364415), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c29'), center: const LatLng(23.857875, 90.364754), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c30'), center: const LatLng(23.859622, 90.361981), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c31'), center: const LatLng(23.863104, 90.367214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c32'), center: const LatLng(23.859985, 90.369842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c33'), center: const LatLng(23.857214, 90.368155), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c34'), center: const LatLng(23.861451, 90.369112), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c35'), center: const LatLng(23.862942, 90.362915), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c36'), center: const LatLng(23.858385, 90.362842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c37'), center: const LatLng(23.864125, 90.365722), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c38'), center: const LatLng(23.859985, 90.370145), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c39'), center: const LatLng(23.861925, 90.367215), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c40'), center: const LatLng(23.858422, 90.366721), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//
//   // Third cluster
//   Circle(circleId: const CircleId('c41'), center: const LatLng(23.782015, 90.427115), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c42'), center: const LatLng(23.779725, 90.426842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c43'), center: const LatLng(23.781952, 90.424385), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c44'), center: const LatLng(23.778944, 90.425112), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c45'), center: const LatLng(23.782841, 90.426952), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c46'), center: const LatLng(23.780125, 90.428214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c47'), center: const LatLng(23.779452, 90.423985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c48'), center: const LatLng(23.782544, 90.423711), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c49'), center: const LatLng(23.781125, 90.428841), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c50'), center: const LatLng(23.778721, 90.426512), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c51'), center: const LatLng(23.783154, 90.425221), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c52'), center: const LatLng(23.779985, 90.422942), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c53'), center: const LatLng(23.783422, 90.428015), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c54'), center: const LatLng(23.782952, 90.427415), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c55'), center: const LatLng(23.781444, 90.423421), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c56'), center: const LatLng(23.780215, 90.427715), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c57'), center: const LatLng(23.783812, 90.426242), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c58'), center: const LatLng(23.779841, 90.428985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c59'), center: const LatLng(23.782185, 90.424915), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c60'), center: const LatLng(23.780685, 90.423614), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//
//   // Fourth cluster
//   Circle(circleId: const CircleId('c61'), center: const LatLng(23.799452, 90.415842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c62'), center: const LatLng(23.797125, 90.415214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c63'), center: const LatLng(23.798985, 90.416512), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c64'), center: const LatLng(23.796954, 90.414125), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c65'), center: const LatLng(23.799815, 90.413852), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c66'), center: const LatLng(23.798544, 90.417215), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c67'), center: const LatLng(23.800214, 90.415325), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c68'), center: const LatLng(23.797842, 90.416942), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c69'), center: const LatLng(23.796885, 90.413421), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c70'), center: const LatLng(23.799944, 90.416115), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c71'), center: const LatLng(23.797521, 90.417425), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c72'), center: const LatLng(23.798741, 90.413214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c73'), center: const LatLng(23.800452, 90.414842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c74'), center: const LatLng(23.796625, 90.415512), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c75'), center: const LatLng(23.799124, 90.417985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c76'), center: const LatLng(23.797285, 90.412985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c77'), center: const LatLng(23.800821, 90.415942), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c78'), center: const LatLng(23.796985, 90.416214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c79'), center: const LatLng(23.799385, 90.413842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c80'), center: const LatLng(23.798185, 90.418214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//
//   // Fifth cluster
//   Circle(circleId: const CircleId('c81'), center: const LatLng(23.746215, 90.373285), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c82'), center: const LatLng(23.744512, 90.373452), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c83'), center: const LatLng(23.746852, 90.371942), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c84'), center: const LatLng(23.744985, 90.371214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c85'), center: const LatLng(23.745842, 90.373815), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c86'), center: const LatLng(23.743925, 90.372452), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c87'), center: const LatLng(23.747125, 90.372985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c88'), center: const LatLng(23.744421, 90.371842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c89'), center: const LatLng(23.746425, 90.373125), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c90'), center: const LatLng(23.745315, 90.374214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c91'), center: const LatLng(23.744842, 90.370985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c92'), center: const LatLng(23.746852, 90.374452), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c93'), center: const LatLng(23.743985, 90.371625), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c94'), center: const LatLng(23.747215, 90.373521), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c95'), center: const LatLng(23.744652, 90.374115), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c96'), center: const LatLng(23.745985, 90.370842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c97'), center: const LatLng(23.746521, 90.374985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c98'), center: const LatLng(23.743785, 90.372985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c99'), center: const LatLng(23.747421, 90.371942), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c100'), center: const LatLng(23.744214, 90.373785), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//
//   // Sixth cluster
//   Circle(circleId: const CircleId('c101'), center: const LatLng(23.75684527394259, 90.46392165354208), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c102'), center: const LatLng(23.756145273942596, 90.46372165354209), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c103'), center: const LatLng(23.756445273942598, 90.46402165354208), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c104'), center: const LatLng(23.756745273942597, 90.46362165354207), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c105'), center: const LatLng(23.756245273942596, 90.46392165354206), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c106'), center: const LatLng(23.756545273942594, 90.46342165354208), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c107'), center: const LatLng(23.756645273942596, 90.46372165354205), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c108'), center: const LatLng(23.756045273942595, 90.46352165354209), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c109'), center: const LatLng(23.756945273942596, 90.46382165354206), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c110'), center: const LatLng(23.756345273942596, 90.46412165354208), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c111'), center: const LatLng(23.75654527394259, 90.46422165354209), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c112'), center: const LatLng(23.756145273942598, 90.46402165354207), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c113'), center: const LatLng(23.756745273942596, 90.46342165354206), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c114'), center: const LatLng(23.756245273942594, 90.46362165354205), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c115'), center: const LatLng(23.75644527394259, 90.46412165354207), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c116'), center: const LatLng(23.75664527394259, 90.4635216535421), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c117'), center: const LatLng(23.756845273942597, 90.46372165354207), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c118'), center: const LatLng(23.756045273942596, 90.46392165354209), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c119'), center: const LatLng(23.75694527394259, 90.46362165354208), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c120'), center: const LatLng(23.75634527394259, 90.46332165354206), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//
//   // Seventh cluster
//   Circle(circleId: const CircleId('c121'), center: const LatLng(23.729454126104426, 90.41938950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c122'), center: const LatLng(23.728454126104426, 90.41838950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c123'), center: const LatLng(23.729954126104426, 90.41988950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c124'), center: const LatLng(23.728954126104426, 90.41788950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c125'), center: const LatLng(23.730454126104426, 90.41888950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c126'), center: const LatLng(23.728454126104426, 90.41988950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c127'), center: const LatLng(23.729454126104426, 90.41788950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c128'), center: const LatLng(23.730954126104426, 90.41938950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c129'), center: const LatLng(23.727954126104426, 90.41838950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c130'), center: const LatLng(23.729954126104426, 90.42038950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c131'), center: const LatLng(23.730454126104426, 90.42088950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c132'), center: const LatLng(23.727454126104426, 90.41788950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c133'), center: const LatLng(23.730954126104426, 90.41788950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c134'), center: const LatLng(23.727954126104426, 90.42038950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c135'), center: const LatLng(23.729954126104426, 90.41738950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c136'), center: const LatLng(23.728454126104426, 90.41688950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c137'), center: const LatLng(23.731454126104426, 90.41988950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c138'), center: const LatLng(23.729454126104426, 90.42138950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c139'), center: const LatLng(23.731954126104426, 90.41888950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c140'), center: const LatLng(23.727954126104426, 90.41738950725988), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//
//   // Eighth cluster
//   Circle(circleId: const CircleId('c141'), center: const LatLng(23.79548294208009, 90.34614617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c142'), center: const LatLng(23.79348294208009, 90.34414617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c143'), center: const LatLng(23.79498294208009, 90.34714617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c144'), center: const LatLng(23.79398294208009, 90.34314617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c145'), center: const LatLng(23.79598294208009, 90.34564617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c146'), center: const LatLng(23.79448294208009, 90.34814617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c147'), center: const LatLng(23.79648294208009, 90.34414617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c148'), center: const LatLng(23.79398294208009, 90.34614617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c149'), center: const LatLng(23.79548294208009, 90.34364617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c150'), center: const LatLng(23.79498294208009, 90.34464617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c151'), center: const LatLng(23.79648294208009, 90.34664617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c152'), center: const LatLng(23.79348294208009, 90.34564617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c153'), center: const LatLng(23.79598294208009, 90.34714617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c154'), center: const LatLng(23.79448294208009, 90.34364617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c155'), center: const LatLng(23.79648294208009, 90.34514617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c156'), center: const LatLng(23.79398294208009, 90.34714617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c157'), center: const LatLng(23.79548294208009, 90.34464617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c158'), center: const LatLng(23.79498294208009, 90.34664617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c159'), center: const LatLng(23.79648294208009, 90.34764617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c160'), center: const LatLng(23.79348294208009, 90.34414617670126), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//
//   // Additional points with variable radii
//   Circle(circleId: const CircleId('c161'), center: const LatLng(23.854262689364894, 90.3884472638953), radius: 77.05291085405463, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c162'), center: const LatLng(23.763391478912983, 90.35003007519339), radius: 37.346457943981136, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c163'), center: const LatLng(23.660627128987066, 90.4564738122924), radius: 59.168718945649246, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c164'), center: const LatLng(23.89530655785806, 90.40188331012561), radius: 72.42855035253562, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c165'), center: const LatLng(23.89027481067819, 90.3984091356647), radius: 49.303328004986255, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c166'), center: const LatLng(23.823566316944795, 90.4422998780587), radius: 45.59911091710917, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c167'), center: const LatLng(23.755170285025862, 90.39547134776618), radius: 61.56207990238147, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c168'), center: const LatLng(23.779529632649734, 90.41283274228105), radius: 67.05643388118061, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c169'), center: const LatLng(23.721145742709712, 90.45551256599742), radius: 67.98233867485132, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c170'), center: const LatLng(23.82823730705207, 90.35964989872402), radius: 54.70005989862519, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c171'), center: const LatLng(23.759573900867437, 90.42731304688519), radius: 49.96866807943938, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c172'), center: const LatLng(23.891924232100628, 90.3910556023441), radius: 50.20607900861593, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c173'), center: const LatLng(23.88166728277413, 90.38742423557824), radius: 38.17871970230097, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c174'), center: const LatLng(23.679353666549574, 90.43002705576023), radius: 62.01738843645221, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c175'), center: const LatLng(23.741416790789597, 90.42347533046045), radius: 53.024081086879384, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c176'), center: const LatLng(23.729548881380016, 90.3396022281376), radius: 36.060357493324624, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c177'), center: const LatLng(23.8752724422756, 90.33672364292917), radius: 31.784415939446077, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c178'), center: const LatLng(23.684525692434345, 90.46503155339208), radius: 43.542260458627304, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c179'), center: const LatLng(23.781735055738334, 90.43610073143383), radius: 61.155139658907764, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c180'), center: const LatLng(23.779892840281455, 90.43660385645185), radius: 71.83452520139807, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c181'), center: const LatLng(23.847653922020246, 90.33330734134425), radius: 55.39956636833965, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c182'), center: const LatLng(23.67770336680485, 90.47813161398199), radius: 39.12565787158054, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c183'), center: const LatLng(23.806251984779724, 90.36309258815986), radius: 68.39490515954927, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c184'), center: const LatLng(23.716924121397515, 90.33034322516262), radius: 63.53416925811736, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c185'), center: const LatLng(23.854814213468973, 90.33705443107306), radius: 48.46879367317989, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c186'), center: const LatLng(23.702679795990324, 90.38620098652817), radius: 43.50173868246541, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c187'), center: const LatLng(23.79099206796124, 90.3797160244484), radius: 59.66685878047012, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c188'), center: const LatLng(23.740176544461736, 90.38597429426349), radius: 62.69720646094261, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c189'), center: const LatLng(23.754691917439484, 90.47178184189693), radius: 63.57121849244195, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c190'), center: const LatLng(23.74918478718909, 90.44471640814209), radius: 45.002372660207975, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c191'), center: const LatLng(23.867639656081142, 90.39285956694889), radius: 50.99643278766575, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c192'), center: const LatLng(23.82268691326673, 90.3568033244674), radius: 52.994055150409196, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c193'), center: const LatLng(23.829408671260374, 90.47955258245533), radius: 60.10663353969037, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c194'), center: const LatLng(23.745211364381834, 90.35963747204542), radius: 65.95485808974396, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c195'), center: const LatLng(23.733658819099535, 90.35788520339469), radius: 75.85389271132244, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c196'), center: const LatLng(23.748870283147486, 90.44084334210599), radius: 69.10196504279477, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c197'), center: const LatLng(23.855850981837644, 90.46924017518243), radius: 38.25576368286268, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c198'), center: const LatLng(23.858114267095104, 90.35344039621123), radius: 61.94603988013813, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c199'), center: const LatLng(23.864669916047507, 90.39567712926994), radius: 76.93363443547435, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c200'), center: const LatLng(23.82899852537848, 90.44356429427437), radius: 79.69442375341185, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c201'), center: const LatLng(23.698779729704885, 90.47310224764749), radius: 78.3608572474826, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c202'), center: const LatLng(23.878262312499682, 90.42010813591133), radius: 75.12015550457882, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c203'), center: const LatLng(23.693884004013807, 90.4589310212065), radius: 32.427241796563685, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c204'), center: const LatLng(23.868501739769414, 90.49763896483505), radius: 33.917908775155766, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c205'), center: const LatLng(23.837096767929186, 90.49686882134384), radius: 56.497786721729945, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c206'), center: const LatLng(23.877484301491968, 90.49675165459435), radius: 46.80993737956102, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c207'), center: const LatLng(23.862553513708136, 90.43195140229267), radius: 78.3152330836156, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c208'), center: const LatLng(23.800804446935963, 90.43699945344012), radius: 58.75207416535207, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c209'), center: const LatLng(23.790558545436046, 90.38571470064878), radius: 69.0311467093191, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c210'), center: const LatLng(23.724139572325175, 90.4691366865171), radius: 45.81501900399563, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c211'), center: const LatLng(23.815076014320983, 90.45040695814394), radius: 72.34964938720924, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c212'), center: const LatLng(23.793329016078676, 90.36785913925642), radius: 47.702442222872975, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c213'), center: const LatLng(23.82489867366748, 90.49326226370924), radius: 33.31496373894301, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c214'), center: const LatLng(23.8778775714476, 90.37859314860499), radius: 46.375279508251474, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c215'), center: const LatLng(23.784713226805465, 90.43176056236021), radius: 70.52936506966954, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c216'), center: const LatLng(23.82053870431129, 90.49399197560818), radius: 30.03478206497946, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c217'), center: const LatLng(23.89612085469279, 90.46924418862524), radius: 54.399960416363086, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c218'), center: const LatLng(23.86991294208962, 90.47189174201726), radius: 37.411123813621614, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c219'), center: const LatLng(23.728216119136736, 90.3441988360276), radius: 52.53930498947558, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c220'), center: const LatLng(23.7021405989386, 90.46063828921966), radius: 36.12252729714061, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c221'), center: const LatLng(23.80522826531573, 90.40846975625016), radius: 48.73583121286196, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c222'), center: const LatLng(23.808604028386828, 90.45736613918204), radius: 41.388178272842254, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c223'), center: const LatLng(23.694762172615295, 90.33506460802462), radius: 71.15595579238368, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c224'), center: const LatLng(23.704454721413335, 90.34530105799111), radius: 35.10335764403619, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c225'), center: const LatLng(23.84385245681548, 90.36328949373781), radius: 42.913328183190046, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c226'), center: const LatLng(23.72722015468074, 90.35892052753618), radius: 32.075074981926086, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c227'), center: const LatLng(23.81712723037594, 90.40094238385731), radius: 30.382724261270173, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c228'), center: const LatLng(23.77066998561471, 90.47197202458266), radius: 31.580060639170377, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c229'), center: const LatLng(23.685728193111505, 90.38952092035369), radius: 40.47896034952224, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c230'), center: const LatLng(23.814821326679056, 90.38865393422599), radius: 40.733683040679594, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c231'), center: const LatLng(23.799192893139395, 90.46614850775455), radius: 42.10533990789886, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c232'), center: const LatLng(23.88033592211059, 90.42793871228761), radius: 55.646610147184944, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c233'), center: const LatLng(23.746479797268897, 90.44061347509685), radius: 64.98803864460257, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c234'), center: const LatLng(23.845425303446763, 90.41636182244851), radius: 57.92871773518777, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c235'), center: const LatLng(23.83708775587229, 90.4638333435036), radius: 51.70050256199651, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c236'), center: const LatLng(23.831026519656017, 90.33461417020128), radius: 44.37791477280605, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c237'), center: const LatLng(23.762403608833846, 90.4832703542335), radius: 33.51375635399539, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c238'), center: const LatLng(23.794278361406935, 90.4971417656768), radius: 66.59593389120008, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c239'), center: const LatLng(23.8569881483401, 90.33953655541809), radius: 31.262068667853022, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c240'), center: const LatLng(23.742496278679493, 90.41619568460217), radius: 73.49309735693491, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c241'), center: const LatLng(23.744524943490834, 90.42090170341102), radius: 68.9233294555335, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c242'), center: const LatLng(23.728755646666677, 90.4201032837253), radius: 50.098708968380066, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c243'), center: const LatLng(23.699436847227307, 90.4377667696718), radius: 47.95328661381056, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c244'), center: const LatLng(23.757352981520604, 90.40226819773713), radius: 55.33074126191819, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c245'), center: const LatLng(23.780833782151607, 90.4858899739508), radius: 63.20245472246078, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c246'), center: const LatLng(23.800417517552052, 90.3597170441381), radius: 39.504462119821696, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c247'), center: const LatLng(23.80513998836549, 90.49659300928013), radius: 53.03839371187601, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c248'), center: const LatLng(23.83247668791555, 90.3706943136834), radius: 79.04076605410967, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c249'), center: const LatLng(23.814925219101934, 90.43652874104342), radius: 51.188891587745566, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c250'), center: const LatLng(23.67085433515414, 90.38600965851069), radius: 30.592529019503317, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c251'), center: const LatLng(23.824395162853712, 90.46278878015187), radius: 61.43879805406557, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c252'), center: const LatLng(23.767709250585707, 90.37736143462186), radius: 63.7427709993916, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c253'), center: const LatLng(23.862389661764343, 90.4945025111741), radius: 73.93074389941589, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c254'), center: const LatLng(23.84094259817668, 90.38764506108701), radius: 71.81392030705388, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c255'), center: const LatLng(23.744240478222135, 90.4388695974412), radius: 70.36356776536418, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c256'), center: const LatLng(23.673970727021036, 90.34312454844216), radius: 34.610009914003044, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c257'), center: const LatLng(23.699002919396424, 90.3854185474682), radius: 38.210458335542356, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c258'), center: const LatLng(23.815141198275477, 90.38765702618632), radius: 39.408318165028625, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c259'), center: const LatLng(23.885240223928072, 90.46834042307653), radius: 42.78561924705801, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c260'), center: const LatLng(23.897571474243158, 90.39307541296427), radius: 72.60359843398177, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c261'), center: const LatLng(23.73658945074609, 90.34704330502487), radius: 32.498083319857784, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c262'), center: const LatLng(23.794576457957444, 90.46815108543595), radius: 78.98942856429369, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c263'), center: const LatLng(23.82947223088983, 90.36531228751198), radius: 65.38172083816833, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c264'), center: const LatLng(23.676579054080495, 90.41057840294472), radius: 53.80486664898655, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c265'), center: const LatLng(23.66860535446607, 90.48310632556658), radius: 73.94989705752779, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c266'), center: const LatLng(23.759210966804915, 90.42913973286888), radius: 65.26104543275225, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c267'), center: const LatLng(23.812177997702626, 90.40877141944839), radius: 63.94128232252978, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c268'), center: const LatLng(23.786440488702947, 90.45092617463807), radius: 33.890378986606194, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c269'), center: const LatLng(23.886027320348855, 90.4427856542381), radius: 32.53506790517309, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c270'), center: const LatLng(23.865571036112726, 90.45465362666073), radius: 51.30785149393156, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c271'), center: const LatLng(23.72325721792509, 90.337189852958), radius: 75.18923474006753, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c272'), center: const LatLng(23.788136347171417, 90.36584712769637), radius: 37.60043679807511, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c273'), center: const LatLng(23.86616425873542, 90.4170964416316), radius: 78.17376841465823, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c274'), center: const LatLng(23.6949814792108, 90.36993889991632), radius: 44.76589693348271, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c275'), center: const LatLng(23.68926066084182, 90.46583596122562), radius: 36.697898065904724, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c276'), center: const LatLng(23.89002525083037, 90.3380663100737), radius: 30.256807287171334, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c277'), center: const LatLng(23.756116630493853, 90.44979872292784), radius: 42.94384220839236, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c278'), center: const LatLng(23.887843894603993, 90.41202724568367), radius: 62.08187508736465, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c279'), center: const LatLng(23.76196623674419, 90.47105315163023), radius: 30.645082692547394, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c280'), center: const LatLng(23.82519327104692, 90.36481086320572), radius: 78.23235957436705, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c281'), center: const LatLng(23.782770845536177, 90.34436981706955), radius: 55.6680386241207, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c282'), center: const LatLng(23.838724123847836, 90.46403783888996), radius: 66.51824120995988, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c283'), center: const LatLng(23.773220840495576, 90.38350215463736), radius: 45.75923605165697, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c284'), center: const LatLng(23.89175666769019, 90.37613076553589), radius: 56.53664755561105, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c285'), center: const LatLng(23.6756469471513, 90.40711057441202), radius: 32.19599222687754, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c286'), center: const LatLng(23.89364450415646, 90.44780374898775), radius: 76.61269739966116, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c287'), center: const LatLng(23.728940058800628, 90.37545322805343), radius: 74.96675421908682, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c288'), center: const LatLng(23.78228467976051, 90.45544982520568), radius: 79.68541313900397, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c289'), center: const LatLng(23.868206661936735, 90.34984263941627), radius: 59.91839534853506, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c290'), center: const LatLng(23.815142087105947, 90.38189840770335), radius: 46.88894199673307, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c291'), center: const LatLng(23.801877061974622, 90.42112433729262), radius: 56.441115145173754, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c292'), center: const LatLng(23.8267552122619, 90.48552901010497), radius: 50.27844532281046, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c293'), center: const LatLng(23.849578521559852, 90.49869031185703), radius: 49.086287719205004, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c294'), center: const LatLng(23.78663102740274, 90.40889502721733), radius: 30.66941718808971, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c295'), center: const LatLng(23.669467528071618, 90.3882077432778), radius: 67.09546172304022, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c296'), center: const LatLng(23.669834612273387, 90.43295906701245), radius: 33.5677765425997, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c297'), center: const LatLng(23.87977608199115, 90.48705540055984), radius: 63.52602785718652, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c298'), center: const LatLng(23.689572480809353, 90.47953489008144), radius: 39.255087428478205, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c299'), center: const LatLng(23.697855896555847, 90.38308080815341), radius: 64.53223111875286, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c300'), center: const LatLng(23.70270372222549, 90.41891115250843), radius: 50.79250862701799, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c301'), center: const LatLng(23.730316327922168, 90.4084721213657), radius: 53.131418430587075, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c302'), center: const LatLng(23.899317224331007, 90.33567932071618), radius: 31.161630779638966, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c303'), center: const LatLng(23.897323827615796, 90.3528778841156), radius: 49.54820900266097, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c304'), center: const LatLng(23.84376631756742, 90.48856929403408), radius: 50.36802674044488, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c305'), center: const LatLng(23.83402905542777, 90.39495874299438), radius: 32.09765957519061, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c306'), center: const LatLng(23.749789062246702, 90.41102767834423), radius: 30.430027766986672, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c307'), center: const LatLng(23.758360848436816, 90.44496951969758), radius: 45.48062056615357, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c308'), center: const LatLng(23.831153527048475, 90.40569414047519), radius: 47.016504149165186, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c309'), center: const LatLng(23.665026898376745, 90.41435234739616), radius: 75.60108406394043, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c310'), center: const LatLng(23.829521769106748, 90.36057935104027), radius: 66.91563341568494, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c311'), center: const LatLng(23.677776311296597, 90.48619769555674), radius: 61.35838577037934, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c312'), center: const LatLng(23.805915951949295, 90.39029759763348), radius: 61.70769270017868, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c313'), center: const LatLng(23.866057025731415, 90.49336859274635), radius: 34.38322782513096, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c314'), center: const LatLng(23.72640111449872, 90.49697257391877), radius: 70.0988615928299, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c315'), center: const LatLng(23.80144604305107, 90.33890209742755), radius: 79.58571240154913, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c316'), center: const LatLng(23.757958113724378, 90.45225245399499), radius: 53.74106092611045, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c317'), center: const LatLng(23.737460155860106, 90.41486783126673), radius: 60.84936543139453, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c318'), center: const LatLng(23.68984144333762, 90.33010621248029), radius: 36.339944228105075, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c319'), center: const LatLng(23.804856906749773, 90.43477941477695), radius: 37.459369188923764, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c320'), center: const LatLng(23.660891262142854, 90.42662324332201), radius: 68.48294804200086, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c321'), center: const LatLng(23.866213779806813, 90.3805574396146), radius: 35.26562431050024, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c322'), center: const LatLng(23.843595376442895, 90.49177207619229), radius: 30.986171809672044, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c323'), center: const LatLng(23.84596122632743, 90.37694097869955), radius: 44.436364171026014, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c324'), center: const LatLng(23.739202489580645, 90.37017341490282), radius: 57.26457289562716, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c325'), center: const LatLng(23.78008585880681, 90.35092360822298), radius: 53.668513767461384, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c326'), center: const LatLng(23.872228971373467, 90.3915929567414), radius: 71.90716411393457, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c327'), center: const LatLng(23.884859713285504, 90.38470439960754), radius: 42.41940428910241, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c328'), center: const LatLng(23.74873417101916, 90.40401633229999), radius: 78.06924129476025, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c329'), center: const LatLng(23.874934671339645, 90.48361497629931), radius: 79.6183887507556, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c330'), center: const LatLng(23.881849652818257, 90.3966754197209), radius: 62.85670216174592, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c331'), center: const LatLng(23.85044988608085, 90.4099272704138), radius: 42.3743782752241, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c332'), center: const LatLng(23.7297275676271, 90.4376505054702), radius: 63.55650639256186, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c333'), center: const LatLng(23.86887636794993, 90.48502164403382), radius: 49.19340929327029, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c334'), center: const LatLng(23.792463044678925, 90.48182810837153), radius: 31.54989410455782, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c335'), center: const LatLng(23.837272320411966, 90.41692635982834), radius: 45.598915271875256, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c336'), center: const LatLng(23.85674076659523, 90.46982076906377), radius: 42.47682896147171, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c337'), center: const LatLng(23.664548583067628, 90.39679392285248), radius: 51.83422759021469, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c338'), center: const LatLng(23.694197292436698, 90.47431961396958), radius: 30.470872874296262, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c339'), center: const LatLng(23.89139042341064, 90.33882574380564), radius: 70.59326423503944, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c340'), center: const LatLng(23.87704958496204, 90.44159157542295), radius: 65.33870402401737, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c341'), center: const LatLng(23.68988062555188, 90.40802865224124), radius: 54.96227583194247, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c342'), center: const LatLng(23.86063845369956, 90.43925885561407), radius: 65.12415241211917, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c343'), center: const LatLng(23.75732905404222, 90.48507362687556), radius: 76.58240148464768, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c344'), center: const LatLng(23.89982051973992, 90.33026605377717), radius: 71.16629145900036, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c345'), center: const LatLng(23.74578600521311, 90.48460490891424), radius: 71.37908648653215, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c346'), center: const LatLng(23.873458690097188, 90.35246719141536), radius: 57.910538545058856, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c347'), center: const LatLng(23.793199371708404, 90.42323426970215), radius: 50.90446429203873, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c348'), center: const LatLng(23.743910053492346, 90.48501732706006), radius: 48.50796436674645, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c349'), center: const LatLng(23.800751748145817, 90.41948526315983), radius: 44.73305928148967, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c350'), center: const LatLng(23.886728463705545, 90.39155537294579), radius: 33.822990587132274, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c351'), center: const LatLng(23.781385751556233, 90.34138502198164), radius: 50.95062312426849, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c352'), center: const LatLng(23.740110817822504, 90.38782648534564), radius: 53.22596520237148, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c353'), center: const LatLng(23.869563754234733, 90.46012770366913), radius: 46.03757752002676, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c354'), center: const LatLng(23.734969314112437, 90.40713944969336), radius: 73.565462254747, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c355'), center: const LatLng(23.845851162619315, 90.40180012395518), radius: 72.46625164401232, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c356'), center: const LatLng(23.72420042503735, 90.34668884065026), radius: 68.34208884753349, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c357'), center: const LatLng(23.797429295980677, 90.34175058302283), radius: 70.03984826811032, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c358'), center: const LatLng(23.877736103431054, 90.36819869025442), radius: 61.659721405691286, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c359'), center: const LatLng(23.74746360903401, 90.35675919696465), radius: 47.28901837754582, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
//   Circle(circleId: const CircleId('c360'), center: const LatLng(23.706045173532267, 90.3497855709579), radius: 43.93547062792268, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
// };