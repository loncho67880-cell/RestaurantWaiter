import 'dart:convert';

import 'package:flutter/services.dart';

class AppSettings {
  final String apiBaseUrl;
  final String restaurantId;

  const AppSettings({
    required this.apiBaseUrl,
    required this.restaurantId,
  });

  static Future<AppSettings> load() async {
    final jsonStr = await rootBundle.loadString('assets/cfg/appsettings.json');
    final Map<String, dynamic> json = jsonDecode(jsonStr);

    return AppSettings(
      apiBaseUrl: json['apiBaseUrl'] as String,
      restaurantId: json['restaurantId'] as String,
    );
  }
}
