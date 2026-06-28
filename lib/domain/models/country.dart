class Country {
  final String code;
  final String flag;
  final Map<String, String> name;

  const Country({
    required this.code,
    required this.flag,
    required this.name,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] as Map<String, dynamic>;
    return Country(
      code: json['code'] as String,
      flag: json['flag'] as String,
      name: rawName.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  String nameForLocale(String localeCode) {
    return name[localeCode] ?? name['es'] ?? code;
  }
}
