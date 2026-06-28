import 'dart:convert';

import 'package:flutter/services.dart';

class BootstrapI18n {
  BootstrapI18n._();

  static Future<Map<String, String>> load(String locale) async {
    final code = locale == 'en' ? 'en' : 'es';
    final jsonStr = await rootBundle.loadString(
      'assets/i18n/bootstrap_$code.json',
    );
    final decoded = json.decode(jsonStr);
    if (decoded is! Map) return const {};

    return decoded.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }
}
