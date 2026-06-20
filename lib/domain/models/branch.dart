import 'package:restaurantwaiter/core/utils/local_time.dart';

class Branch {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String city;
  final String stateOrProvince;
  final String country;
  final double? latitude;
  final double? longitude;
  final LocalTime openingTime;
  final LocalTime closingTime;

  const Branch({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.city,
    required this.stateOrProvince,
    required this.country,
    this.latitude,
    this.longitude,
    required this.openingTime,
    required this.closingTime,
  });

  bool get hasLocation => latitude != null && longitude != null;

  String get operatingHoursLabel =>
      '${openingTime.format24h()} - ${closingTime.format24h()}';

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
        id: json['branchId'] as String,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        address: json['address'] as String? ?? '',
        city: json['city'] as String? ?? '',
        stateOrProvince: json['stateOrProvince'] as String? ?? '',
        country: json['country'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        openingTime:
            LocalTime.parse(json['openingTime']) ?? const LocalTime(10, 0),
        closingTime:
            LocalTime.parse(json['closingTime']) ?? const LocalTime(22, 0),
      );
}
