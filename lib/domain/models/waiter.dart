class Waiter {
  final String id;
  final String name;
  final String email;
  final String token;
  final String? preferredLanguage;
  final String? defaultBranchId;

  const Waiter({
    required this.id,
    required this.name,
    required this.email,
    required this.token,
    this.preferredLanguage,
    this.defaultBranchId,
  });

  factory Waiter.fromJson(
    Map<String, dynamic> json, {
    required String token,
  }) {
    return Waiter(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      token: token,
      preferredLanguage: json['preferredLanguage'] as String?,
      defaultBranchId: json['defaultBranchId']?.toString(),
    );
  }
}
