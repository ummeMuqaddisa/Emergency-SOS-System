import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:resqmob/Class%20Models/sms.dart';
import 'package:resqmob/backend/permission%20handler/location%20services.dart';
import 'package:resqmob/pages/profile/profile.dart';

import '../Class Models/alert.dart';
import '../Class Models/user.dart';
import '../backend/firebase config/Authentication.dart';
import 'package:resqmob/backend/api keys.dart';
import '../backend/firebase config/firebase message.dart';
import '../modules/distance.dart'; // Assuming this path is correct

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  // Initial camera position
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(23.76922413394876, 90.42557442785835),
    zoom: 14.0,
  );

  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = false;
  final Set<Marker> _markers = {}; // Holds all markers for the map
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<RemoteMessage>? _notificationSub;
  StreamSubscription<DocumentSnapshot>? _alertListener;
  StreamSubscription<QuerySnapshot>? _alertMarkerListener;

  LatLng? _navigationDestination;
  bool isDanger = false;
  final Set<Polyline> _polylines = {};

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
    _notificationSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (!mounted) return;

      if (message.notification != null) {
        final title = message.notification?.title ?? 'Notification';
        final body = message.notification?.body ?? '';
        final data = message.data;

        _showNotificationDialog(title, body, data);
      }
    });


    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((Position pos) async {
      animateTo(pos);
      setState(() {
        _currentPosition = pos;
      });
      print('1');
      print(_navigationDestination);
      // ⬇ Live update polyline
      if (_navigationDestination != null) {
        print('2');
        await _getDirections(
          LatLng(pos.latitude, pos.longitude),
          _navigationDestination!,
        );
        _checkArrival(pos, _navigationDestination!);
        print('3');
      }
    });

    // _positionStream = Geolocator.getPositionStream(
    //   locationSettings: LocationSettings(
    //     accuracy: LocationAccuracy.bestForNavigation,
    //     distanceFilter: 1,
    //   ),
    // ).listen((Position pos) async {
    //
    //
    // //   final location = { 'location': {
    // //     'latitude': pos.latitude,
    // //     'longitude': pos.longitude,
    // //     'timestamp': Timestamp.now(),
    // //   }
    // // };
    // // try {
    // //   await FirebaseFirestore.instance
    // //       .collection('Users')
    // //       .doc(FirebaseAuth.instance.currentUser!.uid)
    // //       .set(location, SetOptions(merge: true)); // merge to avoid overwriting other fields
    // // } catch (e) {
    // //   print('Error updating location: $e');
    // // }
    //
    //
    //
    //
    //
    //
    //   animateTo(pos);
    //   setState(() {
    //     _currentPosition = pos;
    //   });
    // });

    try{
      FirebaseFirestore.instance
          .collection('Users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get()
          .then((doc) {
        if (doc.exists) {
          setState(() {
            isDanger = doc.get('isInDanger');
          });

          print('isDanger: $isDanger');
        }
      })
          .catchError((e) => print('Error: $e'));
    }catch(e){
      print(e);
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose

    _positionStream?.cancel();
    _mapController?.dispose();
    _notificationSub?.cancel();
    _alertListener?.cancel();
    super.dispose();
  }

  void _checkInitialMessage() async {
    RemoteMessage? initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      print("🧊 App opened from terminated state via notification");
      _handleMessage(initialMessage);
    }
  }

  void _handleMessage(RemoteMessage message) {
    final data = message.data;

    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? '';

    if (context.mounted) {
      _showNotificationDialog(title, body, data); // or navigate, etc.
    }
  }


  void _showNotificationDialog(String title, String body, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(body),
                const SizedBox(height: 12),
                if (data.isNotEmpty) ...[
                  const Text('Additional Data:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...data.entries.map((entry) => Text('${entry.key}: ${entry.value}')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();

                final userId = FirebaseAuth.instance.currentUser?.uid;
                final double? lat = double.tryParse(data['latitude'].toString());
                final double? lng = double.tryParse(data['longitude'].toString());
                final String? alertId = data['alertId'];
                if (userId != null && alertId != null) {
                  try {
                    final alertRef = FirebaseFirestore.instance.collection('Alerts').doc(alertId);
                    await alertRef.set({
                      'responders': [],
                    }, SetOptions(merge: true));


                    await alertRef.update({
                      'responders': FieldValue.arrayUnion([userId]),
                    });

                    print("User $userId added to responders of alert $alertId");


                  } catch (e) {
                    print("Failed to add responder: $e");
                  }
                } else {
                  print("Missing userId or alertId");
                }

                if (lat != null && lng != null && _currentPosition != null) {
                  print("Getting directions...");
                  _navigationDestination = LatLng(lat, lng);
                  await _getDirections(
                    LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    LatLng(lat, lng),
                  );
                  _checkDanger(alertId!);
                } else {
                  print("Invalid or missing coordinates.");
                }
              },

              child: const Text('Help'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }


  Future<void> _loadAllAlertMarkers() async {
    _alertMarkerListener?.cancel();

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    _alertMarkerListener = FirebaseFirestore.instance
        .collection('Alerts')
        .snapshots()
        .listen((querySnapshot) {
      Set<Marker> updatedMarkers = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final docId = doc.id;

        // Skip: if current user's alert, invalid or safe, or by admin
        if (docId == currentUserId ||
            !data.containsKey('location') ||
            data['location'] == null ||
            data['admin'] == true ||
            data['status'] == 'safe' ||
            data['userId'] == currentUserId) {
          continue;
        }

        final location = data['location'];
        final latitude = location['latitude'];
        final longitude = location['longitude'];

        if (latitude != null && longitude != null) {
          final marker = Marker(
            markerId: MarkerId(docId),
            position: LatLng(latitude, longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
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


  void _checkArrival(Position current, LatLng destination) async{
    final distance = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      destination.latitude,
      destination.longitude,
    );

    if (distance < 5 ) { // You can tune this threshold
      setState(() {
        _navigationDestination = null;
        _polylines.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have arrived at your destination!')),
      );
    }
  }

  void _checkDanger(String alertId) {
    _alertListener?.cancel();

    _alertListener = FirebaseFirestore.instance
        .collection('Alerts')
        .doc(alertId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'];

      if (status == 'safe') {
        print('Alert marked as safe. Stopping navigation.');
        setState(() {
          _navigationDestination = null;
          _polylines.clear();

        });


        // Optionally show feedback
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alert is marked safe. Navigation stopped.')),
          );
        }

        _alertListener?.cancel(); // Stop listening
      }
    });
  }


  // Get current location and add its marker
  Future<void> _getCurrentLocation() async {

    setState(() => _isLoading = true);

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16.0,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      print('Error getting location: $e');
    }
  }

  void animateTo(Position position) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
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


  Future<void> _getDirections(LatLng origin, LatLng destination) async {
    final String _googleApiKey = apiKey.getKey();
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&alternatives=true&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));

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
              lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)),
          northeast: LatLng(
              lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b)),
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
          const SnackBar(content: Text('Something went wrong while fetching directions.')),
        );
      }
    }
  }

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

      // Now show the bottom sheet with fetched user data
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



  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text('View All User'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
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

          print(imageUrl);
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
      const SizedBox(width: 8),
      ],
      ),

      body: Stack(
        children: [

          GoogleMap(
            polylines: _polylines,
            initialCameraPosition: _initialPosition,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              _loadAllAlertMarkers();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: true,
            zoomControlsEnabled: false,
            markers: _markers,
          ),

          // red layer when alert is on
          if(isDanger)
          IgnorePointer(
            child: Container(
              color: Colors.red.withOpacity(0.3), // Adjust opacity as needed
              height: double.infinity,
              width: double.infinity,
            ),
          ),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),

      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "safe",
            onPressed: () async {
              try {
                final uid = FirebaseAuth.instance.currentUser?.uid;

                // Update user's isInDanger flag
                await FirebaseFirestore.instance
                    .collection('Users')
                    .doc(uid)
                    .update({
                  "isInDanger": false,
                });

                // Fetch all alerts for current user
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
                  await doc.reference.update({'status': 'safe'});
                }

                // Optional: Show a snackbar confirmation
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Status updated to safe.")),
                  );
                }
                setState(() {
                  isDanger = false;
                });
              } catch (e) {
                debugPrint("Error updating status: $e");
              }
            },
            backgroundColor: Colors.blue,
            child: const Icon(
              Icons.whatshot,
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

      bottomNavigationBar: BottomNavigationBar(
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.add_alert),
            label: 'alert',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search,
                color: Colors.white,
                size: 28,
              ),
            ),
            label: 'Find',
          ),
          const BottomNavigationBarItem(

            icon: Icon(Icons.sms_outlined),
            label: 'sms',
          ),

        ],
        currentIndex: 1,
        onTap: (index) async{
          try {
            print(index);
            if(index==0){

              print(calculateDistance(LatLng(23.753054483668922, 90.44925302168778),LatLng(23.76949633026305, 90.42552266287973)));


              final data = await FirebaseFirestore.instance.collection('Users').doc(FirebaseAuth.instance.currentUser?.uid).get();
              UserModel user=UserModel.fromJson(data.data()!);
              final length=await FirebaseFirestore.instance.collection('Alerts').get().then((value) => value.docs.length+1);
              final alert= AlertModel(
              alertId: length.toString(),
              userId: user.id,
              userName: user.name,
              userPhone: user.phoneNumber,
              severity: 1,
              status: 'danger',
              timestamp: Timestamp.now(),
              address: user.address,
              message: 'help',
              location: {
                'latitude': _currentPosition!.latitude,
                'longitude': _currentPosition!.longitude,
              }
            );



              if(user.isInDanger==false){
                await FirebaseFirestore.instance.collection('Users').doc(FirebaseAuth.instance.currentUser?.uid).update({
                  'isInDanger': true,
                });

                await FirebaseFirestore.instance.collection('Alerts').doc(alert.alertId).set(alert.toJson());
                print('done');



                final querySnapshot = await FirebaseFirestore.instance.collection('Users').get();
                for (var doc in querySnapshot.docs) {
                  final data = doc.data();
                  final fcm=data['fcmToken'];
                  final currentuser=FirebaseAuth.instance.currentUser!.uid;

                  if("pygVJCfrL7OJLQoRRHbo5yRhsGg1"==doc.id){
                   // print(doc.id);
                    print('0');
                    print(data.toString());
                    print('1');
                    // if(currentuser!=doc.id){
                    print(alert.alertId);
                    FirebaseApi().sendNotification(token: fcm,title: 'Alert',body:  'help meeeeeeeeeeeeee',userId: doc.id,latitude: _currentPosition?.latitude,longitude: _currentPosition?.longitude,alertId:alert.alertId);
                  }
                }
                setState(() {
                  isDanger = true;
                });

              }
              else
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text( "Alert sent already")));

            }
            if(index==1){
              final querySnapshot = await FirebaseFirestore.instance.collection('Users').get();
              for (var doc in querySnapshot.docs) {
                final data = doc.data();
                final fcm=data['fcmToken'];
                final currentuser=FirebaseAuth.instance.currentUser!.uid;

                if("geXyFswHImQbkzX0Up3tSzCQdmE2"==doc.id){
               // if(currentuser!=doc.id){
                  FirebaseApi().sendNotification(token: fcm,title: 'Alert',body:  'help meeeeeeeeeeeeee',userId: currentuser,latitude: _currentPosition?.latitude,longitude: _currentPosition?.longitude);
                }
              }
            }
            if(index==2){
              sendSos(['01839228924','01742092337'], 'Saif', 23.76922413394876, 90.42557442785835);
              print("done");
              print("-----------------------------------");
            }



        } catch (e) {
          debugPrint('Error sending notification: $e');
        }
        },
        selectedItemColor: Colors.blue,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}