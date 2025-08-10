import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:resqmob/Class%20Models/sms.dart';
import 'package:resqmob/Class%20Models/social%20model.dart';
import 'package:resqmob/backend/permission%20handler/location%20services.dart';
import 'package:resqmob/pages/alert%20listing/view%20active%20alerts.dart';
import 'package:resqmob/pages/alert%20listing/view%20my%20alerts.dart';
import 'package:resqmob/pages/homepage/safe%20road.dart';
import 'package:resqmob/pages/profile/profile.dart';
import 'package:resqmob/test.dart';
import '../../Class Models/alert.dart';
import '../../Class Models/pstation.dart';
import '../../Class Models/user.dart';
import '../../backend/firebase config/Authentication.dart';
import 'package:resqmob/backend/api keys.dart';
import '../../backend/firebase config/firebase message.dart';
import '../../modules/coordinate to location.dart';
import '../../modules/distance.dart';
import '../community/community.dart';
import 'drawer.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Initial camera position
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(23.8103, 90.4125), // Dhaka coordinates
    zoom: 12.0,
  );

  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = false;
  final Set<Marker> _markers = {}; // Holds all markers for the map
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<RemoteMessage>? _notificationSub;
  StreamSubscription<DocumentSnapshot>? _alertListener;
  StreamSubscription<QuerySnapshot>? _alertMarkerListener;
  UserModel? currentUser;
  var imageLink;
  LatLng? _navigationDestination;
  bool isDanger = false;
  final Set<Polyline> _polylines = {};

  // Add these flags to track map state more robustly
  bool _isMapReady = false;
  bool _isControllerDisposed = false;
  Timer? _cameraAnimationTimer;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    LocationService().getInitialPosition(context);
    _checkInitialMessage();

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print("📥 App opened from background via notification");
      _handleMessage(message);
    });

    _notificationSub =
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (!mounted) return;
          if (message.notification != null) {
            print(
                'message: ${message.notification!.body}, ${message.notification!
                    .title}, ${message.data}');
            final title = message.notification?.title ?? 'Notification';
            final body = message.notification?.body ?? '';
            final data = message.data;
            print(data.toString());
            _showNotificationDialog(title, body, data);
          }
        });

    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      ),
    ).listen((Position pos) async {
      if (!mounted) return;

      // Safe camera animation with proper checks and error recovery
      _safeAnimateTo(pos);

      setState(() {
        _currentPosition = pos;
      });

      print('1');
      print(_navigationDestination);

      // Live update polyline if navigation is active
      if (_navigationDestination != null) {
        print('2');
        await _getDirections(
          LatLng(pos.latitude, pos.longitude),
          _navigationDestination!,
        );
        _checkArrival(pos, _navigationDestination!);
        print('3');
      }
    }, onError: (error) {
      print('Position stream error: $error');
    });


    try {
      FirebaseFirestore.instance
          .collection('Users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get()
          .then((doc) {
        if (doc.exists && mounted) {
          setState(() {
            isDanger = doc.get('isInDanger');
          });
          imageLink = doc.get("profileImageUrl");
          currentUser = UserModel.fromJson(doc.data() as Map<String, dynamic>);
        }
      }).catchError((e) => print('Error: $e'));
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _notificationSub?.cancel();
    _alertListener?.cancel();
    _alertMarkerListener?.cancel();
    _cameraAnimationTimer?.cancel();

    // Mark controller as disposed before disposing
    _isControllerDisposed = true;
    _isMapReady = false;

    // Dispose map controller with a delay to ensure no pending operations
    if (_mapController != null) {
      Future.delayed(Duration(milliseconds: 100), () {
        try {
          _mapController?.dispose();
        } catch (e) {
          print('Error disposing map controller: $e');
        }
      });
    }

    super.dispose();
  }

// map position initialization
  void _reinitializeMapController() {
    if (!mounted) return;

    print('Attempting to reinitialize map controller...');
    _isMapReady = false;
    _isControllerDisposed = true;
    _mapController = null;

    // Force a rebuild of the widget to recreate the map
    setState(() {});
  }


  void _safeAnimateTo(Position position) {
    if (!mounted || _isControllerDisposed || !_isMapReady ||
        _mapController == null) return;

    // Cancel any pending camera animations
    _cameraAnimationTimer?.cancel();

    // Use a timer to debounce rapid camera updates
    _cameraAnimationTimer = Timer(Duration(milliseconds: 100), () {
      if (!mounted || _isControllerDisposed || !_isMapReady ||
          _mapController == null) return;

      try {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(position.latitude, position.longitude),
          ),
        ).catchError((error) {
          print('Camera animation error caught: $error');
          if (error is PlatformException && error.code == 'channel-error') {
            print('Channel error detected, reinitializing map controller');
            _reinitializeMapController();
            return;
          }
          // Try a fallback approach
          _fallbackCameraUpdate(LatLng(position.latitude, position.longitude));
        });
      } catch (e) {
        print('Exception during camera animation: $e');
        if (e is PlatformException && e.code == 'channel-error') {
          print(
              'Channel error detected in catch block, reinitializing map controller');
          _reinitializeMapController();
          return;
        }
        _fallbackCameraUpdate(LatLng(position.latitude, position.longitude));
      }
    });
  }


  void _fallbackCameraUpdate(LatLng target) {
    if (!mounted || _isControllerDisposed || !_isMapReady ||
        _mapController == null) return;

    try {
      // Try a simple camera move instead of animation
      _mapController!.moveCamera(CameraUpdate.newLatLng(target));
    } catch (e) {
      print('Fallback camera update also failed: $e');
      // At this point, we'll just log the error and continue
    }
  }


  Future<void> _safeAnimateCamera(CameraUpdate cameraUpdate,
      {int timeoutSeconds = 5}) async {
    if (!mounted || _isControllerDisposed || !_isMapReady ||
        _mapController == null) return;

    try {
      await _mapController!.animateCamera(cameraUpdate).timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          print('Camera animation timed out');
          throw TimeoutException(
              'Camera animation timeout', Duration(seconds: timeoutSeconds));
        },
      );
    } on TimeoutException {
      print('Camera animation timed out, trying fallback');
      try {
        await _mapController!.moveCamera(cameraUpdate);
      } catch (e) {
        print('Fallback camera move also failed: $e');
      }
    } on PlatformException catch (e) {
      print('Platform exception during camera animation: $e');
      if (e.code == 'channel-error') {
        print('Channel error detected, marking controller as disposed');
        _isControllerDisposed = true;
        _isMapReady = false;
      }
    } catch (e) {
      print('General error during camera animation: $e');
    }
  }


//load marker & navigating
  Future<void> _loadAllAlertMarkers() async {
    _alertMarkerListener?.cancel();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    _alertMarkerListener = FirebaseFirestore.instance
        .collection('Alerts')
        .snapshots()
        .listen((querySnapshot) {
      if (!mounted) return;

      Set<Marker> updatedMarkers = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final docId = doc.id;

        if (docId == currentUserId ||
            !data.containsKey('location') ||
            data['location'] == null ||
            data['admin'] == true ||
            data['status'] == 'safe' ||
            data['userId'] == currentUserId) {
          continue;
        }

        print(data.toString());
        final location = data['location'];
        final latitude = location['latitude'];
        final longitude = location['longitude'];

        if (latitude != null && longitude != null) {
          final marker = Marker(
            markerId: MarkerId(docId),
            position: LatLng(latitude, longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRose),
            onTap: () {
              _showNavigationBottomSheet(LatLng(latitude, longitude), data);
            },
          );
          updatedMarkers.add(marker);
        }
      }

      if (mounted) {
        setState(() {
          _markers.clear();
          _markers.addAll(updatedMarkers);
        });
      }
    }, onError: (e) {
      debugPrint("Marker listener error: $e");
    });
  }


  //for view alert to homepage
  void handleNavigationRequest(double lat, double lng, String alertId) async {
    if (_currentPosition != null) {
      setState(() {
        _navigationDestination = LatLng(lat, lng);
      });
      await _getDirections(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        LatLng(lat, lng),
      );
      _checkDanger(alertId);
      _checkArrival(_currentPosition!, LatLng(lat, lng));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location not available')),
      );
    }
  }

  void _checkArrival(Position current, LatLng destination) async {
    final distance = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      destination.latitude,
      destination.longitude,
    );

    if (distance < 5) { // You can tune this threshold
      setState(() {
        _navigationDestination = null;
        _polylines.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You have arrived at your destination!')),
        );
      }
    }
  }

  void _checkDanger(String alertId) {
    _alertListener?.cancel();
    _alertListener = FirebaseFirestore.instance
        .collection('Alerts')
        .doc(alertId)
        .snapshots()
        .listen(
          (doc) {
        if (!doc.exists || !mounted) return;

        try {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String?; // Explicit type

          if (status == 'safe') {
            _handleSafeAlert();
          }
        } catch (e) {
          debugPrint('Error processing alert update: $e');
        }
      },
      onError: (e) => debugPrint('Alert listener error: $e'),
    );
  }

  void _handleSafeAlert() {
    print('Alert marked as safe. Stopping navigation.');
    if (!mounted) return;

    setState(() {
      _navigationDestination = null;
      _polylines.clear();
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert is marked safe. Navigation stopped.')),
      );
    }
    _alertListener?.cancel();
  }

  // Get current location and add its marker
  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      // Safe camera animation
      await _safeAnimateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16.0,
          ),
        ),
      );

      FirebaseFirestore.instance
          .collection('Users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        'location': {
          'latitude': _currentPosition?.latitude,
          'longitude': _currentPosition?.longitude,
          'timestamp': Timestamp.now(),
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      print('Error getting location: $e');
    }
  }

  void _fitMarkersInView() {
    if (_markers.isEmpty || _mapController == null || !_isMapReady ||
        !mounted || _isControllerDisposed) return;

    double minLat = _markers.first.position.latitude;
    double maxLat = _markers.first.position.latitude;
    double minLng = _markers.first.position.longitude;
    double maxLng = _markers.first.position.longitude;

    for (Marker marker in _markers) {
      minLat =
      minLat < marker.position.latitude ? minLat : marker.position.latitude;
      maxLat =
      maxLat > marker.position.latitude ? maxLat : marker.position.latitude;
      minLng =
      minLng < marker.position.longitude ? minLng : marker.position.longitude;
      maxLng =
      maxLng > marker.position.longitude ? maxLng : marker.position.longitude;
    }

    _safeAnimateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100.0, // padding
      ),
    );
  }

  Future<void> _getDirections(LatLng origin, LatLng destination) async {
    if (!mounted) return;

    final String _googleApiKey = apiKey.getKey();
    final String url = 'https://maps.googleapis.com/maps/api/directions/json?origin=${origin
        .latitude},${origin.longitude}&destination=${destination
        .latitude},${destination
        .longitude}&alternatives=true&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (!mounted) return;

      if (response.statusCode != 200) {
        debugPrint("❌ HTTP error: ${response.statusCode}");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('HTTP Error: ${response.statusCode}')),
          );
        }
        return;
      }

      final data = json.decode(response.body);
      if (data['status'] != 'OK') {
        debugPrint("❌ Directions API error: ${data['status']}");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Directions API Error: ${data['status']}')),
          );
        }
        return;
      }

      final List<Polyline> updatedPolylines = [];
      final List<Color> routeColors = [
        Colors.blue,
        Colors.green,
        Colors.purple,
        Colors.orange,
        Colors.red,
      ];

      LatLngBounds? bounds;
      int colorIndex = 0;

      for (var route in data['routes']) {
        final polylineStr = route['overview_polyline']?['points'];
        if (polylineStr == null) continue;

        final points = PolylinePoints().decodePolyline(polylineStr);
        if (points.isEmpty) continue;

        final polyline = Polyline(
          polylineId: PolylineId('route_$colorIndex'),
          color: routeColors[colorIndex % routeColors.length],
          width: 6,
          points: points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        );

        updatedPolylines.add(polyline);

        final lats = polyline.points.map((p) => p.latitude);
        final lngs = polyline.points.map((p) => p.longitude);

        bounds ??= LatLngBounds(
          southwest: LatLng(
              lats.reduce((a, b) => a < b ? a : b),
              lngs.reduce((a, b) => a < b ? a : b)),
          northeast: LatLng(
              lats.reduce((a, b) => a > b ? a : b),
              lngs.reduce((a, b) => a > b ? a : b)),
        );

        colorIndex++;
      }

      if (context.mounted) {
        setState(() {
          _polylines.clear();
          _polylines.addAll(updatedPolylines);
        });
      }
    } catch (e, stacktrace) {
      debugPrint("❌ Exception during getDirections: $e");
      debugPrint("Stacktrace: $stacktrace");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Something went wrong while fetching directions.')),
        );
      }
    }
  }


//need upgrade
  void _showNavigationBottomSheet(LatLng destination, Map<String, dynamic> data) async {
    final userId = data['userId'];
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID is missing')),
      );
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection("Users").doc(userId).get();
      if (!userDoc.exists || userDoc.data() == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
        return;
      }

      final user = UserModel.fromJson(userDoc.data()!);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      'Navigate to ${user.name}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (user.phoneNumber != null) ...[
                    Text("Name : ${user.phoneNumber}"),
                    const SizedBox(height: 8),
                  ],
                  if (user.email != null) ...[
                    Text("Email: ${user.email}"),
                    const SizedBox(height: 8),
                  ],
                  if (user.isInDanger != null) ...[
                    Text("Danger Status: ${user.isInDanger}"),
                    const SizedBox(height: 8),
                  ],
                  ElevatedButton.icon(
                    icon: const Icon(Icons.navigation),
                    label: const Text('Start Navigation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      if (_currentPosition != null) {
                        final alertRef = FirebaseFirestore.instance.collection('Alerts').doc(data['alertId']);
                        await alertRef.set({
                          'responders': [],
                        }, SetOptions(merge: true));
                        await alertRef.update({
                          'responders': FieldValue.arrayUnion([currentUser!.id]),
                        });
                        print("User $userId added to responders of alert ${data['alertId']}");
                        _navigationDestination = destination;
                        await _getDirections(
                          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          _navigationDestination!,
                        );
                        _checkDanger(data['alertId']);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Current location not available')),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load user info: $e')),
      );
    }
  }


  // Main alert function
  void AlertSystem() async {
    final data = await FirebaseFirestore.instance.collection('Users').doc(FirebaseAuth.instance.currentUser?.uid).get();
    UserModel user = UserModel.fromJson(data.data()!);
    final length = await FirebaseFirestore.instance.collection('Alerts').get().then((value) => value.docs.length + 10);
    String address = await getAddressFromLatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    final alert = AlertModel(
        alertId: length.toString(),
        userId: user.id,
        userName: user.name,
        userPhone: user.phoneNumber,
        severity: 1,
        status: 'danger',
        timestamp: Timestamp.now(),
        address: address,
        message: 'help',
        location: {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
        });

    if (user.isInDanger == false) {
      await FirebaseFirestore.instance.collection('Users').doc(FirebaseAuth.instance.currentUser?.uid).update({
        'isInDanger': true,
      });
      await FirebaseFirestore.instance.collection('Alerts').doc(alert.alertId).set(alert.toJson());

      // Alert distribution for sev 1
      int notified = 0;
      final querySnapshot = await FirebaseFirestore.instance.collection('Users').get();
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final fcm = data['fcmToken'];
        UserModel ouser = UserModel.fromJson(data);
        final cloc = user.location;
        final uloc = ouser.location;
        final distance = calculateDistance(
          LatLng(
            cloc?['latitude'],
            cloc?['longitude'],
          ),
          LatLng(
            uloc?['latitude'],
            uloc?['longitude'],
          ),
        );
        print('user: ${ouser.name}, distance: $distance');
        if (ouser.id != FirebaseAuth.instance.currentUser?.uid &&
            ouser.admin == false &&
            ouser.isInDanger == false) {
          if (0 < distance && distance < 501) {
            FirebaseApi().sendNotification(
                token: fcm,
                title: 'Alert',
                body: 'help!!!',
                userId: ouser.id,
                latitude: _currentPosition?.latitude,
                longitude: _currentPosition?.longitude,
                alertId: alert.alertId);
            print('alert sent to ${ouser.name}, distance: $distance');
            notified = notified + 1;
          }
        }
      }

      // SOS to emergency contacts
      final econtacts = user.emergencyContacts;
      List<String> phoneNumbers = [];
      for (var contact in econtacts) {
        phoneNumbers.add(contact.phoneNumber);
      }
      // sendSos(phoneNumbers, '${user.name}', _currentPosition!.latitude, _currentPosition!.longitude);
      print('sos sent to emergency contacts');

      // Police station
      final police = await FirebaseFirestore.instance.collection('Resources/PoliceStations/Stations').get();
      var min = 10000000000.0;
      PStationModel? nearStation;
      for (var doc in police.docs) {
        final stationdata = doc.data();
        PStationModel station = PStationModel.fromJson(stationdata);
        final stationloc = station.location;
        final userloc = {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude
        };
        var shortdis = calculateDistancewithmap(stationloc, userloc);
        if (shortdis < min) {
          min = shortdis;
          nearStation = station;
        }
      }

      // Sending sms to police station
      final userloc = {
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude
      };
    //   sendSos(['${nearStation!.phone}'], '${user.name}', userloc['latitude']!, userloc['longitude']!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "Informed to Police station: ${nearStation!.stationName}, ${min.toStringAsFixed(2)} meter away")));
      }

      print('notified: $notified');
      await FirebaseFirestore.instance.collection('Alerts').doc(alert.alertId).update({
        "pstation": "${nearStation!.stationName}",
        "notified": notified
      });

      setState(() {
        isDanger = true;
      });

      // Community post
      final post = PostModel(
          id: alert.alertId,
          userId: alert.userId,
          userName: alert.userName,
          userProfileImage: '',
          content:
          'Emergency Alert for ${alert.userName} at ${alert.address} with severity ${alert.severity} and type ${alert.etype}',
          temp: true,
          createdAt: alert.timestamp.toDate(),
          upvotes: [],
          commentCount: 0);
      await FirebaseFirestore.instance.collection('social').doc(alert.alertId).set(post.toJson());
      print('community post created');

      // Additional danger info
      var dtype = '';
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Select Type of Emergency"),
            content: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      dtype = 'Accident';
                      await FirebaseFirestore.instance.collection('Alerts').doc(alert.alertId).update({
                        "etype": "${dtype}"
                      });
                      await FirebaseFirestore.instance.collection('social').doc(alert.alertId).update({
                        'content':
                        'Emergency Alert for ${alert.userName} at ${alert.address} with severity ${alert.severity} and type ${dtype}',
                      });
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Accident"),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      dtype = 'Threat';
                      await FirebaseFirestore.instance.collection('Alerts').doc(alert.alertId).update({
                        "etype": "${dtype}"
                      });
                      await FirebaseFirestore.instance.collection('social').doc(alert.alertId).update({
                        'content':
                        'Emergency Alert for ${alert.userName} at ${alert.address} with severity ${alert.severity} and type ${dtype}',
                      });
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Threat"),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      dtype = 'Medical';
                      await FirebaseFirestore.instance.collection('Alerts').doc(alert.alertId).update({
                        "etype": "${dtype}"
                      });
                      await FirebaseFirestore.instance.collection('social').doc(alert.alertId).update({
                        'content':
                        'Emergency Alert for ${alert.userName} at ${alert.address} with severity ${alert.severity} and type ${dtype}',
                      });
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Medical"),
                  ),
                ],
              ),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          );
        },
      );
    } else if (user.isInDanger == true) {
      final alert_data = await FirebaseFirestore.instance
          .collection('Alerts')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .where('status', isEqualTo: 'danger')
          .get();
      AlertModel alert2 = AlertModel.fromJson(alert_data.docs.first.data() as Map<String, dynamic>, alert_data.docs.first.id);
      if (alert2.severity < 3) {
        await FirebaseFirestore.instance.collection('Alerts').doc(alert2.alertId).update({
          'severity': FieldValue.increment(1),
        });

        // Alert distribution for sev ++
        int notified = alert2.notified;
        final querySnapshot = await FirebaseFirestore.instance.collection('Users').get();
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final fcm = data['fcmToken'];
          UserModel ouser = UserModel.fromJson(data);
          final cloc = user.location;
          final uloc = ouser.location;
          final distance = calculateDistance(
            LatLng(
              cloc?['latitude'],
              cloc?['longitude'],
            ),
            LatLng(
              uloc?['latitude'],
              uloc?['longitude'],
            ),
          );
          print('severity: ${alert2.severity}, user: ${ouser.name}, distance: $distance');
          if (ouser.id != FirebaseAuth.instance.currentUser?.uid &&
              ouser.admin == false &&
              ouser.isInDanger == false) {
            if (500 < distance && distance < 10001 && alert2.severity == 1) {
              FirebaseApi().sendNotification(
                  token: fcm,
                  title: 'Alert',
                  body: 'help!!!',
                  userId: ouser.id,
                  latitude: _currentPosition?.latitude,
                  longitude: _currentPosition?.longitude,
                  alertId: alert2.alertId);
              print('alert sent to ${ouser.name}, distance: $distance');
              notified = notified + 1;
            }
            if (10000 < distance && distance < 15000 && alert2.severity == 2) {
              FirebaseApi().sendNotification(
                  token: fcm,
                  title: 'Alert',
                  body: 'help meeeeeeeeeeeeee',
                  userId: ouser.id,
                  latitude: _currentPosition?.latitude,
                  longitude: _currentPosition?.longitude);
              print('alert sent to ${ouser.name}, distance: $distance');
              notified = notified + 1;
            }
          }
        }
        print('notified: $notified');
        await FirebaseFirestore.instance.collection('Alerts').doc(alert2.alertId).update({
          "notified": notified
        });

        // Community post update
        final post = PostModel(
            id: alert2.alertId,
            userId: alert2.userId,
            userName: alert2.userName,
            userProfileImage: '',
            content:
            'Emergency Alert for ${alert.userName} at ${alert2.address} with severity ${alert2.severity + 1} and type ${alert2.etype}',
            temp: true,
            createdAt: alert2.timestamp.toDate(),
            upvotes: [],
            commentCount: 0);
        await FirebaseFirestore.instance.collection('social').doc(alert2.alertId).set(post.toJson());
        print('community post updated');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Severity increased to ${alert2.severity + 1}")));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Severity already at maximum")));
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Something went wrong")));
      }
    }
  }

  // UI test
  Widget _buildCustomAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 20,
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
            Builder(
              builder: (context) {
                return GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.menu_rounded,
                      color: Color(0xFF1F2937),
                      size: 24,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ResQmob',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Emergency Response System',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => profile(
                        uid: FirebaseAuth.instance.currentUser?.uid,
                      )),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 16,
                        backgroundImage: (imageLink != null && imageLink.isNotEmpty) ? NetworkImage(imageLink) : null,
                        backgroundColor: const Color(0xFFF3F4F6),
                        child: (imageLink == null || imageLink.isEmpty)
                            ? const Icon(Icons.person, size: 16, color: Color(0xFF6B7280))
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertOverlay() {
    return Positioned(
      top: 130,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFEF4444).withOpacity(0.95),
              const Color(0xFFDC2626).withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withOpacity(0.3 + 0.2 * 1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: StreamBuilder(
          stream: FirebaseFirestore.instance
              .collection('Alerts')
              .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
              .where('status', isEqualTo: 'danger')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                  child: Text("No active alerts", style: TextStyle(color: Colors.white)));
            }

            final doc = snapshot.data!.docs.first;
            final alert = AlertModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
            final responderCount = alert.responders?.length ?? 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "EMERGENCY ALERT ACTIVE",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Level ${alert.severity}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildAlertStat("Type", alert.etype ?? "Unspecified"),
                    _buildAlertStat("Notified", "${alert.notified}"),
                    _buildAlertStat("Responding", "$responderCount"),
                  ],
                ),
                if (alert.pstation != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    "Informed Police Station: ${alert.pstation}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAlertStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }






  int _currentIndex = 3;


  @override
  Widget build(BuildContext context) {

    final List<Widget>  _pages = [
      ViewActiveAlertsScreen(
        currentPosition: _currentPosition,
        onNavigate: (lat, lng, alertId) {
          handleNavigationRequest(lat, lng, alertId);
          setState(() => _currentIndex = 3);
        },
      ),
      AlertHistoryScreen(),
      // ... other pages
    ];
    return Scaffold(
      backgroundColor: isDanger? Color(0xFFFFC5C5): Colors.white,
      drawer: AppDrawer(
        currentUser: currentUser,
      ),
      body: (_currentIndex == 3)
          ? Stack(
        children: [
          GoogleMap(
            style: '''
                  [
                    {
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#f5f5f5"
                        }
                      ]
                    },
                    {
                      "elementType": "labels.icon",
                      "stylers": [
                        {
                          "visibility": "off"
                        }
                      ]
                    },
                    {
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#616161"
                        }
                      ]
                    },
                    {
                      "elementType": "labels.text.stroke",
                      "stylers": [
                        {
                          "color": "#f5f5f5"
                        }
                      ]
                    },
                    {
                      "featureType": "administrative",
                      "elementType": "geometry",
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
                          "color": "#bdbdbd"
                        }
                      ]
                    },
                    {
                      "featureType": "poi",
                      "stylers": [
                        {
                          "visibility": "off"
                        }
                      ]
                    },
                    {
                      "featureType": "poi",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#eeeeee"
                        }
                      ]
                    },
                    {
                      "featureType": "poi",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#757575"
                        }
                      ]
                    },
                    {
                      "featureType": "poi.park",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#e5e5e5"
                        }
                      ]
                    },
                    {
                      "featureType": "poi.park",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#9e9e9e"
                        }
                      ]
                    },
                    {
                      "featureType": "road",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#ffffff"
                        }
                      ]
                    },
                    {
                      "featureType": "road",
                      "elementType": "labels.icon",
                      "stylers": [
                        {
                          "visibility": "off"
                        }
                      ]
                    },
                    {
                      "featureType": "road.arterial",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#757575"
                        }
                      ]
                    },
                    {
                      "featureType": "road.highway",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#dadada"
                        }
                      ]
                    },
                    {
                      "featureType": "road.highway",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#616161"
                        }
                      ]
                    },
                    {
                      "featureType": "road.local",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#9e9e9e"
                        }
                      ]
                    },
                    {
                      "featureType": "transit",
                      "stylers": [
                        {
                          "visibility": "off"
                        }
                      ]
                    },
                    {
                      "featureType": "transit.line",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#e5e5e5"
                        }
                      ]
                    },
                    {
                      "featureType": "transit.station",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#eeeeee"
                        }
                      ]
                    },
                    {
                      "featureType": "water",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#c9c9c9"
                        }
                      ]
                    },
                    {
                      "featureType": "water",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#9e9e9e"
                        }
                      ]
                    }
                  ]
                  ''',
            polylines: _polylines,
            initialCameraPosition: _initialPosition,
            mapType: MapType.normal,
            onMapCreated: (GoogleMapController controller) async {
              try {
                _mapController = controller;

                // Add a small delay to ensure the controller is fully initialized
                await Future.delayed(Duration(milliseconds: 300));

                if (mounted && !_isControllerDisposed) {
                  _isMapReady = true;
                  _loadAllAlertMarkers();

                  // Initial camera positioning if we have current location
                  if (_currentPosition != null) {
                    await _safeAnimateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          zoom: 16.0,
                        ),
                      ),
                    );
                  }
                }
              } catch (e) {
                print('Error in onMapCreated: $e');
                _isMapReady = false;
              }
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: true,
            zoomControlsEnabled: false,
            markers: _markers,
          ),
          _buildCustomAppBar(),
          // Red layer when alert is on with alert stat
          if (isDanger)
            IgnorePointer(
              child: Container(
                color: Colors.red.withOpacity(0.2),
                height: double.infinity,
                width: double.infinity,

              ),
            ),
          if (isDanger) _buildAlertOverlay(),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),

          // Control Buttons
          Positioned(
            bottom: 35,
            left: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _getCurrentLocation,
                  heroTag: "location_1",
                  child: Icon(Icons.my_location, color: Colors.blue.shade700),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () async {
                    _mapController?.animateCamera(
                      CameraUpdate.newCameraPosition(_initialPosition),
                    );},
                  heroTag: "location_2",
                  child: Icon(Icons.home, color: Colors.blue.shade700),
                ),
              ],
            ),
          ),
          if (isDanger)
          Positioned(
            bottom: 35,
            right: 16,
            child: FloatingActionButton(
                  backgroundColor: Colors.blue,
                  onPressed: ()async{

                    try {
                      final uid = FirebaseAuth.instance.currentUser?.uid;

                      // Update user's isInDanger flag
                      await FirebaseFirestore.instance
                          .collection('Users')
                          .doc(uid)
                          .update({
                        "isInDanger": false,
                      });

                      final alertSnapshot = await FirebaseFirestore.instance
                          .collection('Alerts')
                          .where('userId', isEqualTo: uid).where('status',isEqualTo: 'danger')
                          .get();
                      print(alertSnapshot.docs.length);
                      if(alertSnapshot.docs.length==0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("No Alert found from you."))
                        );
                        return;
                      }
                      // Update each alert's status to 'safe'
                      for (var doc in alertSnapshot.docs) {
                        await doc.reference.update({'status': 'safe','safeTime': Timestamp.now()});
                      }

                      setState(() {
                        isDanger = false;
                      });

                      //Temp community post delete
                      String postId=alertSnapshot.docs.first.id;
                      try {

                        final postRef = FirebaseFirestore.instance.collection('social').doc(postId);
                        final commentsRef = postRef.collection('comments');

                        final commentsSnapshot = await commentsRef.get();

                        final batch = FirebaseFirestore.instance.batch();

                        for (final doc in commentsSnapshot.docs) {
                          batch.delete(doc.reference);
                        }
                        batch.delete(postRef);

                        await batch.commit();

                        print('Successfully deleted post $postId and all its comments');


                      } catch (e) {
                        print('Error deleting post and comments: $e');
                        rethrow; // Re-throw to handle in calling code
                      }




                      // Optional: Show a snackbar confirmation
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Status updated to safe.")),
                        );
                      }

                    } catch (e) {
                      debugPrint("Error updating status: $e");
                    }

                  },
                  heroTag: "location",
                  child: Text("Safe",style: TextStyle(color: Colors.white,fontSize: 16,fontWeight: FontWeight.bold),),
                ),

          ),

        ],
      )
          : IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButton: _currentIndex == 3
          ? FloatingActionButton.large(
        backgroundColor: Colors.red,
        elevation: 0,
        onPressed: () {
          AlertSystem(); // Call the alert system
        },
        child: Icon(
          Icons.health_and_safety,
          size: 55,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      )
          : FloatingActionButton(
        backgroundColor: Colors.red,
        elevation: 0,
        onPressed: () {
          setState(() {
            _currentIndex = 3;
          });
        },
        child: Icon(
          Icons.home,
          size: 35,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 60,
        color: Color(0xFF3B82F6).withOpacity(0.6),
        notchMargin: 8,
        shape: CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 0;
                  });
                },
                icon: Icon(Icons.crisis_alert_outlined, size: 28,color: Colors.white,),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: null,
                child: Text(''),
              ),
            ),
            Expanded(
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 1;
                  });
                },
                icon: Icon(Icons.safety_check_rounded, size: 28,color: Colors.white,),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //Push notification handler

  void _checkInitialMessage() async {
    RemoteMessage? initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      print(" App opened from terminated state via notification");
      _handleMessage(initialMessage);
    }
  }

  void _handleMessage(RemoteMessage message) {
    final data = message.data;

    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? '';

    if (context.mounted) {
      _showNotificationDialog(title, body, data);
    }
  }


  void _showNotificationDialog(String title, String body, Map<String, dynamic> data) async {

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    print(data.toString());
    try {
      final alertSnapshot = await FirebaseFirestore.instance
          .collection('Alerts')
          .doc(data['alertId'])
          .get();

      if (!alertSnapshot.exists || alertSnapshot.data() == null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert not found')),
        );
        return;
      }

      final alert = AlertModel.fromJson(
        alertSnapshot.data() as Map<String, dynamic>,
        alertSnapshot.id,
      );

      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    body,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF374151)),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Text("Name: ", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                    Expanded(child: Text(alert.userName ?? 'N/A', style: const TextStyle(color: Color(0xFF374151)))),
                  ]),
                  Row(children: [
                    const Text("Location: ", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                    Expanded(child: Text(alert.address ?? 'N/A', style: const TextStyle(color: Color(0xFF374151)))),
                  ]),

                  Row(children: [
                    const Text("Message: ", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                    Expanded(child: Text(alert.message ?? 'N/A', style: const TextStyle(color: Color(0xFF374151)))),
                  ]),

                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();

                  final userId = FirebaseAuth.instance.currentUser?.uid;
                  final double? lat = double.tryParse(
                    data['latitude']?.toString() ?? alert.location?['latitude']?.toString() ?? '',
                  );
                  final double? lng = double.tryParse(
                    data['longitude']?.toString() ?? alert.location?['longitude']?.toString() ?? '',
                  );
                  final String? alertId = data['alertId'] ?? alert.alertId;

                  if (userId != null && alertId != null) {
                    try {
                      final alertRef = FirebaseFirestore.instance.collection('Alerts').doc(alertId);
                      await alertRef.set({'responders': []}, SetOptions(merge: true));
                      await alertRef.update({
                        'responders': FieldValue.arrayUnion([userId]),
                      });
                    } catch (e) {
                      print("Failed to add responder: $e");
                    }
                  }

                  if (lat != null && lng != null && _currentPosition != null) {
                    _navigationDestination = LatLng(lat, lng);
                    await _getDirections(
                      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      LatLng(lat, lng),
                    );
                    _checkDanger(alertId!);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Help'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      Navigator.of(context).pop(); // remove loader
      print("Error fetching alert: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load alert')),
      );
    }
  }


}









//
//
//
//
//
//
//
// GoogleMapController? _mapController;
// Position? _currentPosition;
// bool _isLoading = false;
// final Set<Marker> _markers = {};
// StreamSubscription<Position>? _positionStream;
// StreamSubscription<RemoteMessage>? _notificationSub;
// StreamSubscription<DocumentSnapshot>? _alertListener;
// StreamSubscription<QuerySnapshot>? _alertMarkerListener;
// UserModel? currentUser;
// var imageLink;
// LatLng? _navigationDestination;
// bool isDanger = false;
// final Set<Polyline> _polylines = {};
// late AnimationController _pulseController;
// late AnimationController _slideController;
// bool _showQuickActions = false;
//
// @override
//
//
//
//
//
// @override
// Widget build(BuildContext context) {
//   return Scaffold(
//     backgroundColor: const Color(0xFFF8FAFC),
//     body: Stack(
//       children: [
//         // Map
//
//
//         // Custom App Bar
//         _buildCustomAppBar(),
//
//         // Alert Overlay
//         if (isDanger) _buildAlertOverlay(),
//
//         // Quick Actions
//         _buildQuickActions(),
//
//         // Loading Indicator
//         if (_isLoading)
//           const Center(
//             child: CircularProgressIndicator(
//               color: Color(0xFF3B82F6),
//               strokeWidth: 3,
//             ),
//           ),
//       ],
//     ),
//     bottomNavigationBar: _buildBottomNavigation(),
//   );
// }
//

// Widget _buildAlertOverlay() {
//   return Positioned(
//     top: 120,
//     left: 20,
//     right: 20,
//     child: AnimatedBuilder(
//       animation: _pulseController,
//       builder: (context, child) {
//         return Container(
//           padding: const EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [
//                 const Color(0xFFEF4444).withOpacity(0.95),
//                 const Color(0xFFDC2626).withOpacity(0.95),
//               ],
//             ),
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: const Color(0xFFEF4444).withOpacity(0.3 + 0.2 * _pulseController.value),
//                 blurRadius: 20,
//                 spreadRadius: 5,
//               ),
//             ],
//           ),
//           child: StreamBuilder(
//             stream: FirebaseFirestore.instance
//                 .collection('Alerts')
//                 .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
//                 .where('status', isEqualTo: 'danger')
//                 .snapshots(),
//             builder: (context, snapshot) {
//               if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//                 return const Center(child: Text("No active alerts", style: TextStyle(color: Colors.white)));
//               }
//               final doc = snapshot.data!.docs.first;
//               final alert = AlertModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
//               final responderCount = alert.responders?.length ?? 0;
//
//               return Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
//                       const SizedBox(width: 12),
//                       const Expanded(
//                         child: Text(
//                           "EMERGENCY ALERT ACTIVE",
//                           style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.w800,
//                             color: Colors.white,
//                           ),
//                         ),
//                       ),
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.2),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Text(
//                           "Level ${alert.severity}",
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 12,
//                             fontWeight: FontWeight.w700,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 16),
//                   Row(
//                     children: [
//                       _buildAlertStat("Type", alert.etype ?? "Emergency"),
//                       _buildAlertStat("Notified", "${alert.notified}"),
//                       _buildAlertStat("Responding", "$responderCount"),
//                     ],
//                   ),
//                   if (alert.pstation != null) ...[
//                     const SizedBox(height: 12),
//                     Text(
//                       "Police Station: ${alert.pstation}",
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 14,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ],
//                 ],
//               );
//             },
//           ),
//         );
//       },
//     ),
//   );
// }
//
// Widget _buildAlertStat(String label, String value) {
//   return Expanded(
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: TextStyle(
//             color: Colors.white.withOpacity(0.8),
//             fontSize: 12,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//         const SizedBox(height: 2),
//         Text(
//           value,
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 16,
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//       ],
//     ),
//   );
// }
//
//
//
// Widget _buildBottomNavigation() {
//   return Container(
//     decoration: BoxDecoration(
//       color: Colors.white,
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withOpacity(0.1),
//           blurRadius: 20,
//           offset: const Offset(0, -5),
//         ),
//       ],
//     ),
//     child: SafeArea(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//         child: Row(
//           children: [
//             _buildNavItem(
//               icon: Icons.crisis_alert_outlined,
//               label: 'Active Alerts',
//               onTap: () async {
//                 final result = await Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => ViewActiveAlertsScreen(
//                       currentPosition: _currentPosition,
//                     ),
//                   ),
//                 );
//                 if (result != null && result['navigate'] == true) {
//                   final destination = result['destination'];
//                   final alertData = result['alertData'] as Map<String, dynamic>;
//                   _navigationDestination = LatLng(destination['latitude'], destination['longitude']);
//                   if (_currentPosition != null) {
//                     await _getDirections(
//                       LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
//                       _navigationDestination!,
//                     );
//                     _checkDanger(alertData['alertId']);
//                   }
//                 }
//               },
//             ),
//
//             const SizedBox(width: 20),
//
//             // Emergency Button
//             Expanded(
//               child: GestureDetector(
//                 onTap: AlertSystem,
//                 child: AnimatedBuilder(
//                   animation: _pulseController,
//                   builder: (context, child) {
//                     return Container(
//                       height: 64,
//                       decoration: BoxDecoration(
//                         gradient: LinearGradient(
//                           colors: [
//                             const Color(0xFFEF4444),
//                             const Color(0xFFDC2626),
//                           ],
//                         ),
//                         borderRadius: BorderRadius.circular(20),
//                         boxShadow: [
//                           BoxShadow(
//                             color: const Color(0xFFEF4444).withOpacity(0.4 + 0.2 * _pulseController.value),
//                             blurRadius: 20,
//                             spreadRadius: 2,
//                           ),
//                         ],
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             isDanger ? Icons.add_alert_rounded : Icons.emergency_rounded,
//                             color: Colors.white,
//                             size: 28,
//                           ),
//                           const SizedBox(width: 12),
//                           Text(
//                             isDanger ? 'INCREASE ALERT' : 'EMERGENCY',
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontSize: 16,
//                               fontWeight: FontWeight.w800,
//                               letterSpacing: 0.5,
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ),
//
//             const SizedBox(width: 20),
//
//             _buildNavItem(
//               icon: Icons.history_outlined,
//               label: 'History',
//               onTap: () {
//                 Navigator.of(context).push(
//                   MaterialPageRoute(builder: (context) => AlertHistoryScreen()),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     ),
//   );
// }
//
// Widget _buildNavItem({
//   required IconData icon,
//   required String label,
//   required VoidCallback onTap,
// }) {
//   return GestureDetector(
//     onTap: onTap,
//     child: Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF8FAFC),
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(
//             icon,
//             color: const Color(0xFF6B7280),
//             size: 24,
//           ),
//           const SizedBox(height: 4),
//           Text(
//             label,
//             style: const TextStyle(
//               color: Color(0xFF6B7280),
//               fontSize: 10,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }