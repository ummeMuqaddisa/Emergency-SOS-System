import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AddPoliceStations extends StatefulWidget {
  AddPoliceStations({super.key});

  @override
  State<AddPoliceStations> createState() => _AddPoliceStationsState();
}

class _AddPoliceStationsState extends State<AddPoliceStations> {
  final List<Map<String, dynamic>> allStations = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    FirebaseFirestore.instance.collection('Resources/PoliceStations/Stations').get().then((querySnapshot) {
      setState(() {
        allStations.clear();
        for (final doc in querySnapshot.docs) {
          allStations.add(doc.data());
        }
      });
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Police Stations'),
        actions: [
          ElevatedButton(
            child: const Text('Add Police Stations'),
            onPressed: () async {

            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: allStations.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(
                    allStations[index]['stationName'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(allStations[index]['address']),
                      const SizedBox(height: 4),
                      Text(
                        'Latitude: ${allStations[index]['location']['latitude']}, '
                            'Longitude: ${allStations[index]['location']['longitude']}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if ((allStations[index]['phone'] as String).isNotEmpty)
                        Text(
                          'Phone: ${allStations[index]['phone']}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                  isThreeLine: true,
                );

              },
            ),
          ),

        ],
      ),
    );
  }
}