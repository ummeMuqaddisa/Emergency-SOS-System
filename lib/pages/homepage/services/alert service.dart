// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:latlong2/latlong.dart';
//
// import '../../../Class Models/alert.dart';
// import '../../../Class Models/pstation.dart';
// import '../../../Class Models/user.dart';
// import '../../../backend/firebase config/firebase message.dart';
// import '../../../modules/distance.dart';
//
// class alertService{
//
//   SendAlert(context,_currentPosition)async{
//
//
//     final data = await FirebaseFirestore.instance.collection('Users').doc(FirebaseAuth.instance.currentUser?.uid).get();
//     UserModel user=UserModel.fromJson(data.data()!);
//     final length=await FirebaseFirestore.instance.collection('Alerts').get().then((value) => value.docs.length+10);
//     final alert= AlertModel(
//         alertId: length.toString(),
//         userId: user.id,
//         userName: user.name,
//         userPhone: user.phoneNumber,
//         severity: 1,
//         status: 'danger',
//         timestamp: Timestamp.now(),
//         address: user.address,
//         message: 'help',
//         location: {
//           'latitude': _currentPosition!.latitude,
//           'longitude': _currentPosition!.longitude,
//         }
//     );
//
//
//
//     if(user.isInDanger==false){
//       await FirebaseFirestore.instance.collection('Users').doc(FirebaseAuth.instance.currentUser?.uid).update({
//         'isInDanger': true,
//       });
//       await FirebaseFirestore.instance.collection('Alerts').doc(alert.alertId).set(alert.toJson());
//       //print('alert create done');
//
//
//
//       //alert distribution for sev 1
//       int notified=0;
//       final querySnapshot = await FirebaseFirestore.instance.collection('Users').get();
//       for (var doc in querySnapshot.docs) {
//         final data = doc.data();
//         final fcm = data['fcmToken'];
//         UserModel ouser = UserModel.fromJson(data);
//         final cloc = user.location;
//         final uloc = ouser.location;
//
//         final distance =calculateDistance(
//             LatLng(cloc?['latitude'], cloc?['longitude'],),
//             LatLng(uloc?['latitude'], uloc?['longitude'],));
//         print('user: ${ouser.name}, distance: $distance');
//
//         if (ouser.id != FirebaseAuth.instance.currentUser?.uid && ouser.admin==false && ouser.isInDanger==false) {
//           if(0<distance && distance<501){
//
//             FirebaseApi().sendNotification(token: fcm,
//                 title: 'Alert',
//                 body: 'help meeeeeeeeeeeeee',
//                 userId: ouser.id,
//                 latitude: _currentPosition?.latitude,
//                 longitude: _currentPosition?.longitude);
//             print('alert sent to ${ouser.name}, distance: $distance');
//             notified=notified+1;
//           }
//         }
//       }
//
//       //sos to emergency contacts
//       final econtacts=user.emergencyContacts;
//       List<String> phoneNumbers = [];
//       for (var contact in econtacts) {
//         phoneNumbers.add(contact.phoneNumber);
//       }
//       // sendSos(phoneNumbers, '${user.name}', _currentPosition!.latitude, _currentPosition!.longitude);
//       print('sos sent to emergency contacts');
//
//
//
//       //police station
//       final police = await FirebaseFirestore.instance.collection('Resources/PoliceStations/Stations').get();
//       var min=10000000000.0;
//       PStationModel? nearStation;
//       for (var doc in police.docs){
//         final stationdata = doc.data();
//         PStationModel station = PStationModel.fromJson(stationdata);
//         final stationloc = station.location;
//         final userloc={'latitude': _currentPosition!.latitude, 'longitude': _currentPosition!.longitude};
//         var shortdis =calculateDistancewithmap(stationloc, userloc);
//         if(shortdis<min){
//           min=shortdis;
//           nearStation = station;
//         }
//       }
//
//
//       //sending sms to police station
//
//       final userloc={'latitude': _currentPosition!.latitude, 'longitude': _currentPosition!.longitude};
//
//       //   sendSos(['${nearStation!.phone}'], '${user.name}', userloc['latitude']!, userloc['longitude']!);
//
//
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text( "Informed to Police station: ${nearStation!.stationName}, ${min.toStringAsFixed(2)} meter away")));
//
//       print('notified: $notified');
//       await FirebaseFirestore.instance
//           .collection('Alerts')
//           .doc(alert.alertId)
//           .update({"pstation": "${nearStation!.stationName}","notified":notified});
//
//
//       setState(() {
//         isDanger = true;
//       });
//
//       //additional danger info
//
//       var dtype='';
//
//       showDialog(
//         context: context,
//         builder: (context) {
//           return AlertDialog(
//             title: const Text("Select Type of Emergency"),
//             content: SingleChildScrollView(
//               scrollDirection: Axis.horizontal,
//               child: Row(
//                 children: [
//                   TextButton(
//                     onPressed: () async{
//                       Navigator.pop(context);
//                       dtype='Accident';
//                       await FirebaseFirestore.instance
//                           .collection('Alerts')
//                           .doc(alert.alertId)
//                           .update({"etype": "${dtype}"});
//                     },
//                     style: TextButton.styleFrom(
//                       backgroundColor: Colors.red.shade100,
//                       foregroundColor: Colors.black,
//                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                     ),
//                     child: const Text("Accident"),
//                   ),
//                   const SizedBox(width: 10),
//                   TextButton(
//                     onPressed: () async{
//                       Navigator.pop(context);
//                       dtype='Threat';
//                       await FirebaseFirestore.instance
//                           .collection('Alerts')
//                           .doc(alert.alertId)
//                           .update({"etype": "${dtype}"});
//                     },
//                     style: TextButton.styleFrom(
//                       backgroundColor: Colors.red.shade100,
//                       foregroundColor: Colors.black,
//                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                     ),
//                     child: const Text("Threat"),
//                   ),
//                   const SizedBox(width: 10),
//                   TextButton(
//                     onPressed: () async{
//                       Navigator.pop(context);
//                       dtype='Medical';
//                       await FirebaseFirestore.instance
//                           .collection('Alerts')
//                           .doc(alert.alertId)
//                           .update({"etype": "${dtype}"});
//                     },
//                     style: TextButton.styleFrom(
//                       backgroundColor: Colors.red.shade100,
//                       foregroundColor: Colors.black,
//                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                     ),
//                     child: const Text("Medical"),
//                   ),
//                 ],
//               ),
//             ),
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           );
//         },
//       );
//
//
//
//
//
//     }
//     else if(user.isInDanger==true){
//       final alert_data= await FirebaseFirestore.instance.collection('Alerts').where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid).where('status',isEqualTo: 'danger').get();
//       AlertModel alert2=AlertModel.fromJson(alert_data.docs.first.data() as Map<String, dynamic>, alert_data.docs.first.id);
//       if(alert2.severity<3){
//         await FirebaseFirestore.instance.collection('Alerts').doc(alert2.alertId).update({
//           'severity': FieldValue.increment(1),
//         });
//
//
//         //alert distribution for sev ++
//         int notified=0;
//
//         final querySnapshot = await FirebaseFirestore.instance.collection('Users').get();
//         for (var doc in querySnapshot.docs) {
//           final data = doc.data();
//           final fcm = data['fcmToken'];
//           UserModel ouser = UserModel.fromJson(data);
//           final cloc = user.location;
//           final uloc = ouser.location;
//
//           final distance =calculateDistance(
//               LatLng(cloc?['latitude'], cloc?['longitude'],),
//               LatLng(uloc?['latitude'], uloc?['longitude'],));
//           print('severity: ${alert2.severity}, user: ${ouser.name}, distance: $distance');
//
//           if (ouser.id != FirebaseAuth.instance.currentUser?.uid && ouser.admin==false && ouser.isInDanger==false) {
//             if(500<distance && distance<10001 && alert2.severity==1){
//
//               FirebaseApi().sendNotification(token: fcm,
//                   title: 'Alert',
//                   body: 'help meeeeeeeeeeeeee',
//                   userId: ouser.id,
//                   latitude: _currentPosition?.latitude,
//                   longitude: _currentPosition?.longitude);
//               print('alert sent to ${ouser.name}, distance: $distance');
//               notified=notified+1;
//             }
//             if( 10000<distance && distance<15000 && alert2.severity==2){
//
//               FirebaseApi().sendNotification(token: fcm,
//                   title: 'Alert',
//                   body: 'help meeeeeeeeeeeeee',
//                   userId: ouser.id,
//                   latitude: _currentPosition?.latitude,
//                   longitude: _currentPosition?.longitude);
//               print('alert sent to ${ouser.name}, distance: $distance');
//               notified=notified+1;
//             }
//           }
//         }
//         print('notified: $notified');
//
//         await FirebaseFirestore.instance
//             .collection('Alerts')
//             .doc(alert2.alertId)
//             .update({"notified":notified});
//
//
//
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text( "Severity increased to ${alert2.severity+1}")));
//       }
//       else{
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text( "Severity already at maximum")));
//       }
//     }
//     else
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text( "Something went wrong")));
//
//   }
//
// }