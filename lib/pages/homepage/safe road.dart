import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:resqmob/backend/api%20keys.dart';

class SafetyMap extends StatefulWidget {
  const SafetyMap({Key? key}) : super(key: key);

  @override
  _SafetyMapState createState() => _SafetyMapState();
}

class _SafetyMapState extends State<SafetyMap> {
  // Controllers and Completers
  final Completer<GoogleMapController> _controller = Completer();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  // Google API Key - Replace with your actual API key
   String googleApiKey = apiKey.getKey();

  // Validation for API key

  // Map and Location Variables
  GoogleMapController? mapController;
  Position? currentPosition;
  LatLng? destinationLocation;
//   Set<Marker> markers = {
//     Marker(
//       markerId: const MarkerId('m1'),
//       position: const LatLng(23.7421, 90.39849),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m2'),
//       position: const LatLng(23.7373, 90.4041),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//   };
//
// // Add corresponding circles
//   Set<Circle> circles = {
//     Circle(
//       circleId: const CircleId('c1'),
//       center: const LatLng(23.7421, 90.39849),
//       radius: 500, // in meters
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c2'),
//       center: const LatLng(23.7373, 90.4041),
//       radius: 500, // in meters
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//   };
//   Set<Polyline> polylines = {
//
//     Polyline(polylineId: const PolylineId('route_1'), points: [
//       LatLng(23.73731, 90.4041),
//       LatLng(23.73743, 90.40411),
//       LatLng(23.73757, 90.4041),
//       LatLng(23.73772, 90.40401),
//       LatLng(23.73793, 90.40392),
//       LatLng(23.73817, 90.40377),
//       LatLng(23.73838, 90.40362),
//       LatLng(23.73871, 90.40329),
//       LatLng(23.73893, 90.40306),
//       LatLng(23.73929, 90.40252),
//       LatLng(23.73968, 90.40188),
//       LatLng(23.74002, 90.40124),
//       LatLng(23.7403, 90.40065),
//       LatLng(23.74061, 90.39999),
//       LatLng(23.74073, 90.39979),
//       LatLng(23.74099, 90.39952),
//       LatLng(23.74167, 90.39887),
//       LatLng(23.7419, 90.39861),
//       LatLng(23.7419, 90.39858),
//       LatLng(23.74192, 90.39853),
//       LatLng(23.74196, 90.39848),
//       LatLng(23.74201, 90.39846),
//       LatLng(23.7421, 90.39849),
//       LatLng(23.74215, 90.39856),
//       LatLng(23.74215, 90.39862),
//       LatLng(23.74215, 90.39864),
//       LatLng(23.74225, 90.39877),
//       LatLng(23.74229, 90.3989),
//       LatLng(23.74231, 90.39904),
//       LatLng(23.74371, 90.40364),
//       LatLng(23.74388, 90.40432),
//       LatLng(23.74409, 90.40484),
//       LatLng(23.74435, 90.40484),
//       LatLng(23.74474, 90.40441),
//       LatLng(23.74491, 90.40427),
//       LatLng(23.74516, 90.40413),
//       LatLng(23.74587, 90.40403),
//       LatLng(23.74597, 90.40402),
//       LatLng(23.74653, 90.40398),
//       LatLng(23.74745, 90.40393),
//       LatLng(23.74799, 90.40385),
//       LatLng(23.74834, 90.40378),
//       LatLng(23.74843, 90.40375),
//       LatLng(23.74866, 90.40359),
//       LatLng(23.74878, 90.40352),
//       LatLng(23.74935, 90.40317),
//       LatLng(23.75023, 90.40266),
//       LatLng(23.75115, 90.4021),
//       LatLng(23.75222, 90.40149),
//       LatLng(23.75344, 90.40075),
//       LatLng(23.75366, 90.40059),
//       LatLng(23.75397, 90.40039),
//       LatLng(23.75445, 90.40013),
//       LatLng(23.75485, 90.3999),
//       LatLng(23.75523, 90.39975),
//       LatLng(23.75544, 90.39968),
//       LatLng(23.75561, 90.39961),
//       LatLng(23.75615, 90.39934),
//       LatLng(23.75659, 90.39911),
//       LatLng(23.75677, 90.39903),
//       LatLng(23.75693, 90.39899),
//       LatLng(23.75704, 90.39899),
//       LatLng(23.75725, 90.39899),
//       LatLng(23.75796, 90.39911),
//       LatLng(23.75863, 90.39917),
//       LatLng(23.75876, 90.39918),
//       LatLng(23.75943, 90.39927),
//       LatLng(23.76098, 90.39951),
//       LatLng(23.76116, 90.39954),
//       LatLng(23.76147, 90.39958),
//       LatLng(23.76217, 90.39974),
//       LatLng(23.76248, 90.39979),
//       LatLng(23.76363, 90.4),
//       LatLng(23.76448, 90.40011),
//       LatLng(23.76611, 90.40038),
//       LatLng(23.76827, 90.40071),
//       LatLng(23.76883, 90.4008),
//       LatLng(23.76913, 90.40086),
//       LatLng(23.7699, 90.40102),
//       LatLng(23.7705, 90.40111),
//       LatLng(23.77061, 90.40113),
//       LatLng(23.77116, 90.4011),
//       LatLng(23.77144, 90.40107),
//       LatLng(23.77206, 90.40088),
//       LatLng(23.77257, 90.40052),
//       LatLng(23.77307, 90.40019),
//       LatLng(23.77331, 90.4),
//       LatLng(23.7741, 90.39946),
//       LatLng(23.77452, 90.39917),
//       LatLng(23.77477, 90.39905),
//       LatLng(23.77529, 90.39879),
//       LatLng(23.77573, 90.39861),
//       LatLng(23.7769, 90.39834),
//       LatLng(23.77753, 90.39823),
//       LatLng(23.77775, 90.39817),
//       LatLng(23.77795, 90.39817),
//       LatLng(23.77833, 90.39819),
//       LatLng(23.77881, 90.39827),
//       LatLng(23.77902, 90.39827),
//       LatLng(23.77918, 90.39825),
//       LatLng(23.77932, 90.39828),
//       LatLng(23.77976, 90.39835),
//       LatLng(23.78106, 90.39859),
//       LatLng(23.78134, 90.39864),
//       LatLng(23.78241, 90.3988),
//       LatLng(23.7833, 90.39896),
//       LatLng(23.78352, 90.39901),
//       LatLng(23.78365, 90.3991),
//       LatLng(23.78588, 90.39946),
//       LatLng(23.7876, 90.39972),
//       LatLng(23.78804, 90.3998),
//       LatLng(23.78908, 90.39998),
//       LatLng(23.7906, 90.40024),
//       LatLng(23.7929, 90.40063),
//       LatLng(23.79392, 90.40084),
//       LatLng(23.79476, 90.40098),
//       LatLng(23.79842, 90.40157),
//       LatLng(23.80136, 90.40207),
//       LatLng(23.8031, 90.40236),
//       LatLng(23.80454, 90.40248),
//       LatLng(23.80483, 90.40255),
//       LatLng(23.80598, 90.40285),
//       LatLng(23.80644, 90.40292),
//       LatLng(23.80686, 90.40297),
//       LatLng(23.80702, 90.40303),
//       LatLng(23.80738, 90.40309),
//       LatLng(23.80758, 90.40312),
//       LatLng(23.80785, 90.40316),
//       LatLng(23.81035, 90.40357),
//       LatLng(23.81103, 90.40365),
//       LatLng(23.8128, 90.40398),
//       LatLng(23.81421, 90.40421),
//       LatLng(23.81496, 90.40434),
//       LatLng(23.8153, 90.40447),
//       LatLng(23.81548, 90.40456),
//       LatLng(23.81583, 90.40478),
//       LatLng(23.81606, 90.40496),
//       LatLng(23.81635, 90.40528),
//       LatLng(23.81657, 90.40557),
//       LatLng(23.81674, 90.40587),
//       LatLng(23.81684, 90.40606),
//       LatLng(23.81696, 90.40642),
//       LatLng(23.81703, 90.40679),
//       LatLng(23.81705, 90.40709),
//       LatLng(23.817, 90.4084),
//       LatLng(23.81689, 90.41039),
//       LatLng(23.81686, 90.41074),
//       LatLng(23.81688, 90.41123),
//       LatLng(23.81694, 90.41151),
//       LatLng(23.81706, 90.41183),
//       LatLng(23.8173, 90.41231),
//       LatLng(23.8174, 90.41247),
//       LatLng(23.81821, 90.41372),
//       LatLng(23.81894, 90.41484),
//       LatLng(23.81971, 90.41608),
//       LatLng(23.82106, 90.41815),
//       LatLng(23.82138, 90.41861),
//       LatLng(23.82162, 90.41891),
//       LatLng(23.82187, 90.41916),
//       LatLng(23.82226, 90.41946),
//       LatLng(23.82289, 90.41985),
//       LatLng(23.82338, 90.4201),
//       LatLng(23.82374, 90.42022),
//       LatLng(23.82428, 90.42034),
//       LatLng(23.82494, 90.42042),
//       LatLng(23.82553, 90.42041),
//       LatLng(23.82615, 90.42033),
//       LatLng(23.82715, 90.42015),
//       LatLng(23.82939, 90.4198),
//       LatLng(23.83206, 90.41934),
//       LatLng(23.8343, 90.41898),
//       LatLng(23.83575, 90.41872),
//       LatLng(23.8367, 90.41848),
//       LatLng(23.8372, 90.41833),
//       LatLng(23.83799, 90.41806),
//       LatLng(23.83857, 90.4178),
//       LatLng(23.83921, 90.41745),
//       LatLng(23.83945, 90.41729),
//       LatLng(23.8402, 90.41678),
//       LatLng(23.84055, 90.41649),
//       LatLng(23.84105, 90.41612),
//       LatLng(23.84284, 90.4148),
//       LatLng(23.84399, 90.41381),
//       LatLng(23.84517, 90.41284),
//       LatLng(23.84606, 90.41211),
//       LatLng(23.84751, 90.41092),
//       LatLng(23.8483, 90.41026),
//       LatLng(23.84843, 90.41015),
//       LatLng(23.84844, 90.40997),
//       LatLng(23.84843, 90.40983),
//       LatLng(23.84809, 90.40935),
//       LatLng(23.84757, 90.4086),
//       LatLng(23.84708, 90.4079),
//       LatLng(23.84645, 90.40693),
//     ], color: Colors.blue, width: 6),
//     Polyline(polylineId: const PolylineId('route_0'), points: [LatLng(23.73728, 90.40409), LatLng(23.73737, 90.40411), LatLng(23.73743, 90.40411), LatLng(23.73752, 90.40411), LatLng(23.73757, 90.4041), LatLng(23.73762, 90.40408), LatLng(23.73772, 90.40401), LatLng(23.73783, 90.40397), LatLng(23.73793, 90.40392), LatLng(23.73802, 90.40387), LatLng(23.73817, 90.40377), LatLng(23.73829, 90.40369), LatLng(23.73838, 90.40362), LatLng(23.73848, 90.40353), LatLng(23.73871, 90.40329), LatLng(23.73873, 90.40326), LatLng(23.73893, 90.40306), LatLng(23.73909, 90.40284), LatLng(23.73929, 90.40252), LatLng(23.73949, 90.40221), LatLng(23.73968, 90.40188), LatLng(23.73986, 90.40156), LatLng(23.74002, 90.40124), LatLng(23.74004, 90.4012), LatLng(23.7403, 90.40065), LatLng(23.74035, 90.40053), LatLng(23.74045, 90.40031), LatLng(23.74054, 90.40012), LatLng(23.74061, 90.39999), LatLng(23.74066, 90.39991), LatLng(23.74073, 90.39979), LatLng(23.74083, 90.39969), LatLng(23.74099, 90.39952), LatLng(23.74119, 90.39932), LatLng(23.74167, 90.39887), LatLng(23.7419, 90.39862)], color: Colors.red, width: 6),
//
//   };




  Set<Marker> markers = {};
//   Set<Marker> markers = {
//     Marker(
//       markerId: const MarkerId('m0'),
//       position: const LatLng(23.8748324308902, 90.3193790209598),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m1'),
//       position: const LatLng(23.723991414495334, 90.34487367430866),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m2'),
//       position: const LatLng(23.86238646554868, 90.33037070614861),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m3'),
//       position: const LatLng(23.833751206939333, 90.46767765563997),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m4'),
//       position: const LatLng(23.8397473155082, 90.45619499478242),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m5'),
//       position: const LatLng(23.801867374788316, 90.33488208801121),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m6'),
//       position: const LatLng(23.822872957809334, 90.32073077040893),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m7'),
//       position: const LatLng(23.730487382113314, 90.33544128823841),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m8'),
//       position: const LatLng(23.850971402259482, 90.48248575943096),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m9'),
//       position: const LatLng(23.711940306527147, 90.38262839786906),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m10'),
//       position: const LatLng(23.899780382262723, 90.36307376761151),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m11'),
//       position: const LatLng(23.790683832708833, 90.38929938445557),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m12'),
//       position: const LatLng(23.841595057262705, 90.4449555774447),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m13'),
//       position: const LatLng(23.786694570467752, 90.43178567058007),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m14'),
//       position: const LatLng(23.804002755639996, 90.47049330616086),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m15'),
//       position: const LatLng(23.89320460424554, 90.34921423117781),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m16'),
//       position: const LatLng(23.782837077034, 90.4605965988524),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m17'),
//       position: const LatLng(23.822908515032662, 90.48783517368919),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m18'),
//       position: const LatLng(23.8974005935798, 90.47636671360996),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m19'),
//       position: const LatLng(23.790204191974958, 90.3413458969681),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m20'),
//       position: const LatLng(23.7993909896165, 90.4982747976284),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m21'),
//       position: const LatLng(23.81762622770255, 90.33812332223013),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m22'),
//       position: const LatLng(23.707261950111377, 90.31454253318589),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m23'),
//       position: const LatLng(23.83134238674737, 90.4836420256016),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m24'),
//       position: const LatLng(23.74873560356926, 90.47049436358328),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m25'),
//       position: const LatLng(23.881939360998363, 90.33320272738766),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m26'),
//       position: const LatLng(23.74786139729153, 90.43016209115123),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m27'),
//       position: const LatLng(23.707540235227018, 90.33487196236011),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m28'),
//       position: const LatLng(23.71193026940335, 90.48336328008439),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m29'),
//       position: const LatLng(23.896909725333394, 90.3041229526827),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m30'),
//       position: const LatLng(23.796410019442643, 90.38573713486198),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m31'),
//       position: const LatLng(23.809923369170757, 90.47328318411707),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m32'),
//       position: const LatLng(23.781975210663354, 90.31588208280537),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m33'),
//       position: const LatLng(23.764936522727055, 90.3812552525272),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m34'),
//       position: const LatLng(23.746766440217137, 90.38498883406584),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m35'),
//       position: const LatLng(23.809609562039856, 90.3692352207855),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m36'),
//       position: const LatLng(23.766040540859343, 90.35880279770625),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m37'),
//       position: const LatLng(23.81116509792679, 90.37826004616329),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m38'),
//       position: const LatLng(23.874867836385903, 90.32199771561953),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m39'),
//       position: const LatLng(23.70717371293769, 90.45514605586779),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m40'),
//       position: const LatLng(23.839874667017657, 90.30003013264346),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m41'),
//       position: const LatLng(23.783822354451328, 90.34681100677844),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m42'),
//       position: const LatLng(23.875911461004755, 90.48669526800323),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m43'),
//       position: const LatLng(23.83024198074946, 90.43759467572941),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m44'),
//       position: const LatLng(23.84263918383869, 90.374696379759),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m45'),
//       position: const LatLng(23.896834602870413, 90.37981836401374),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m46'),
//       position: const LatLng(23.719921564907324, 90.43217206279914),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m47'),
//       position: const LatLng(23.85417726089529, 90.39424080800049),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m48'),
//       position: const LatLng(23.708396939514703, 90.41057744718931),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//     Marker(
//       markerId: const MarkerId('m49'),
//       position: const LatLng(23.81284994076617, 90.38255671522599),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//     ),
//   };
//   Set<Circle> circles = {
//     Circle(
//       circleId: const CircleId('c0'),
//       center: const LatLng(23.791659300779475, 90.31407823387542),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c1'),
//       center: const LatLng(23.83089018654928, 90.38621399885903),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c2'),
//       center: const LatLng(23.702249100699458, 90.46909184679464),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c3'),
//       center: const LatLng(23.830797962557128, 90.32406474035608),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c4'),
//       center: const LatLng(23.77201669804531, 90.3418405343019),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c5'),
//       center: const LatLng(23.787557903633758, 90.46234675212993),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c6'),
//       center: const LatLng(23.76146857663977, 90.4564237623055),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c7'),
//       center: const LatLng(23.825481720790847, 90.40448071074806),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c8'),
//       center: const LatLng(23.8108523445904, 90.41924844884034),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c9'),
//       center: const LatLng(23.745117239338285, 90.46743006726246),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c10'),
//       center: const LatLng(23.73726169925128, 90.44421970665097),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c11'),
//       center: const LatLng(23.872858371188684, 90.33771554569913),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c12'),
//       center: const LatLng(23.763018626821665, 90.3156600575159),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c13'),
//       center: const LatLng(23.7048452407338, 90.45016764663545),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c14'),
//       center: const LatLng(23.841098784813656, 90.43440154109952),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c15'),
//       center: const LatLng(23.75531933546758, 90.3867956653944),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c16'),
//       center: const LatLng(23.7233943949483, 90.46712196646347),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c17'),
//       center: const LatLng(23.746631947659218, 90.47555806196387),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c18'),
//       center: const LatLng(23.853576905733565, 90.37222770288348),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c19'),
//       center: const LatLng(23.83578042231262, 90.43432426578511),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c20'),
//       center: const LatLng(23.82779734564717, 90.47722931864274),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c21'),
//       center: const LatLng(23.889527279009634, 90.41631043430822),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c22'),
//       center: const LatLng(23.749671497054116, 90.44534124465696),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c23'),
//       center: const LatLng(23.821899461484318, 90.31047334236531),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c24'),
//       center: const LatLng(23.885682458075003, 90.44577875681104),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c25'),
//       center: const LatLng(23.835962940883817, 90.43295721425787),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c26'),
//       center: const LatLng(23.86076170900997, 90.48779809528286),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c27'),
//       center: const LatLng(23.866312939440917, 90.4926772723835),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.red.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c28'),
//       center: const LatLng(23.788766580059256, 90.49058201381328),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c29'),
//       center: const LatLng(23.708293380394853, 90.35528912677428),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c30'),
//       center: const LatLng(23.813616419691837, 90.4551691990741),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c31'),
//       center: const LatLng(23.835651671048023, 90.36996782517741),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c32'),
//       center: const LatLng(23.722915575534003, 90.47168166621374),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c33'),
//       center: const LatLng(23.76364533903154, 90.38520023319558),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c34'),
//       center: const LatLng(23.740504907610674, 90.3442550182535),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c35'),
//       center: const LatLng(23.755133258702454, 90.36836161289774),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c36'),
//       center: const LatLng(23.707764017103898, 90.3053375627987),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c37'),
//       center: const LatLng(23.786691982563866, 90.49323886148163),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c38'),
//       center: const LatLng(23.85425468471945, 90.32084093048381),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c39'),
//       center: const LatLng(23.71861780450371, 90.4392478635803),
//       radius: 50.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c40'),
//       center: const LatLng(23.870686852029895, 90.46832762353957),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c41'),
//       center: const LatLng(23.708625173957035, 90.3220492643414),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c42'),
//       center: const LatLng(23.715253445281334, 90.41084051028369),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c43'),
//       center: const LatLng(23.80260052416276, 90.48023633380943),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c44'),
//       center: const LatLng(23.750241461548733, 90.31459926150973),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c45'),
//       center: const LatLng(23.826236290579985, 90.44724559024381),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c46'),
//       center: const LatLng(23.852584749925466, 90.40698453087685),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c47'),
//       center: const LatLng(23.81775158299093, 90.34728864851479),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c48'),
//       center: const LatLng(23.76361479377331, 90.46724468555428),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c49'),
//       center: const LatLng(23.854893193723473, 90.45378252580687),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),Circle(
//       circleId: const CircleId('c0'),
//       center: const LatLng(23.71225754654724, 90.36209330328452),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c1'),
//       center: const LatLng(23.819805028468544, 90.3967910346945),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c2'),
//       center: const LatLng(23.776997776404198, 90.32905513339641),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c3'),
//       center: const LatLng(23.795098732934942, 90.44143330253648),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c4'),
//       center: const LatLng(23.794987576177395, 90.48956651457665),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c5'),
//       center: const LatLng(23.834012535619465, 90.4484432278606),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c6'),
//       center: const LatLng(23.831270338377312, 90.33222629319809),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c7'),
//       center: const LatLng(23.733549914517987, 90.46106708468668),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c8'),
//       center: const LatLng(23.801076861004884, 90.33753063654287),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c9'),
//       center: const LatLng(23.790585147443583, 90.47672446219858),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c10'),
//       center: const LatLng(23.84081421824403, 90.3932250411522),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c11'),
//       center: const LatLng(23.716831334788253, 90.34015950004785),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c12'),
//       center: const LatLng(23.880405407838364, 90.33177808480913),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c13'),
//       center: const LatLng(23.712695592061774, 90.43721058030168),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c14'),
//       center: const LatLng(23.711103969254374, 90.31114332037443),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c15'),
//       center: const LatLng(23.89774375820414, 90.36299320904952),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c16'),
//       center: const LatLng(23.720901502891547, 90.36781210913688),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c17'),
//       center: const LatLng(23.71758903676168, 90.47622943572183),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c18'),
//       center: const LatLng(23.77822854412928, 90.38790438755295),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c19'),
//       center: const LatLng(23.82656969630889, 90.47294745341108),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c20'),
//       center: const LatLng(23.735197233611427, 90.45798517988185),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c21'),
//       center: const LatLng(23.895891292883995, 90.48847119389121),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c22'),
//       center: const LatLng(23.87447333553669, 90.41191157502305),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c23'),
//       center: const LatLng(23.789725260125, 90.44964503503665),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c24'),
//       center: const LatLng(23.77653973627912, 90.39305760650346),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c25'),
//       center: const LatLng(23.700062885257385, 90.42726113659276),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c26'),
//       center: const LatLng(23.89202580611384, 90.38943668788036),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c27'),
//       center: const LatLng(23.835869027790768, 90.3212855133278),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c28'),
//       center: const LatLng(23.89824139324972, 90.48634587664831),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c29'),
//       center: const LatLng(23.82325271841395, 90.38361538959022),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c30'),
//       center: const LatLng(23.76685175851211, 90.45528468830179),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c31'),
//       center: const LatLng(23.795329665618894, 90.34545836598006),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c32'),
//       center: const LatLng(23.893723234119445, 90.33981250035028),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c33'),
//       center: const LatLng(23.722007507437464, 90.43078922863324),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c34'),
//       center: const LatLng(23.74981706979529, 90.35880450676845),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c35'),
//       center: const LatLng(23.747031255266, 90.31980747919384),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c36'),
//       center: const LatLng(23.889569613204326, 90.32554730188438),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c37'),
//       center: const LatLng(23.844462085676124, 90.33340372791582),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c38'),
//       center: const LatLng(23.761370639381404, 90.43484813535417),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c39'),
//       center: const LatLng(23.737216896662673, 90.36002248295486),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c40'),
//       center: const LatLng(23.820079841256717, 90.45127915088723),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c41'),
//       center: const LatLng(23.704005084001256, 90.44198764091962),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c42'),
//       center: const LatLng(23.782343182216135, 90.37143769020899),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c43'),
//       center: const LatLng(23.77314787724803, 90.45761374026476),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c44'),
//       center: const LatLng(23.712305511852616, 90.38109156290486),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c45'),
//       center: const LatLng(23.791089094069978, 90.43499080749338),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c46'),
//       center: const LatLng(23.73685850690373, 90.44021816555815),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c47'),
//       center: const LatLng(23.77757284403112, 90.36688058722224),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c48'),
//       center: const LatLng(23.76686127448155, 90.42876175713768),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c49'),
//       center: const LatLng(23.780805459642888, 90.41216820861402),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c0'),
//       center: const LatLng(23.8748324308902, 90.3193790209598),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c1'),
//       center: const LatLng(23.723991414495334, 90.34487367430866),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c2'),
//       center: const LatLng(23.86238646554868, 90.33037070614861),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c3'),
//       center: const LatLng(23.833751206939333, 90.46767765563997),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c4'),
//       center: const LatLng(23.8397473155082, 90.45619499478242),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c5'),
//       center: const LatLng(23.801867374788316, 90.33488208801121),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c6'),
//       center: const LatLng(23.822872957809334, 90.32073077040893),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c7'),
//       center: const LatLng(23.730487382113314, 90.33544128823841),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c8'),
//       center: const LatLng(23.850971402259482, 90.48248575943096),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c9'),
//       center: const LatLng(23.711940306527147, 90.38262839786906),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c10'),
//       center: const LatLng(23.899780382262723, 90.36307376761151),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c11'),
//       center: const LatLng(23.790683832708833, 90.38929938445557),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c12'),
//       center: const LatLng(23.841595057262705, 90.4449555774447),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c13'),
//       center: const LatLng(23.786694570467752, 90.43178567058007),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c14'),
//       center: const LatLng(23.804002755639996, 90.47049330616086),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c15'),
//       center: const LatLng(23.89320460424554, 90.34921423117781),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c16'),
//       center: const LatLng(23.782837077034, 90.4605965988524),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c17'),
//       center: const LatLng(23.822908515032662, 90.48783517368919),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c18'),
//       center: const LatLng(23.8974005935798, 90.47636671360996),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c19'),
//       center: const LatLng(23.790204191974958, 90.3413458969681),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c20'),
//       center: const LatLng(23.7993909896165, 90.4982747976284),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c21'),
//       center: const LatLng(23.81762622770255, 90.33812332223013),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c22'),
//       center: const LatLng(23.707261950111377, 90.31454253318589),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c23'),
//       center: const LatLng(23.83134238674737, 90.4836420256016),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c24'),
//       center: const LatLng(23.74873560356926, 90.47049436358328),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c25'),
//       center: const LatLng(23.881939360998363, 90.33320272738766),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c26'),
//       center: const LatLng(23.74786139729153, 90.43016209115123),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c27'),
//       center: const LatLng(23.707540235227018, 90.33487196236011),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c28'),
//       center: const LatLng(23.71193026940335, 90.48336328008439),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c29'),
//       center: const LatLng(23.896909725333394, 90.3041229526827),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c30'),
//       center: const LatLng(23.796410019442643, 90.38573713486198),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c31'),
//       center: const LatLng(23.809923369170757, 90.47328318411707),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c32'),
//       center: const LatLng(23.781975210663354, 90.31588208280537),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c33'),
//       center: const LatLng(23.764936522727055, 90.3812552525272),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c34'),
//       center: const LatLng(23.746766440217137, 90.38498883406584),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c35'),
//       center: const LatLng(23.809609562039856, 90.3692352207855),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c36'),
//       center: const LatLng(23.766040540859343, 90.35880279770625),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c37'),
//       center: const LatLng(23.81116509792679, 90.37826004616329),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c38'),
//       center: const LatLng(23.874867836385903, 90.32199771561953),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c39'),
//       center: const LatLng(23.70717371293769, 90.45514605586779),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c40'),
//       center: const LatLng(23.839874667017657, 90.30003013264346),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c41'),
//       center: const LatLng(23.783822354451328, 90.34681100677844),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c42'),
//       center: const LatLng(23.875911461004755, 90.48669526800323),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c43'),
//       center: const LatLng(23.83024198074946, 90.43759467572941),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c44'),
//       center: const LatLng(23.84263918383869, 90.374696379759),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c45'),
//       center: const LatLng(23.896834602870413, 90.37981836401374),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c46'),
//       center: const LatLng(23.719921564907324, 90.43217206279914),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c47'),
//       center: const LatLng(23.85417726089529, 90.39424080800049),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c48'),
//       center: const LatLng(23.708396939514703, 90.41057744718931),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//     Circle(
//       circleId: const CircleId('c49'),
//       center: const LatLng(23.81284994076617, 90.38255671522599),
//       radius: 500.0,
//       fillColor: Colors.yellow.withOpacity(0.2),
//       strokeColor: Colors.orange.withOpacity(0.2),
//       strokeWidth: 40,
//     ),
//   };
  Set<Polyline> polylines = {};
  // Set<Polyline> polylines = {
  //   Polyline(
  //     polylineId: const PolylineId('route_0'),
  //     points: [
  //       LatLng(23.827927692117992, 90.46827062827272),
  //       LatLng(23.717780289334947, 90.47180242384806),
  //       LatLng(23.898770940568056, 90.43989356382797),
  //       LatLng(23.80203433502629, 90.44576252518225),
  //       LatLng(23.84993206425131, 90.40562704538193),
  //       LatLng(23.777015912574996, 90.46507055604579),
  //       LatLng(23.730400385711256, 90.38994298860604),
  //       LatLng(23.7604275454169, 90.41959254135777),
  //       LatLng(23.899707719628385, 90.47470052714806),
  //       LatLng(23.77048348832185, 90.32914603040443),
  //       LatLng(23.73709264911446, 90.43713298423029),
  //       LatLng(23.873158684234763, 90.30085984411623),
  //       LatLng(23.832638697224798, 90.31982939569858),
  //       LatLng(23.843949686840297, 90.39976639076286),
  //       LatLng(23.748975117224887, 90.48336071869959),
  //       LatLng(23.86599184295084, 90.30071892061811),
  //       LatLng(23.79358629001891, 90.49746688265964),
  //       LatLng(23.875744526218885, 90.46305339837996),
  //       LatLng(23.762565861748268, 90.35119491486623),
  //       LatLng(23.77359509553105, 90.31169058658462),
  //       LatLng(23.729318203233362, 90.48955979421133),
  //       LatLng(23.867850045475436, 90.3881313290381),
  //       LatLng(23.888096588123712, 90.40544562225391),
  //       LatLng(23.837177548535642, 90.43896503179319),
  //       LatLng(23.88422246417672, 90.37042166948929),
  //       LatLng(23.785486704148983, 90.31794271990255),
  //       LatLng(23.757504225042364, 90.3353703314164),
  //       LatLng(23.853406232457992, 90.49811976148787),
  //       LatLng(23.728891857809664, 90.44880086633428),
  //       LatLng(23.871774893692145, 90.41680673387252),
  //       LatLng(23.8321086993572, 90.35204049508756),
  //       LatLng(23.755338920396063, 90.48183989085756),
  //       LatLng(23.70752441176325, 90.39138610052896),
  //       LatLng(23.714254993351897, 90.31860511483546),
  //       LatLng(23.89742705864709, 90.4507109969639),
  //       LatLng(23.885186764042185, 90.39611675195242),
  //       LatLng(23.713520995817895, 90.37823361363465),
  //       LatLng(23.825708309406522, 90.3398849598368),
  //       LatLng(23.717930567498694, 90.3234187340253),
  //       LatLng(23.898662381831976, 90.43786108560343),
  //       LatLng(23.87174842909956, 90.37469303988311),
  //       LatLng(23.872842937055058, 90.33253683690876),
  //       LatLng(23.728524419038763, 90.45334794316659),
  //       LatLng(23.778561960827442, 90.37988898017613),
  //       LatLng(23.702098142635695, 90.42711171319282),
  //       LatLng(23.86854835977331, 90.39021877899897),
  //       LatLng(23.736205152517538, 90.42789793528861),
  //       LatLng(23.76653263227957, 90.47837302171544),
  //       LatLng(23.83854634771865, 90.43701743306332),
  //       LatLng(23.85726443543567, 90.33649289227391),
  //       LatLng(23.74081428235824, 90.48750915690094),
  //       LatLng(23.724524173553757, 90.40204546697557),
  //       LatLng(23.818374524858726, 90.41414823703954),
  //       LatLng(23.855770213213276, 90.34177702089467),
  //       LatLng(23.892627245097593, 90.49888653729074),
  //       LatLng(23.826212191993204, 90.38143418305243),
  //       LatLng(23.86232109026882, 90.48616516923357),
  //       LatLng(23.73582194400702, 90.41052432649087),
  //       LatLng(23.896188719412603, 90.30108258775188),
  //       LatLng(23.785185100431075, 90.3862422253244),
  //       LatLng(23.739655815259482, 90.4600212009454),
  //       LatLng(23.70019164949297, 90.30317893417325),
  //       LatLng(23.76972318689497, 90.42443618902126),
  //       LatLng(23.816532456295413, 90.33016721933791),
  //       LatLng(23.725777329919172, 90.37595045753004),
  //       LatLng(23.81697038195652, 90.4205597160272),
  //       LatLng(23.838908224020734, 90.43517780349882),
  //       LatLng(23.791291849777938, 90.44288633440517),
  //       LatLng(23.786409567867732, 90.48232128095972),
  //       LatLng(23.867748668236775, 90.31381883930494),
  //       LatLng(23.898812914906195, 90.34697867803838),
  //       LatLng(23.744285047941315, 90.33267013117373),
  //       LatLng(23.712807156732488, 90.40630074791353),
  //       LatLng(23.80387151016009, 90.34776784172628),
  //       LatLng(23.817215414234667, 90.4863090378719),
  //       LatLng(23.708839740905997, 90.39623796279594),
  //       LatLng(23.73564815732891, 90.38572367203284),
  //       LatLng(23.757486451911735, 90.45086490022089),
  //       LatLng(23.79212094361852, 90.37505737647196),
  //       LatLng(23.87375635813678, 90.47828306788658),
  //       LatLng(23.722143281439376, 90.46030991384393),
  //       LatLng(23.846295380979512, 90.44034437143513),
  //       LatLng(23.761570421038815, 90.34876253319828),
  //       LatLng(23.745221024523833, 90.41637331011984),
  //       LatLng(23.870762424864918, 90.33211306424988),
  //       LatLng(23.70993198296298, 90.49301925944964),
  //       LatLng(23.849452943621145, 90.49969717960526),
  //       LatLng(23.740341685561642, 90.36883002370276),
  //       LatLng(23.710462478759872, 90.49126105753577),
  //       LatLng(23.823622612789567, 90.49703015565994),
  //       LatLng(23.805664708576767, 90.318790267735),
  //       LatLng(23.77812254846297, 90.40809562644051),
  //       LatLng(23.880820635199402, 90.40862610305992),
  //       LatLng(23.70965808210814, 90.30993759870945),
  //       LatLng(23.878435384220488, 90.42750169186556),
  //       LatLng(23.767773796303825, 90.44951497514249),
  //       LatLng(23.75573718359476, 90.44163274189204),
  //       LatLng(23.86539679347229, 90.38125796773265),
  //       LatLng(23.752392634352994, 90.4472713704782),
  //       LatLng(23.87686684798841, 90.36516391289776),
  //     ],
  //     color: Colors.green,
  //     width: 6,
  //   ),
  // };

  // Search and Suggestions
  Set<Circle> circles = {
    Circle(circleId: const CircleId('c0'), center: const LatLng(23.767210638688493, 90.35838621347095), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),

    Circle(circleId: const CircleId('c1'), center: const LatLng(23.769512, 90.359721), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c2'), center: const LatLng(23.765932, 90.357254), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c3'), center: const LatLng(23.770821, 90.360892), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c4'), center: const LatLng(23.766182, 90.361224), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c5'), center: const LatLng(23.768415, 90.362918), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c6'), center: const LatLng(23.764892, 90.359442), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c7'), center: const LatLng(23.769942, 90.356731), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c8'), center: const LatLng(23.771255, 90.358415), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c9'), center: const LatLng(23.763875, 90.358754), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c10'), center: const LatLng(23.768622, 90.354981), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c11'), center: const LatLng(23.772104, 90.360214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c12'), center: const LatLng(23.767985, 90.363842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c13'), center: const LatLng(23.765214, 90.362155), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c14'), center: const LatLng(23.769451, 90.363112), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c15'), center: const LatLng(23.770942, 90.355915), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c16'), center: const LatLng(23.764385, 90.355842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c17'), center: const LatLng(23.773125, 90.358722), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c18'), center: const LatLng(23.762985, 90.360145), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c19'), center: const LatLng(23.771925, 90.362215), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c20'), center: const LatLng(23.765732, 90.364421), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c33'), center: const LatLng(23.861233, 90.366754), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c34'), center: const LatLng(23.858012, 90.366184), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c35'), center: const LatLng(23.860721, 90.367892), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c36'), center: const LatLng(23.857182, 90.363224), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c37'), center: const LatLng(23.862415, 90.368918), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c38'), center: const LatLng(23.857892, 90.361442), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c39'), center: const LatLng(23.861942, 90.362731), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c40'), center: const LatLng(23.863255, 90.364415), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c41'), center: const LatLng(23.857875, 90.364754), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c42'), center: const LatLng(23.859622, 90.361981), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c43'), center: const LatLng(23.863104, 90.367214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c44'), center: const LatLng(23.859985, 90.369842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c45'), center: const LatLng(23.857214, 90.368155), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c46'), center: const LatLng(23.861451, 90.369112), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c47'), center: const LatLng(23.862942, 90.362915), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c48'), center: const LatLng(23.858385, 90.362842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c49'), center: const LatLng(23.864125, 90.365722), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c50'), center: const LatLng(23.859985, 90.370145), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c51'), center: const LatLng(23.861925, 90.367215), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c52'), center: const LatLng(23.858422, 90.366721), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c53'), center: const LatLng(23.782015, 90.427115), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c54'), center: const LatLng(23.779725, 90.426842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c55'), center: const LatLng(23.781952, 90.424385), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c56'), center: const LatLng(23.778944, 90.425112), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c57'), center: const LatLng(23.782841, 90.426952), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c58'), center: const LatLng(23.780125, 90.428214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c59'), center: const LatLng(23.779452, 90.423985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c60'), center: const LatLng(23.782544, 90.423711), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c61'), center: const LatLng(23.781125, 90.428841), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c62'), center: const LatLng(23.778721, 90.426512), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c63'), center: const LatLng(23.783154, 90.425221), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c64'), center: const LatLng(23.779985, 90.422942), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c65'), center: const LatLng(23.783422, 90.428015), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c66'), center: const LatLng(23.782952, 90.427415), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c67'), center: const LatLng(23.781444, 90.423421), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c68'), center: const LatLng(23.780215, 90.427715), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c69'), center: const LatLng(23.783812, 90.426242), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c70'), center: const LatLng(23.779841, 90.428985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c71'), center: const LatLng(23.782185, 90.424915), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c72'), center: const LatLng(23.780685, 90.423614), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),

    Circle(circleId: const CircleId('c73'), center: const LatLng(23.799452, 90.415842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c74'), center: const LatLng(23.797125, 90.415214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c75'), center: const LatLng(23.798985, 90.416512), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c76'), center: const LatLng(23.796954, 90.414125), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c77'), center: const LatLng(23.799815, 90.413852), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c78'), center: const LatLng(23.798544, 90.417215), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c79'), center: const LatLng(23.800214, 90.415325), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c80'), center: const LatLng(23.797842, 90.416942), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c81'), center: const LatLng(23.796885, 90.413421), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c82'), center: const LatLng(23.799944, 90.416115), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c83'), center: const LatLng(23.797521, 90.417425), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c84'), center: const LatLng(23.798741, 90.413214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c85'), center: const LatLng(23.800452, 90.414842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c86'), center: const LatLng(23.796625, 90.415512), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c87'), center: const LatLng(23.799124, 90.417985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c88'), center: const LatLng(23.797285, 90.412985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c89'), center: const LatLng(23.800821, 90.415942), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c90'), center: const LatLng(23.796985, 90.416214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c91'), center: const LatLng(23.799385, 90.413842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c92'), center: const LatLng(23.798185, 90.418214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),Circle(circleId: const CircleId('c93'), center: const LatLng(23.746215, 90.373285), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c94'), center: const LatLng(23.744512, 90.373452), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c95'), center: const LatLng(23.746852, 90.371942), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c96'), center: const LatLng(23.744985, 90.371214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c97'), center: const LatLng(23.745842, 90.373815), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c98'), center: const LatLng(23.743925, 90.372452), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c99'), center: const LatLng(23.747125, 90.372985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c100'), center: const LatLng(23.744421, 90.371842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c101'), center: const LatLng(23.746425, 90.373125), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c102'), center: const LatLng(23.745315, 90.374214), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c103'), center: const LatLng(23.744842, 90.370985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c104'), center: const LatLng(23.746852, 90.374452), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c105'), center: const LatLng(23.743985, 90.371625), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c106'), center: const LatLng(23.747215, 90.373521), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c107'), center: const LatLng(23.744652, 90.374115), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c108'), center: const LatLng(23.745985, 90.370842), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c109'), center: const LatLng(23.746521, 90.374985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c110'), center: const LatLng(23.743785, 90.372985), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c111'), center: const LatLng(23.747421, 90.371942), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(circleId: const CircleId('c112'), center: const LatLng(23.744214, 90.373785), radius: 50.0, fillColor: Colors.yellow.withOpacity(0.2), strokeColor: Colors.red.withOpacity(0.2), strokeWidth: 20),
    Circle(
      circleId: const CircleId('c113'),
      center: const LatLng(23.75684527394259, 90.46392165354208),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c114'),
      center: const LatLng(23.756145273942596, 90.46372165354209),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c115'),
      center: const LatLng(23.756445273942598, 90.46402165354208),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c116'),
      center: const LatLng(23.756745273942597, 90.46362165354207),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c117'),
      center: const LatLng(23.756245273942596, 90.46392165354206),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c118'),
      center: const LatLng(23.756545273942594, 90.46342165354208),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c119'),
      center: const LatLng(23.756645273942596, 90.46372165354205),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c120'),
      center: const LatLng(23.756045273942595, 90.46352165354209),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c121'),
      center: const LatLng(23.756945273942596, 90.46382165354206),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c122'),
      center: const LatLng(23.756345273942596, 90.46412165354208),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c123'),
      center: const LatLng(23.75654527394259, 90.46422165354209),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c124'),
      center: const LatLng(23.756145273942598, 90.46402165354207),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c125'),
      center: const LatLng(23.756745273942596, 90.46342165354206),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c126'),
      center: const LatLng(23.756245273942594, 90.46362165354205),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c127'),
      center: const LatLng(23.75644527394259, 90.46412165354207),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c128'),
      center: const LatLng(23.75664527394259, 90.4635216535421),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c129'),
      center: const LatLng(23.756845273942597, 90.46372165354207),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c130'),
      center: const LatLng(23.756045273942596, 90.46392165354209),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c131'),
      center: const LatLng(23.75694527394259, 90.46362165354208),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c132'),
      center: const LatLng(23.75634527394259, 90.46332165354206),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c133'),
      center: const LatLng(23.729454126104426, 90.41938950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c134'),
      center: const LatLng(23.728454126104426, 90.41838950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c135'),
      center: const LatLng(23.729954126104426, 90.41988950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c136'),
      center: const LatLng(23.728954126104426, 90.41788950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c137'),
      center: const LatLng(23.730454126104426, 90.41888950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c138'),
      center: const LatLng(23.728454126104426, 90.41988950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c139'),
      center: const LatLng(23.729454126104426, 90.41788950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c140'),
      center: const LatLng(23.730954126104426, 90.41938950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c141'),
      center: const LatLng(23.727954126104426, 90.41838950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c142'),
      center: const LatLng(23.729954126104426, 90.42038950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c143'),
      center: const LatLng(23.730454126104426, 90.42088950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c144'),
      center: const LatLng(23.727454126104426, 90.41788950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c145'),
      center: const LatLng(23.730954126104426, 90.41788950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c146'),
      center: const LatLng(23.727954126104426, 90.42038950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c147'),
      center: const LatLng(23.729954126104426, 90.41738950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c148'),
      center: const LatLng(23.728454126104426, 90.41688950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c149'),
      center: const LatLng(23.731454126104426, 90.41988950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c150'),
      center: const LatLng(23.729454126104426, 90.42138950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c151'),
      center: const LatLng(23.731954126104426, 90.41888950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c152'),
      center: const LatLng(23.727954126104426, 90.41738950725988),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c153'),
      center: const LatLng(23.79548294208009, 90.34614617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c154'),
      center: const LatLng(23.79348294208009, 90.34414617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c155'),
      center: const LatLng(23.79498294208009, 90.34714617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c156'),
      center: const LatLng(23.79398294208009, 90.34314617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c157'),
      center: const LatLng(23.79598294208009, 90.34564617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c158'),
      center: const LatLng(23.79448294208009, 90.34814617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c159'),
      center: const LatLng(23.79648294208009, 90.34414617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c160'),
      center: const LatLng(23.79398294208009, 90.34614617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c161'),
      center: const LatLng(23.79548294208009, 90.34364617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c162'),
      center: const LatLng(23.79498294208009, 90.34464617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c163'),
      center: const LatLng(23.79648294208009, 90.34664617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c164'),
      center: const LatLng(23.79348294208009, 90.34564617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c165'),
      center: const LatLng(23.79598294208009, 90.34714617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c166'),
      center: const LatLng(23.79448294208009, 90.34364617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c167'),
      center: const LatLng(23.79648294208009, 90.34514617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c168'),
      center: const LatLng(23.79398294208009, 90.34714617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c169'),
      center: const LatLng(23.79548294208009, 90.34464617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c170'),
      center: const LatLng(23.79498294208009, 90.34664617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c171'),
      center: const LatLng(23.79648294208009, 90.34764617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
    Circle(
      circleId: const CircleId('c172'),
      center: const LatLng(23.79348294208009, 90.34414617670126),
      radius: 50.0,
      fillColor: Colors.yellow.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.2),
      strokeWidth: 20,
    ),
  };
  List<PlaceSuggestion> suggestions = [];
  bool showSuggestions = false;
  bool isLoading = false;
  List<RouteInfo> availableRoutes = [];

  // Initial camera position - Dhaka, Bangladesh
  static const CameraPosition _kDhakaPosition = CameraPosition(
    target: LatLng(23.8103, 90.4125), // Dhaka coordinates
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _searchFocusNode.addListener(() {
      setState(() {
        showSuggestions = _searchFocusNode.hasFocus && suggestions.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Location services are disabled', Colors.orange);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permission denied', Colors.red);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permission permanently denied', Colors.red);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        currentPosition = position;
        // markers.add(
        //   Marker(
        //     markerId: const MarkerId('current_location'),
        //     position: LatLng(position.latitude, position.longitude),
        //     icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        //     infoWindow: const InfoWindow(title: 'Your Location'),
        //   ),
        // );
      });

      // Move camera to current location
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15.0,
          ),
        ),
      );

     // _showSnackBar('Location found', Colors.blue);
    } catch (e) {
      print('Error getting location: $e');
      _showSnackBar('Could not get location', Colors.red);
    }
  }

  // Show snackbar helper
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Search for places
  void _searchPlaces(String query) {
    if (query.isEmpty) {
      setState(() {
        suggestions.clear();
        showSuggestions = false;
      });
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchPlaceSuggestions(query);
    });
  }

  // Fetch place suggestions from Google Places API
  // Replace your _fetchPlaceSuggestions method with this:

  Future<void> _fetchPlaceSuggestions(String query) async {
    setState(() {
      isLoading = true;
    });

    try {
      String baseUrl = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';

      // Updated request with new API parameters
      String request = '$baseUrl?input=${Uri.encodeQueryComponent(query)}'
          '&key=$googleApiKey'
          '&components=country:bd'
          '&types=establishment|geocode'
          '&fields=place_id,description,structured_formatting';

      // Add location bias if available
      if (currentPosition != null) {
        request += '&location=${currentPosition!.latitude},${currentPosition!.longitude}'
            '&radius=50000'; // 50km radius
      }

      print('Places API Request: $request');

      final response = await http.get(
        Uri.parse(request),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('Places API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          List<PlaceSuggestion> newSuggestions = [];

          for (var prediction in data['predictions']) {
            newSuggestions.add(
              PlaceSuggestion(
                placeId: prediction['place_id'],
                description: prediction['description'],
                mainText: prediction['structured_formatting']['main_text'],
                secondaryText: prediction['structured_formatting']['secondary_text'] ?? '',
                types: List<String>.from(prediction['types'] ?? []),
              ),
            );
          }

          setState(() {
            suggestions = newSuggestions;
            showSuggestions = suggestions.isNotEmpty && _searchFocusNode.hasFocus;
            isLoading = false;
          });
        } else {
          String errorMessage = 'Search failed: ${data['status']}';
          if (data['error_message'] != null) {
            errorMessage += ' - ${data['error_message']}';
          }
          _showSnackBar(errorMessage, Colors.red);
          setState(() {
            isLoading = false;
            suggestions.clear();
            showSuggestions = false;
          });
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      _showSnackBar('Network error: ${e.toString()}', Colors.red);
      setState(() {
        isLoading = false;
        suggestions.clear();
        showSuggestions = false;
      });
    }
  }

  // Get place details and show routes
  Future<void> _selectPlace(PlaceSuggestion suggestion) async {
    setState(() {
      showSuggestions = false;
      isLoading = true;
    });

    _searchController.text = suggestion.mainText;
    _searchFocusNode.unfocus();

    try {
      // Get place details
      String baseUrl = 'https://maps.googleapis.com/maps/api/place/details/json';
      // Replace your _selectPlace method's API call with:
      String request = '$baseUrl?place_id=${suggestion.placeId}'
          '&key=$googleApiKey'
          '&fields=name,formatted_address,geometry'
          ;

      print('Place Details Request: $request');

      final response = await http.get(Uri.parse(request)).timeout(const Duration(seconds: 10));

      print('Place Details Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          final name = data['result']['name'] ?? suggestion.mainText;
          final address = data['result']['formatted_address'] ?? suggestion.description;

          destinationLocation = LatLng(location['lat'], location['lng']);

          // Add destination marker
          setState(() {
            markers.removeWhere((marker) => marker.markerId.value == 'destination');
            markers.add(
              Marker(
                markerId: const MarkerId('destination'),
                position: destinationLocation!,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(
                  title: name,
                  snippet: address,
                ),
              ),
            );
          });

          // Get directions if current location is available
          if (currentPosition != null) {
            await _getDirections();
          } else {
            _showSnackBar('Destination selected', Colors.blue);
          }

          // Move camera to show both locations or just destination
          if (currentPosition != null) {
            _moveCameraToShowBothLocations();
          } else {
            final GoogleMapController controller = await _controller.future;
            controller.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: destinationLocation!, zoom: 15.0),
              ),
            );
          }
        } else {
          _showSnackBar('Failed to get place details: ${data['status']}', Colors.red);
        }
      }
    } catch (e) {
      print('Error selecting place: $e');
      _showSnackBar('Error selecting place: ${e.toString()}', Colors.red);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Get directions from current location to destination
  Future<void> _getDirections() async {
    if (currentPosition == null || destinationLocation == null) return;

    try {
      String baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
      String request = '$baseUrl?origin=${currentPosition!.latitude},${currentPosition!.longitude}'
          '&destination=${destinationLocation!.latitude},${destinationLocation!.longitude}'
          '&alternatives=true' // Get alternative routes
          '&avoid=tolls' // Avoid tolls (relevant for BD highways)
          '&region=bd' // Bangladesh region
          '&language=bn' // Bengali language
          '&key=$googleApiKey';

      print('Directions API Request: $request');

      final response = await http.get(Uri.parse(request)).timeout(const Duration(seconds: 15));

      print('Directions API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          setState(() {
            polylines.clear();
            availableRoutes.clear();
          });

          // Process all available routes
          for (int i = 0; i < data['routes'].length; i++) {
            var route = data['routes'][i];
            String encodedPolyline = route['overview_polyline']['points'];
            List<LatLng> routePoints = _decodePolyline(encodedPolyline);

            // Extract route information
            var leg = route['legs'][0];
            String distance = leg['distance']['text'];
            String duration = leg['duration']['text'];
            String summary = route['summary'] ?? ' ${i + 1}';

            availableRoutes.add(RouteInfo(
              routeIndex: i,
              distance: distance,
              duration: duration,
              summary: summary,
              points: routePoints,
            ));

            // Add polyline to map
            setState(() {
              polylines.add(
                Polyline(
                  polylineId: PolylineId('route_$i'),
                  points: routePoints,
                  color: i == 0 ? Colors.blue : Colors.grey.shade600,
                  width: i == 0 ? 6 : 4,
                  patterns: i == 0 ? [] : [PatternItem.dash(10), PatternItem.gap(5)],
                ),
              );
            });
          }

          if (availableRoutes.isNotEmpty) {
            _showSnackBar('${availableRoutes.length} routes found', Colors.blue);
          }
        } else {
          _showSnackBar('No routes found: ${data['status']}', Colors.orange);
        }
      }
    } catch (e) {
      print('Error getting directions: ${e.toString()}');
      _showSnackBar('Error getting directions: ${e.toString()}', Colors.red);
    }
  }

  // Decode polyline string to LatLng points
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polylinePoints = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polylinePoints.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polylinePoints;
  }

  // Move camera to show both current location and destination
  void _moveCameraToShowBothLocations() async {
    if (currentPosition == null || destinationLocation == null) return;

    final GoogleMapController controller = await _controller.future;

    double minLat = math.min(currentPosition!.latitude, destinationLocation!.latitude);
    double maxLat = math.max(currentPosition!.latitude, destinationLocation!.latitude);
    double minLng = math.min(currentPosition!.longitude, destinationLocation!.longitude);
    double maxLng = math.max(currentPosition!.longitude, destinationLocation!.longitude);

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  // Clear search and routes
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      suggestions.clear();
      showSuggestions = false;
      destinationLocation = null;
      polylines.clear();
      availableRoutes.clear();
      markers.removeWhere((marker) => marker.markerId.value == 'destination');
    });
  }

  // Select a specific route
  void _selectRoute(int routeIndex) {
    setState(() {
      polylines.clear();
      for (int i = 0; i < availableRoutes.length; i++) {
        polylines.add(
          Polyline(
            polylineId: PolylineId('route_$i'),
            points: availableRoutes[i].points,
            color: i == routeIndex ? Colors.blue : Colors.grey.shade400,
            width: i == routeIndex ? 6 : 3,
            patterns: i == routeIndex ? [] : [PatternItem.dash(8), PatternItem.gap(4)],
          ),
        );
        print(polylines.last.toJson());
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Maps'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: (){
              setState(() {

              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            style:
            '''
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
            mapType: MapType.normal,
            initialCameraPosition: _kDhakaPosition,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              mapController = controller;
            },
            markers: markers,
            circles: circles,
            polylines: polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            trafficEnabled: false, // Show traffic information
          ),

          // Search Bar
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search places in Bangladesh',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: Icon(Icons.search, color: Colors.blue.shade700),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: _clearSearch,
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: _searchPlaces,
              ),
            ),
          ),

          // Suggestions List
          if (showSuggestions)
            Positioned(
              top: 70,
              left: 16,
              right: 16,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    IconData icon = Icons.location_on;

                    // Set different icons based on place type
                    if (suggestion.types.contains('restaurant') || suggestion.types.contains('meal_takeaway')) {
                      icon = Icons.restaurant;
                    } else if (suggestion.types.contains('hospital')) {
                      icon = Icons.local_hospital;
                    } else if (suggestion.types.contains('school') || suggestion.types.contains('university')) {
                      icon = Icons.school;
                    } else if (suggestion.types.contains('shopping_mall')) {
                      icon = Icons.ac_unit;
                    }

                    return ListTile(
                      leading: Icon(icon, color: Colors.blue.shade700),
                      title: Text(
                        suggestion.mainText,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: suggestion.secondaryText.isNotEmpty
                          ? Text(
                        suggestion.secondaryText,
                        style: TextStyle(color: Colors.grey.shade600),
                      )
                          : null,
                      onTap: () => _selectPlace(suggestion),
                    );
                  },
                ),
              ),
            ),

          // Route Options Panel
          if (availableRoutes.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Routes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: availableRoutes.length,
                        itemBuilder: (context, index) {
                          final route = availableRoutes[index];
                          return GestureDetector(
                            onTap: () => _selectRoute(index),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: index == 0 ? Colors.blue.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: index == 0 ? Colors.blue : Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    route.distance,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: index == 0 ? Colors.blue : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    route.duration,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (route.summary.isNotEmpty)
                                    Text(
                                      route.summary,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Loading Indicator
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Control Buttons
          Positioned(
            bottom: availableRoutes.isNotEmpty ? 140 : 30,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _getCurrentLocation,
                  heroTag: "location",
                  child: FaIcon(FontAwesomeIcons.locationCrosshairs, color: Colors.black,size: 20,),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () async {
                    final GoogleMapController controller = await _controller.future;
                    controller.animateCamera(
                      CameraUpdate.newCameraPosition(_kDhakaPosition),
                    );
                  },
                  heroTag: "dhaka",
                  child: FaIcon(FontAwesomeIcons.mapLocationDot, color: Colors.black,size: 19,),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Place suggestion model
class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final List<String> types;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    required this.types,
  });
}

// Route information model
class RouteInfo {
  final int routeIndex;
  final String distance;
  final String duration;
  final String summary;
  final List<LatLng> points;

  RouteInfo({
    required this.routeIndex,
    required this.distance,
    required this.duration,
    required this.summary,
    required this.points,
  });
}