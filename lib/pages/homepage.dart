import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:resqmob/backend/firebase%20config/firebase%20message.dart';
import 'package:resqmob/backend/permission%20handler/location%20services.dart';

import '../backend/firebase config/Authentication.dart'; // Assuming this path is correct

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

      Set<Marker> loadedMarkers = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();

        if (data.containsKey('location')) {
          final location = data['location'];
          print(location);
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

      setState(() {
        _markers.addAll(loadedMarkers); // Assuming _markers is your Set<Marker>
      });
      print("done");
      print("-----------------------------------");
    } catch (e) {
      debugPrint('Error loading user markers: $e');
    }
  }



  // Get current location and add its marker
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );



      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      // Move camera to current location
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16.0,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error getting current location: $e');
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
          IconButton(
            onPressed: () {
              Authentication().signout(context);
            },
            icon: const Icon(Icons.logout),
          ),
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
            zoomControlsEnabled: true,
            markers: _markers, // Pass the entire set of markers to the map
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        tooltip: 'Get Current Location',
        child: const Icon(Icons.my_location),
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
            icon: Icon(Icons.not_interested_sharp),
            label: '',
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
            if(currentuser!=doc.id){
              FirebaseApi().sendNotification(token: fcm,title: 'Alert',body:  'help meeeeeeeeeeeeee',userId: currentuser,latitude: _currentPosition?.latitude,longitude: _currentPosition?.longitude);
            }

          //

          }


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