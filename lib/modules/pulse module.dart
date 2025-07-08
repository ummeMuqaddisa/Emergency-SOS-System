// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/gestures.dart';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:resqmob/pages/authentication/login.dart';
// import '../backend/firebase config/firebase_options.dart';
// import 'authentication/signup.dart';
//
//
// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key});
//
//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
//   // Updated initial camera position
//   static const CameraPosition _initialPosition = CameraPosition(
//     target: LatLng(23.753222, 90.449305),
//     zoom: 14.0,
//   );
//
//   GoogleMapController? _mapController;
//   Position? _currentPosition;
//   bool _isLoading = false;
//   bool _useInitialLocation = false;
//   bool _isPulsing = false;
//   int _selectedIndex = 0;
//   bool _mapReady = false; // Add map ready state
//
//   late AnimationController _pulseController;
//   late Animation<double> _pulseAnimation1;
//   late Animation<double> _pulseAnimation2;
//   late Animation<double> _pulseAnimation3;
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeAnimations();
//     _requestLocationPermission();
//   }
//
//   void _initializeAnimations() {
//     _pulseController = AnimationController(
//       duration: const Duration(seconds: 2),
//       vsync: this,
//     );
//
//     _pulseAnimation1 = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(CurvedAnimation(
//       parent: _pulseController,
//       curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
//     ));
//
//     _pulseAnimation2 = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(CurvedAnimation(
//       parent: _pulseController,
//       curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
//     ));
//
//     _pulseAnimation3 = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(CurvedAnimation(
//       parent: _pulseController,
//       curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
//     ));
//
//     setState(() {
//       _useInitialLocation = true;
//     });
//   }
//
//   @override
//   void dispose() {
//     _pulseController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _requestLocationPermission() async {
//     try {
//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//       }
//
//       if (permission == LocationPermission.deniedForever) {
//         _showPermissionDialog();
//         return;
//       }
//
//       if (permission == LocationPermission.whileInUse ||
//           permission == LocationPermission.always) {
//         _getCurrentLocation();
//       }
//     } catch (e) {
//       print('Error requesting location permission: $e');
//     }
//   }
//
//   Future<void> _getCurrentLocation() async {
//     setState(() {
//       _isLoading = true;
//     });
//
//     try {
//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//
//       setState(() {
//         _currentPosition = position;
//         _useInitialLocation = false;
//         _isLoading = false;
//       });
//
//       if (_mapController != null && _mapReady) {
//         await _mapController!.animateCamera(
//           CameraUpdate.newCameraPosition(
//             CameraPosition(
//               target: LatLng(position.latitude, position.longitude),
//               zoom: 16.0,
//             ),
//           ),
//         );
//       }
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//         _useInitialLocation = true;
//       });
//       print('Error getting current location: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Unable to get current location. Using default location.'),
//             backgroundColor: Colors.orange,
//           ),
//         );
//       }
//     }
//   }
//
//   void _showPermissionDialog() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Location Permission'),
//           content: const Text(
//             'This app needs location permission to show your current location on the map. Using default location for now.',
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('Cancel'),
//             ),
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 Geolocator.openAppSettings();
//               },
//               child: const Text('Settings'),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   void _togglePulse() {
//     setState(() {
//       _isPulsing = !_isPulsing;
//     });
//
//     if (_isPulsing) {
//       _pulseController.repeat();
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Emergency signal activated!'),
//           backgroundColor: Colors.red,
//           duration: Duration(seconds: 2),
//         ),
//       );
//     } else {
//       _pulseController.stop();
//       _pulseController.reset();
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Emergency signal deactivated'),
//           backgroundColor: Colors.green,
//           duration: Duration(seconds: 2),
//         ),
//       );
//     }
//   }
//
//   void _onItemTapped(int index) {
//     setState(() {
//       _selectedIndex = index;
//     });
//
//     switch (index) {
//       case 0:
//         break;
//       case 1:
//         _togglePulse();
//         break;
//       case 2:
//         break;
//     }
//   }
//
//   LatLng _getPulseLocation() {
//     if (_currentPosition != null && !_useInitialLocation) {
//       return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
//     }
//     return _initialPosition.target;
//   }
//
//   Set<Circle> _generatePulseCircles() {
//     if (!_isPulsing) return {};
//
//     final LatLng center = _getPulseLocation();
//     return {
//       Circle(
//         circleId: const CircleId('pulse_1'),
//         center: center,
//         radius: 30 + (_pulseAnimation1.value * 70),
//         fillColor: Colors.red.withOpacity((1 - _pulseAnimation1.value) * 0.3),
//         strokeColor: Colors.red.withOpacity((1 - _pulseAnimation1.value) * 0.8),
//         strokeWidth: 2,
//       ),
//       Circle(
//         circleId: const CircleId('pulse_2'),
//         center: center,
//         radius: 30 + (_pulseAnimation2.value * 70),
//         fillColor: Colors.red.withOpacity((1 - _pulseAnimation2.value) * 0.3),
//         strokeColor: Colors.red.withOpacity((1 - _pulseAnimation2.value) * 0.8),
//         strokeWidth: 2,
//       ),
//       Circle(
//         circleId: const CircleId('pulse_3'),
//         center: center,
//         radius: 30 + (_pulseAnimation3.value * 70),
//         fillColor: Colors.red.withOpacity((1 - _pulseAnimation3.value) * 0.3),
//         strokeColor: Colors.red.withOpacity((1 - _pulseAnimation3.value) * 0.8),
//         strokeWidth: 2,
//       ),
//       Circle(
//         circleId: const CircleId('accuracy'),
//         center: center,
//         radius: 25,
//         fillColor: Colors.red.withOpacity(0.1),
//         strokeColor: Colors.red.withOpacity(0.5),
//         strokeWidth: 1,
//       ),
//     };
//   }
//
//   Set<Marker> _generateMarkers() {
//     final LatLng location = _getPulseLocation();
//     final bool isCurrentLocation = _currentPosition != null && !_useInitialLocation;
//     return {
//       Marker(
//         markerId: const MarkerId('location_marker1'),
//         position: location,
//         infoWindow: InfoWindow(
//           title: isCurrentLocation ? 'Your Location' : 'Default Location',
//           snippet: isCurrentLocation
//               ? (_isPulsing ? 'Emergency signal active!' : 'Searching nearby...')
//               : (_isPulsing ? 'Emergency signal active!' : 'Dhaka, Bangladesh - Searching...'),
//         ),
//         icon: BitmapDescriptor.defaultMarkerWithHue(
//           _isPulsing
//               ? BitmapDescriptor.hueRed
//               : (isCurrentLocation ? BitmapDescriptor.hueBlue : BitmapDescriptor.hueOrange),
//         ),
//       ),
//
//       Marker(
//         markerId: const MarkerId('location_marker2'),
//         position: LatLng(23.753222, 90.449305), // <-- Use LatLng, not CameraPosition
//         icon: BitmapDescriptor.defaultMarkerWithHue(
//             BitmapDescriptor.hueRed
//         ),
//       ),
//
//
//     };
//   }
//
//   // Handle map creation with error handling
//   void _onMapCreated(GoogleMapController controller) async {
//     try {
//       _mapController = controller;
//
//       // Add a small delay to ensure map is fully initialized
//       await Future.delayed(const Duration(milliseconds: 500));
//
//       setState(() {
//         _mapReady = true;
//       });
//
//       print('Map created successfully');
//     } catch (e) {
//       print('Error creating map: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Map failed to load. Please check your internet connection and API key.'),
//             backgroundColor: Colors.red,
//             duration: Duration(seconds: 5),
//           ),
//         );
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('ResQ Maps'),
//         backgroundColor: Colors.blue,
//         foregroundColor: Colors.white,
//         elevation: 0,
//         actions: [
//           if (_useInitialLocation)
//             IconButton(
//               icon: const Icon(Icons.info_outline),
//               onPressed: () {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Using default location. Tap the location button to try getting your current location.'),
//                     duration: Duration(seconds: 3),
//                   ),
//                 );
//               },
//             ),
//           if (_isPulsing)
//             Container(
//               margin: const EdgeInsets.only(right: 8),
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//               decoration: BoxDecoration(
//                 color: Colors.red,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: const Text(
//                 'EMERGENCY',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 10,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           IconButton(onPressed: (){
//             FirebaseAuth.instance.signOut();
//             Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context)=>const login(),));
//           }, icon:Icon(Icons.logout))
//         ],
//       ),
//       body: Stack(
//         children: [
//           // Map with error handling
//           Container(
//             child: _buildMapWidget(),
//           ),
//           if (_isLoading)
//             Container(
//               color: Colors.black.withOpacity(0.3),
//               child: const Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     CircularProgressIndicator(
//                       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                     ),
//                     SizedBox(height: 16),
//                     Text(
//                       'Searching for your location...',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w500,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           if (_useInitialLocation)
//             Positioned(
//               top: 10,
//               left: 10,
//               right: 10,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 decoration: BoxDecoration(
//                   color: Colors.orange.withOpacity(0.9),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Icon(Icons.location_off, color: Colors.white, size: 16),
//                     const SizedBox(width: 8),
//                     const Expanded(
//                       child: Text(
//                         'Using default location - Dhaka, Bangladesh',
//                         style: TextStyle(color: Colors.white, fontSize: 12),
//                       ),
//                     ),
//                     TextButton(
//                       onPressed: _getCurrentLocation,
//                       child: const Text(
//                         'Get Location',
//                         style: TextStyle(color: Colors.white, fontSize: 12),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _getCurrentLocation,
//         tooltip: 'Get Current Location',
//         backgroundColor: _useInitialLocation ? Colors.orange : Colors.blue,
//         child: _isLoading
//             ? const SizedBox(
//           width: 20,
//           height: 20,
//           child: CircularProgressIndicator(
//             strokeWidth: 2,
//             valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//           ),
//         )
//             : Icon(_useInitialLocation ? Icons.my_location_outlined : Icons.my_location),
//       ),
//       bottomNavigationBar: BottomNavigationBar(
//         items: [
//           const BottomNavigationBarItem(
//             icon: Icon(Icons.home),
//             label: 'Home',
//           ),
//           BottomNavigationBarItem(
//             icon: Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: _isPulsing ? Colors.red : Colors.blue,
//                 shape: BoxShape.circle,
//                 boxShadow: _isPulsing ? [
//                   BoxShadow(
//                     color: Colors.red.withOpacity(0.5),
//                     blurRadius: 10,
//                     spreadRadius: 2,
//                   ),
//                 ] : null,
//               ),
//               child: Icon(
//                 Icons.search,
//                 color: Colors.white,
//                 size: 28,
//               ),
//             ),
//             label: _isPulsing ? 'Stop' : 'Find',
//           ),
//           const BottomNavigationBarItem(
//             icon: Icon(Icons.person),
//             label: 'Profile',
//           ),
//         ],
//         currentIndex: _selectedIndex,
//         selectedItemColor: Colors.blue,
//         onTap: _onItemTapped,
//         type: BottomNavigationBarType.fixed,
//       ),
//     );
//   }
//
//   // Separate widget for map with error handling
//   Widget _buildMapWidget() {
//     return AnimatedBuilder(
//       animation: _pulseController,
//       builder: (context, child) {
//         return GoogleMap(
//           initialCameraPosition: _initialPosition,
//           onMapCreated: _onMapCreated,
//           myLocationEnabled: false,
//           myLocationButtonEnabled: false, // Disable to avoid conflicts
//           compassEnabled: true,
//           mapToolbarEnabled: false, // Disable to avoid issues on some emulators
//           zoomControlsEnabled: false, // Disable to avoid issues on some emulators
//           rotateGesturesEnabled: true,
//           scrollGesturesEnabled: true,
//           tiltGesturesEnabled: true,
//           zoomGesturesEnabled: true,
//           markers: _generateMarkers(),
//           circles: _generatePulseCircles(),
//           // Add map type for better compatibility
//           mapType: MapType.normal,
//           // Add traffic layer
//           trafficEnabled: false,
//           // Add buildings layer
//           buildingsEnabled: true,
//           // Ensure map renders properly on all devices
//           gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
//         );
//       },
//     );
//   }
// }