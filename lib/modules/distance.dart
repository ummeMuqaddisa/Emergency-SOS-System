import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Returns distance in meters between two LatLng points
///
double calculateDistance(LatLng start, LatLng end) {
  return Geolocator.distanceBetween(
    start.latitude,
    start.longitude,
    end.latitude,
    end.longitude,
  );
}

double calculateDistancewithmap(Map<String, dynamic> start, Map<String, dynamic> end) {
  return Geolocator.distanceBetween(
    start['latitude'] as double,
    start['longitude'] as double,
    end['latitude'] as double,
    end['longitude'] as double,
  );
}

//
// LatLng pointA = LatLng(23.772532008881708, 90.4253052285482);
// LatLng pointB = LatLng(23.76922413394876, 90.42557442785835);
//
// double distanceInMeters = calculateDistance(pointA, pointB);
// print("Distance: ${distanceInMeters.toStringAsFixed(2)} meters");
