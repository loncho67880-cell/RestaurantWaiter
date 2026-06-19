import 'dart:ui';

class RestaurantTheme {
  final String name;
  final Color primary;
  final Color background;
  final Color surface;
  final Color onPrimary;
  final Color onBackground;

  RestaurantTheme({
    required this.name,
    required this.primary,
    required this.background,
    required this.surface,
    required this.onPrimary,
    required this.onBackground,
  });

  // Método helper para convertir hex string a Color
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
