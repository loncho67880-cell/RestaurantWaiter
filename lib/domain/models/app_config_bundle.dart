import 'package:restaurantwaiter/domain/models/country.dart';

class AppConfigBundle {
  final String restaurantId;
  final String lang;
  final String appType;
  final String restaurantName;
  final ThemeConfig theme;
  final Map<String, String> strings;
  final String countriesDefaultCode;
  final List<Country> countries;

  const AppConfigBundle({
    required this.restaurantId,
    required this.lang,
    required this.appType,
    required this.restaurantName,
    required this.theme,
    required this.strings,
    required this.countriesDefaultCode,
    required this.countries,
  });

  factory AppConfigBundle.fromJson(Map<String, dynamic> json) {
    final themeJson = _readMap(json, 'theme');
    final countriesJson = _readMap(json, 'countries');
    final stringsJson = _readMap(json, 'strings');
    final countriesList = countriesJson['countries'] as List<dynamic>? ?? [];

    return AppConfigBundle(
      restaurantId: json['restaurantId']?.toString() ?? '',
      lang: json['lang']?.toString() ?? 'es',
      appType: json['appType']?.toString() ?? 'waiter',
      restaurantName: themeJson['restaurantName']?.toString() ?? '',
      theme: ThemeConfig.fromJson(themeJson),
      strings: stringsJson.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      countriesDefaultCode: countriesJson['defaultCode']?.toString() ?? 'CO',
      countries: countriesList
          .whereType<Map>()
          .map((item) => Country.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  static Map<String, dynamic> _readMap(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }
}

class ThemeConfig {
  final String restaurantName;
  final String primaryColor;
  final String secondaryColor;
  final String backgroundColor;
  final String surfaceColor;
  final String textOnPrimary;
  final String textOnBackground;

  const ThemeConfig({
    required this.restaurantName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.textOnPrimary,
    required this.textOnBackground,
  });

  factory ThemeConfig.fromJson(Map<String, dynamic> json) {
    return ThemeConfig(
      restaurantName: json['restaurantName']?.toString() ?? '',
      primaryColor: json['primaryColor']?.toString() ?? '#FF5722',
      secondaryColor: json['secondaryColor']?.toString() ?? '#FFC107',
      backgroundColor: json['backgroundColor']?.toString() ?? '#F5F5F5',
      surfaceColor: json['surfaceColor']?.toString() ?? '#FFFFFF',
      textOnPrimary: json['textOnPrimary']?.toString() ?? '#FFFFFF',
      textOnBackground: json['textOnBackground']?.toString() ?? '#212121',
    );
  }
}
