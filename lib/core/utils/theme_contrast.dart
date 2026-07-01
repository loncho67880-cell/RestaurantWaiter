import 'package:flutter/material.dart';

/// Helpers for themes where [ColorScheme.surface] is dark but cards use a light
/// background (Material 3 defaults).
abstract final class ThemeContrast {
  static const Color onLight = Color(0xFF1C1B1F);
  static const Color onLightMuted = Color(0xFF49454F);

  static bool isDark(Color color) => color.computeLuminance() < 0.5;

  static Color navUnselected(ThemeData theme) {
    if (isDark(theme.colorScheme.surface)) {
      return Colors.white.withValues(alpha: 0.95);
    }
    return theme.colorScheme.onSurface.withValues(alpha: 0.75);
  }

  static ThemeData lightCardTheme(ThemeData theme) {
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        onSurface: onLight,
        onSurfaceVariant: onLightMuted,
      ),
      textTheme: theme.textTheme.apply(
        bodyColor: onLight,
        displayColor: onLight,
      ),
    );
  }

  static NavigationBarThemeData navigationBarTheme({
    required Color surface,
    required Color primary,
    required Color onBackground,
  }) {
    final darkSurface = isDark(surface);
    final unselected = darkSurface
        ? Colors.white.withValues(alpha: 0.95)
        : onBackground.withValues(alpha: 0.75);

    return NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: primary.withValues(alpha: 0.22),
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: primary, size: 24);
        }
        return IconThemeData(color: unselected, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: primary,
          );
        }
        return TextStyle(fontSize: 12, color: unselected);
      }),
    );
  }

  static CardThemeData cardTheme(Color surface) {
    final darkSurface = isDark(surface);
    return CardThemeData(
      color: darkSurface ? Colors.white : surface,
      elevation: 2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
