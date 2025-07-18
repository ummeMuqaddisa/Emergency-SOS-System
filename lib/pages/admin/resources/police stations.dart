import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AddPoliceStations extends StatelessWidget {
  AddPoliceStations({super.key});
  final List<Map<String, dynamic>> allStations = [
    {
      "stationName": "Adabor",
      "phone": "",
      "location": {"longitude": 90.364007, "latitude": 23.786850},
      "address": "House#105/A, Ring road, Shamoli, Dhaka."
    },
    {
      "stationName": "Badda",
      "phone": "",
      "location": {"longitude": 90.427392, "latitude": 23.772391},
      "address": "H-12/A, R-17, DIT Project, Marul Badda, Dhaka."
    },
    {
      "stationName": "Banani",
      "phone": "",
      "location": {"longitude": 90.401364, "latitude": 23.793175},
      "address": "R-7, H-37, Banani, Dhaka."
    },
    {
      "stationName": "Bangshal",
      "phone": "",
      "location": {"longitude": 90.4082, "latitude": 23.7107},
      "address": "1/1-A, Bangshal Road, Dhaka."
    },
    {
      "stationName": "Cantonment",
      "phone": "",
      "location": {"longitude": 90.4018, "latitude": 23.8055},
      "address": "Cantonment Thana, Dhaka."
    },
    {
      "stationName": "Chakbazar",
      "phone": "",
      "location": {"longitude": 90.3998, "latitude": 23.7112},
      "address": "Chawkbazar Thana, Dhaka."
    },
    {
      "stationName": "Darus Salam",
      "phone": "",
      "location": {"longitude": 90.3546, "latitude": 23.7984},
      "address": "Darus Salam Thana, Dhaka."
    },
    {
      "stationName": "Demra",
      "phone": "",
      "location": {"longitude": 90.4938, "latitude": 23.7258},
      "address": "Demra Thana, Dhaka."
    },
    {
      "stationName": "Dhanmondi",
      "phone": "",
      "location": {"longitude": 90.3789, "latitude": 23.7465},
      "address": "Dhanmondi Thana, Dhaka."
    },
    {
      "stationName": "Gendaria",
      "phone": "",
      "location": {"longitude": 90.4258, "latitude": 23.7001},
      "address": "Gendaria Thana, Dhaka."
    },
    {
      "stationName": "Gulshan",
      "phone": "",
      "location": {"longitude": 90.4139, "latitude": 23.7925},
      "address": "Gulshan Thana, Dhaka."
    },
    {
      "stationName": "Hazaribagh",
      "phone": "",
      "location": {"longitude": 90.3705, "latitude": 23.7317},
      "address": "Hazaribagh Thana, Dhaka."
    },
    {
      "stationName": "Kafrul",
      "phone": "",
      "location": {"longitude": 90.3855, "latitude": 23.8016},
      "address": "Kafrul Thana, Dhaka."
    },
    {
      "stationName": "Kamrangirchar",
      "phone": "",
      "location": {"longitude": 90.3769, "latitude": 23.7081},
      "address": "Kamrangirchar Thana, Dhaka."
    },
    {
      "stationName": "Khilgaon",
      "phone": "",
      "location": {"longitude": 90.4313, "latitude": 23.7548},
      "address": "Khilgaon Thana, Dhaka."
    },
    {
      "stationName": "Kotwali",
      "phone": "",
      "location": {"longitude": 90.4103, "latitude": 23.7077},
      "address": "Kotwali Thana, Dhaka."
    },
    {
      "stationName": "Lalbagh",
      "phone": "",
      "location": {"longitude": 90.3883, "latitude": 23.7165},
      "address": "Lalbagh Thana, Dhaka."
    },
    {
      "stationName": "Mirpur",
      "phone": "",
      "location": {"longitude": 90.3667, "latitude": 23.8055},
      "address": "Mirpur Thana, Dhaka."
    },
    {
      "stationName": "Mohammadpur",
      "phone": "",
      "location": {"longitude": 90.3644, "latitude": 23.7649},
      "address": "Mohammadpur Thana, Dhaka."
    },
    {
      "stationName": "Motijheel",
      "phone": "",
      "location": {"longitude": 90.4206, "latitude": 23.7313},
      "address": "Motijheel Thana, Dhaka."
    },
    {
      "stationName": "Pallabi",
      "phone": "",
      "location": {"longitude": 90.3649, "latitude": 23.8219},
      "address": "Pallabi Thana, Dhaka."
    },
    {
      "stationName": "Ramna",
      "phone": "",
      "location": {"longitude": 90.4019, "latitude": 23.7423},
      "address": "Ramna Thana, Dhaka."
    },
    {
      "stationName": "Sabujbagh",
      "phone": "",
      "location": {"longitude": 90.4418, "latitude": 23.7451},
      "address": "Sabujbagh Thana, Dhaka."
    },
    {
      "stationName": "Shah Ali",
      "phone": "",
      "location": {"longitude": 90.3475, "latitude": 23.8115},
      "address": "Shah Ali Thana, Dhaka."
    },
    {
      "stationName": "Shahbagh",
      "phone": "",
      "location": {"longitude": 90.3985, "latitude": 23.7411},
      "address": "Shahbagh Thana, Dhaka."
    },
    {
      "stationName": "Sher-e-Bangla Nagar",
      "phone": "",
      "location": {"longitude": 90.3789, "latitude": 23.7628},
      "address": "Sher-e-Bangla Nagar Thana, Dhaka."
    },
    {
      "stationName": "Sutrapur",
      "phone": "",
      "location": {"longitude": 90.4192, "latitude": 23.7067},
      "address": "Sutrapur Thana, Dhaka."
    },
    {
      "stationName": "Tejgaon",
      "phone": "",
      "location": {"longitude": 90.3926, "latitude": 23.7623},
      "address": "Tejgaon Thana, Dhaka."
    },
    {
      "stationName": "Turag",
      "phone": "",
      "location": {"longitude": 90.3871, "latitude": 23.8718},
      "address": "Turag Thana, Dhaka."
    },
    {
      "stationName": "Uttara",
      "phone": "",
      "location": {"longitude": 90.4023, "latitude": 23.8752},
      "address": "Uttara Thana, Dhaka."
    },
    {
      "stationName": "Vatara",
      "phone": "",
      "location": {"longitude": 90.4358, "latitude": 23.8105},
      "address": "Vatara Thana, Dhaka."
    },
    {
      "stationName": "Wari",
      "phone": "",
      "location": {"longitude": 90.4211, "latitude": 23.7083},
      "address": "Wari Thana, Dhaka."
    }
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Police Stations'),
        actions: [
          ElevatedButton(
            child: const Text('Add All Police Stations'),
            onPressed: () async {
              // All station data in proper format


              try {
                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Adding police stations...'),
                      ],
                    ),
                  ),
                );

                // Use batch for better performance
                final WriteBatch batch = FirebaseFirestore.instance.batch();
                final CollectionReference stationsRef =
                FirebaseFirestore.instance.collection('Resources/PoliceStations/Stations');

                for (final stationData in allStations) {
                  final String stationName = stationData['stationName'];
                  final DocumentReference stationDoc = stationsRef.doc(stationName);
                  batch.set(stationDoc, stationData);
                }

                await batch.commit();

                // Hide loading dialog
                Navigator.pop(context);

                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Successfully added ${allStations.length} police stations'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                // Hide loading dialog if still showing
                Navigator.pop(context);

                // Show error message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to add stations: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
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