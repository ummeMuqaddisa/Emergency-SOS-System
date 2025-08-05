class PStationModel {
  final String stationName;
  final String phone;
  final String address;
  final Map<String, dynamic> location; // {'latitude': double, 'longitude': double}

  PStationModel({
    required this.stationName,
    required this.phone,
    required this.address,
    required this.location,
  });

  factory PStationModel.fromJson(Map<String, dynamic> json) {
    return PStationModel(
      stationName: json['stationName'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      location: {
        'latitude': (json['location']?['latitude'] ?? 0.0) as double,
        'longitude': (json['location']?['longitude'] ?? 0.0) as double,
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stationName': stationName,
      'phone': phone,
      'address': address,
      'location': {
        'latitude': location['latitude'],
        'longitude': location['longitude'],
      },
    };
  }
}
