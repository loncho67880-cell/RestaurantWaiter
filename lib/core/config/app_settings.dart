import 'dart:convert';

import 'package:flutter/services.dart';

class AppSettings {
  final String apiBaseUrl;
  final String restaurantId;
  final String branchId;

  const AppSettings({
    required this.apiBaseUrl,
    required this.restaurantId,
    required this.branchId,
  });

  static Future<AppSettings> load() async {
    final jsonStr = await rootBundle.loadString('assets/cfg/appsettings.json');
    final Map<String, dynamic> json = jsonDecode(jsonStr);

    return AppSettings(
      apiBaseUrl: json['apiBaseUrl'] as String,
      restaurantId: json['restaurantId'] as String,
      branchId: json['branchId'] as String,
    );
  }
}
