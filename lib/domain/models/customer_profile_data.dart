class CustomerProfileData {
  final String phone;
  final String documentNumber;
  final String city;
  final String country;
  final String preferredLanguage;

  const CustomerProfileData({
    required this.phone,
    required this.documentNumber,
    required this.city,
    required this.country,
    required this.preferredLanguage,
  });

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'documentNumber': documentNumber,
        'city': city,
        'country': country,
        'preferredLanguage': preferredLanguage,
      };
}
