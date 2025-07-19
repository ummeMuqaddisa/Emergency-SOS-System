import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:resqmob/modules/coordinate%20to%20location.dart';

class test extends StatefulWidget {
  const test({super.key});

  @override
  State<test> createState() => _testState();
}

class _testState extends State<test> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Flutter Map Desktop')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(51.509364, -0.128928), // London
          initialZoom: 9.2,
        ),
        children: [
          TileLayer(
            tileProvider: CancellableNetworkTileProvider(),
            urlTemplate: 'https://mt1.google.com/vt/lyrs=r&x={x}&y={y}&z={z}',
            userAgentPackageName: 'com.example.resqmob',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(51.509364, -0.128928),
                width: 80,
                height: 80,
                child: Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
