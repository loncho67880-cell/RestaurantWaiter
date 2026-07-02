import 'package:flutter/material.dart';

/// Central contrast rules for restaurant themes (e.g. Corral dark brown UI).
///
/// When [surface] or [scaffold background] is dark, foreground text and icons
/// must be light. [ColorScheme.fromSeed] alone leaves [onSurfaceVariant] dark,
/// which breaks ListTile subtitles, prices, and quantity labels.
abstract final class ThemeContrast {
  static const Color onLight = Color(0xFF1C1B1F);
  static const Color onLightMuted = Color(0xFF49454F);

  static bool isDark(Color color) => color.computeLuminance() < 0.5;

  /// Primary body text on the current theme surface.
  static Color bodyText(ThemeData theme) => theme.colorScheme.onSurface;

  /// Secondary text (prices, hints, unselected labels).
  static Color mutedText(ThemeData theme) => theme.colorScheme.onSurfaceVariant;

  /// Icons on the main surface (quantity +/-, list icons).
  static Color iconOnSurface(ThemeData theme) => mutedText(theme);

  static Color readableOnDark(Color candidate) {
    return isDark(candidate)
        ? Colors.white.withValues(alpha: 0.95)
        : candidate;
  }

  static Color readableOnLight(Color candidate) {
    return isDark(candidate) ? candidate : onLight;
  }

  static ColorScheme contrastColorScheme({
    required Color seedColor,
    required Color primary,
    required Color secondary,
    required Color surface,
    required Color background,
    required Color onPrimary,
    required Color textOnBackground,
  }) {
    final darkUI = isDark(surface) || isDark(background);
    final onSurface = darkUI
        ? readableOnDark(textOnBackground)
        : readableOnLight(textOnBackground);
    final onMuted = darkUI
        ? onSurface.withValues(alpha: 0.78)
        : onSurface.withValues(alpha: 0.65);

    final base = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: darkUI ? Brightness.dark : Brightness.light,
      primary: primary,
      secondary: secondary,
    );

    return base.copyWith(
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onMuted,
      onPrimary: onPrimary,
    );
  }

  static ThemeData buildRemoteTheme({
    required Color primary,
    required Color secondary,
    required Color background,
    required Color surface,
    required Color onPrimary,
    required Color textOnBackground,
  }) {
    final colorScheme = contrastColorScheme(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      surface: surface,
      background: background,
      onPrimary: onPrimary,
      textOnBackground: textOnBackground,
    );
    final onSurface = colorScheme.onSurface;
    final onMuted = colorScheme.onSurfaceVariant;

    return ThemeData(
      useMaterial3: true,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      cardTheme: cardTheme(surface),
      navigationBarTheme: navigationBarTheme(
        surface: surface,
        primary: primary,
        onBackground: onSurface,
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 14,
          color: onMuted,
        ),
        iconColor: onMuted,
      ),
      iconTheme: IconThemeData(color: onMuted),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: onSurface,
        ),
        bodyMedium: TextStyle(color: onSurface),
        bodySmall: TextStyle(color: onMuted),
        titleMedium: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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
      listTileTheme: theme.listTileTheme.copyWith(
        titleTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: onLight,
        ),
        subtitleTextStyle: const TextStyle(
          fontSize: 14,
          color: onLightMuted,
        ),
        iconColor: onLightMuted,
      ),
      iconTheme: const IconThemeData(color: onLightMuted),
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
