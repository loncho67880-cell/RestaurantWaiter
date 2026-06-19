class Customer {
  final String id;
  final String name;
  final String email;
  final String token;
  final String? phone;
  final String? documentNumber;
  final String? city;
  final String? country;
  final String? preferredLanguage;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.token,
    this.phone,
    this.documentNumber,
    this.city,
    this.country,
    this.preferredLanguage,
  });

  bool get needsProfileCompletion {
    if (token == 'dev-token') return false;

    return !_hasValue(phone) ||
        !_hasValue(documentNumber) ||
        !_hasValue(city) ||
        !_hasValue(country) ||
        !_hasValue(preferredLanguage);
  }

  Customer copyWith({
    String? id,
    String? name,
    String? email,
    String? token,
    String? phone,
    String? documentNumber,
    String? city,
    String? country,
    String? preferredLanguage,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      token: token ?? this.token,
      phone: phone ?? this.phone,
      documentNumber: documentNumber ?? this.documentNumber,
      city: city ?? this.city,
      country: country ?? this.country,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }

  factory Customer.fromJson(
    Map<String, dynamic> json, {
    required String token,
  }) {
    return Customer(
      id: json['id']?.toString() ?? json['customerId']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      token: token,
      phone: json['phone'] as String?,
      documentNumber: json['documentNumber'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      preferredLanguage: json['preferredLanguage'] as String?,
    );
  }

  static bool _hasValue(String? value) =>
      value != null && value.trim().isNotEmpty;
}
