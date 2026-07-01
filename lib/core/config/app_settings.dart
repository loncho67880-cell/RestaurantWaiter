import 'dart:convert';

import 'package:flutter/services.dart';

class AppSettings {
  final String apiBaseUrl;

  const AppSettings({
    required this.apiBaseUrl,
  });

  static Future<AppSettings> load() async {
    final jsonStr = await rootBundle.loadString('assets/cfg/appsettings.json');
    final Map<String, dynamic> json = jsonDecode(jsonStr);

    return AppSettings(
      apiBaseUrl: json['apiBaseUrl'] as String,
    );
  }
}
