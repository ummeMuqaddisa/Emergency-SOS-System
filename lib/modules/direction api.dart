import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:resqmob/backend/permission%20handler/location%20services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../backend/firebase config/Authentication.dart';

class MyHomePage2 extends StatefulWidget {
  const MyHomePage2({super.key});

  @override
  State<MyHomePage2> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage2> {
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(23.76877942952722, 90.4255308815893),
    zoom: 14.0,
  );

  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = false;
  final Set<Marker> _markers = {
  };
  final Set<Polyline> _polylines = {};
  final String _googleApiKey = ''; // ← Replace this with your actual key

  late  LatLng _destinationLatLng =
  LatLng(23.736859336096373, 90.40004374720633);

  @override
  void initState() {
    super.initState();
    LocationService().getInitialPosition(context);
  }


  StreamSubscription<Position>? _positionStreamSubscription;

  void _startRealTimeLocationTracking() {
    setState(() => _isLoading = true);

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1, // meters before update triggers
    );

    _positionStreamSubscription?.cancel(); // cancel old if exists

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) async {
      final LatLng currentLatLng = LatLng(position.latitude, position.longitude);

      final Marker currentMarker = Marker(
        markerId: const MarkerId('current_location'),
        position: currentLatLng,
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );

      setState(() {
        _currentPosition = position;
        _markers.removeWhere((m) => m.markerId.value == 'current_location');
        _markers.add(currentMarker);
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: currentLatLng, zoom: 14.0),
        ),
      );

      await _getDirections(currentLatLng, _destinationLatLng);
      setState(() => _isLoading = false);
    }, onError: (e) {
      debugPrint('Real-time location error: $e');
      setState(() => _isLoading = false);
    });
  }


  Future<void> _getDirections(LatLng origin, LatLng destination) async {
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&alternatives=true&key=$_googleApiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        print(data);
        _polylines.clear();
        int colorIndex = 0;
        final List<Color> routeColors = [
          Colors.blue,
          Colors.green,
          Colors.orange,

        ];

        for (var route in data['routes']) {
          final points = PolylinePoints().decodePolyline(
            route['overview_polyline']['points'],
          );

          final polyline = Polyline(
            polylineId: PolylineId('route_$colorIndex'),
            color: routeColors[colorIndex % routeColors.length],
            width: 6,
            points: points
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList(),
          );

          _polylines.add(polyline);
          colorIndex++;
        }

        setState(() {});
      } else {
        debugPrint("Directions API error: ${data['status']}");
      }
    } else {
      debugPrint("HTTP error: ${response.statusCode}");
    }
  }
  void _handleMapLongPress(LatLng latLng) {
    _destinationLatLng=latLng;
    final newMarker = Marker(
      markerId: MarkerId('marker_${latLng.latitude}_${latLng.longitude}'),
      position: latLng,
      infoWindow: const InfoWindow(title: 'Custom Marker'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );


    setState(() {
      _markers.add(newMarker);
    });

    debugPrint("Marker added at: ${latLng.latitude}, ${latLng.longitude}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ResQ Maps'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Authentication().signout(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: true,
            zoomControlsEnabled: true,
            markers: _markers,
            polylines: _polylines,
            onLongPress: _handleMapLongPress,
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startRealTimeLocationTracking,
        tooltip: 'Get Directions',
        child: const Icon(Icons.directions),
      ),
    );
  }
}
