import 'package:geocoding/geocoding.dart';

Future<String> getAddressFromLatLng(double lat, double lng) async {
  try {
    print(lat.toString());
    List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
    print(placemarks.toString());
    if (placemarks.isNotEmpty) {
      final place = placemarks.first;
      print(place.toString());
      return "${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}";
    }
    return "Unknown location";
  } catch (e) {
    print('shit');
    return "Unknown location";
  }
}