import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppConfigState {
  final ThemeData themeData;
  final Map<String, String> localizedStrings;
  final String restaurantName;
  final String localeCode;
  final bool isLoading;
  final String restaurantId;
  final String branchId;
  final String branchName;

  AppConfigState({
    required this.themeData,
    required this.localizedStrings,
    required this.restaurantName,
    required this.localeCode,
    this.isLoading = false,
    this.restaurantId = '',
    this.branchId = '',
    this.branchName = '',
  });

  factory AppConfigState.initial() {
    return AppConfigState(
      themeData: ThemeData.light(),
      localizedStrings: {},
      restaurantName: '',
      localeCode: 'es',
      isLoading: true,
    );
  }

  AppConfigState copyWith({
    ThemeData? themeData,
    Map<String, String>? localizedStrings,
    String? restaurantName,
    String? localeCode,
    bool? isLoading,
    String? restaurantId,
    String? branchId,
    String? branchName,
  }) {
    return AppConfigState(
      themeData: themeData ?? this.themeData,
      localizedStrings: localizedStrings ?? this.localizedStrings,
      restaurantName: restaurantName ?? this.restaurantName,
      localeCode: localeCode ?? this.localeCode,
      isLoading: isLoading ?? this.isLoading,
      restaurantId: restaurantId ?? this.restaurantId,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
    );
  }
}

class AppConfigCubit extends Cubit<AppConfigState> {
  AppConfigCubit() : super(AppConfigState.initial());

  void selectBranch({required String branchId, required String branchName}) {
    emit(state.copyWith(branchId: branchId, branchName: branchName));
  }

  void clearBranch() {
    emit(state.copyWith(branchId: '', branchName: ''));
  }

  Future<void> loadConfiguration({String locale = 'es'}) async {
    try {
      // 1. Cargar settings de la app (IDs de tenant)
      final settingsStr = await rootBundle.loadString('assets/cfg/appsettings.json');
      final Map<String, dynamic> settingsJson = json.decode(settingsStr);
      final restaurantId = settingsJson['restaurantId'] as String? ?? '';

      // 2. Cargar el JSON del Tema Dinámico
      final themeStr = await rootBundle.loadString('assets/cfg/theme_config.json');
      final Map<String, dynamic> themeJson = json.decode(themeStr);

      final Color primary = Color(int.parse(themeJson['primaryColor'].replaceAll('#', '0xFF')));
      final Color secondary = Color(int.parse(themeJson['secondaryColor'].replaceAll('#', '0xFF')));
      final Color background = Color(int.parse(themeJson['backgroundColor'].replaceAll('#', '0xFF')));
      final Color surface = Color(int.parse(themeJson['surfaceColor'].replaceAll('#', '0xFF')));
      final Color onPrimary = Color(int.parse(themeJson['textOnPrimary'].replaceAll('#', '0xFF')));
      final Color onBackground = Color(int.parse(themeJson['textOnBackground'].replaceAll('#', '0xFF')));

      final customTheme = ThemeData(
        useMaterial3: true,
        primaryColor: primary,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: secondary,
          surface: surface,
          onPrimary: onPrimary,
          onSurface: onBackground,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black),
          bodyLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
      );

      // 3. Cargar el JSON de Idioma (i18n)
      final i18nStr = await rootBundle.loadString('assets/i18n/$locale.json');
      final Map<String, dynamic> i18nJson = json.decode(i18nStr);
      final Map<String, String> localized = i18nJson.map((key, value) => MapEntry(key, value.toString()));

      emit(AppConfigState(
        themeData: customTheme,
        localizedStrings: localized,
        restaurantName: themeJson['restaurantName'] ?? 'Restaurante',
        localeCode: locale,
        isLoading: false,
        restaurantId: restaurantId,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false));
    }
  }

  String translate(String key, {Map<String, String>? replacements}) {
    String translated = state.localizedStrings[key] ?? key;
    if (replacements != null) {
      for (final entry in replacements.entries) {
        final placeholder = entry.key.startsWith('{')
            ? entry.key
            : '{${entry.key}}';
        translated = translated.replaceAll(placeholder, entry.value);
      }
    }
    return translated;
  }
}
