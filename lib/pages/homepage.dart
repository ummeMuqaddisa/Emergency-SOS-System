import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:resqmob/Class%20Models/sms.dart';
import 'package:resqmob/backend/permission%20handler/location%20services.dart';
import 'package:resqmob/pages/profile/profile.dart';

import '../backend/firebase config/Authentication.dart';
import '../backend/firebase config/firebase message.dart'; // Assuming this path is correct

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

  void animateTo(Position position) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
    }
  }



  @override
  void initState() {
    super.initState();

    _getCurrentLocation();
    LocationService().getInitialPosition(context);


    // Listen for foreground messages and show dialog
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
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
        distanceFilter: 0,
      ),
    ).listen((Position pos) {
      animateTo(pos);
      setState(() {
        _currentPosition = pos;
      });
    });
  }
  @override
  void dispose() {
    // TODO: implement dispose

    _positionStream?.cancel();
    _mapController?.dispose();
    super.dispose();
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }


  Future<void> _loadAllUserMarkers() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('Users').get();
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      Set<Marker> loadedMarkers = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();

        final docId = doc.id;

       // Skip if: current user, no location, or invalid data
        if (docId == currentUserId ||
            !data.containsKey('location') ||
            data['location'] == null) {
          continue;
        }

        if (data.containsKey('location')) {
          final location = data['location'];
          final latitude = location['latitude'];
          final longitude = location['longitude'];

          if (latitude != null && longitude != null) {
            final marker = Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(latitude, longitude),
              infoWindow: InfoWindow(
                title: data['name'] ?? 'Unknown User',
                snippet: data['email'] ?? '',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
            );
            loadedMarkers.add(marker);
          }
        }
      }

      if (mounted) {
        setState(() {
          _markers.addAll(loadedMarkers);
        });
      }
    } catch (e) {
      debugPrint('Error loading user markers: $e');
    }
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
            initialCameraPosition: _initialPosition,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              _loadAllUserMarkers(); // Load all user markers when the map is created
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: true,
            zoomControlsEnabled: false,
            markers: _markers, // Pass the entire set of markers to the map
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      // Floating action button to toggle view
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "toggle",
            onPressed: _getCurrentLocation,
            backgroundColor:  Colors.blue,
            child: Icon(
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
            icon: Icon(Icons.not_interested_sharp),
            label: '',
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
          final querySnapshot = await FirebaseFirestore.instance.collection('Users').get();
          for (var doc in querySnapshot.docs) {
            final data = doc.data();

            final fcm=data['fcmToken'];
            final currentuser=FirebaseAuth.instance.currentUser!.uid;
            if(currentuser==doc.id){
             FirebaseApi().sendNotification(token: fcm,title: 'Alert',body:  'help meeeeeeeeeeeeee',userId: currentuser,latitude: _currentPosition?.latitude,longitude: _currentPosition?.longitude);
            }

          //

          }

          sendSos(phone: '+8801839228924', name: "XhAfAn", lat: 23.76922413394876, lng:90.42557442785835 );
          print("done");
          print("-----------------------------------");
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