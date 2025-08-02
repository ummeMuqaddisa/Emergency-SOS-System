// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:latlong2/latlong.dart';
//
// import '../../../Class Models/user.dart';
// import '../../../modules/distance.dart';
//
// class alertService{
//
//   fcm(UserModel user)async{
//
//     final querySnapshot = await FirebaseFirestore.instance.collection('Users').get();
//     for (var doc in querySnapshot.docs) {
//       final data = doc.data();
//       final fcm = data['fcmToken'];
//       UserModel ouser = UserModel.fromJson(data);
//       final cloc = user.location;
//       final uloc = ouser.location;
//       print(cloc);
//       print(uloc);
//
//       if (ouser.id != FirebaseAuth.instance.currentUser?.uid) {
//         print(calculateDistance(LatLng(23.753054483668922, 90.44925302168778),LatLng(23.76949633026305, 90.42552266287973)));
//
//       }
//     }
//   }
//
// }