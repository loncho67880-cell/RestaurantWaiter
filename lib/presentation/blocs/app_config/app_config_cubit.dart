import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/core/i18n/bootstrap_i18n.dart';
import 'package:restaurantwaiter/domain/models/country.dart';
import 'package:restaurantwaiter/domain/repositories/app_config_repository.dart';

class AppConfigState {
  final ThemeData themeData;
  final Map<String, String> localizedStrings;
  final String restaurantName;
  final String localeCode;
  final bool isLoading;
  final bool hasRemoteConfig;
  final String restaurantId;
  final String branchId;
  final String branchName;
  final String countriesDefaultCode;
  final List<Country> countries;
  final String? errorMessage;

  AppConfigState({
    required this.themeData,
    required this.localizedStrings,
    required this.restaurantName,
    required this.localeCode,
    this.isLoading = false,
    this.hasRemoteConfig = false,
    this.restaurantId = '',
    this.branchId = '',
    this.branchName = '',
    this.countriesDefaultCode = 'CO',
    this.countries = const [],
    this.errorMessage,
  });

  factory AppConfigState.initial() {
    return AppConfigState(
      themeData: _genericTheme(),
      localizedStrings: const {},
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
    bool? hasRemoteConfig,
    String? restaurantId,
    String? branchId,
    String? branchName,
    String? countriesDefaultCode,
    List<Country>? countries,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AppConfigState(
      themeData: themeData ?? this.themeData,
      localizedStrings: localizedStrings ?? this.localizedStrings,
      restaurantName: restaurantName ?? this.restaurantName,
      localeCode: localeCode ?? this.localeCode,
      isLoading: isLoading ?? this.isLoading,
      hasRemoteConfig: hasRemoteConfig ?? this.hasRemoteConfig,
      restaurantId: restaurantId ?? this.restaurantId,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      countriesDefaultCode: countriesDefaultCode ?? this.countriesDefaultCode,
      countries: countries ?? this.countries,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  static ThemeData _genericTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF5722)),
    );
  }
}

class AppConfigCubit extends Cubit<AppConfigState> {
  AppConfigCubit({
    required AppConfigRepository appConfigRepository,
  })  : _appConfigRepository = appConfigRepository,
        super(AppConfigState.initial());

  final AppConfigRepository _appConfigRepository;

  void selectRestaurant({
    required String restaurantId,
    required String restaurantName,
  }) {
    emit(state.copyWith(
      restaurantId: restaurantId,
      restaurantName: restaurantName,
    ));
  }

  void selectBranch({required String branchId, required String branchName}) {
    emit(state.copyWith(branchId: branchId, branchName: branchName));
  }

  void clearBranch() {
    emit(state.copyWith(branchId: '', branchName: ''));
  }

  void clearRestaurant() {
    emit(state.copyWith(
      restaurantId: '',
      restaurantName: '',
      branchId: '',
      branchName: '',
    ));
  }

  Future<void> loadBootstrap({String locale = 'es'}) async {
    try {
      final strings = await BootstrapI18n.load(locale);
      emit(AppConfigState(
        themeData: AppConfigState._genericTheme(),
        localizedStrings: strings,
        restaurantName: strings['appName'] ?? 'Kiosco',
        localeCode: locale,
        isLoading: false,
        hasRemoteConfig: false,
        restaurantId: '',
        branchId: '',
        branchName: '',
        errorMessage: null,
      ));
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[AppConfigCubit] loadBootstrap failed: $e\n$stack');
      }
      emit(state.copyWith(
        themeData: AppConfigState._genericTheme(),
        isLoading: false,
        hasRemoteConfig: false,
        localeCode: locale,
        restaurantId: '',
        restaurantName: '',
        branchId: '',
        branchName: '',
      ));
    }
  }

  Future<void> loadRemoteConfiguration({String locale = 'es'}) async {
    final restaurantId = state.restaurantId.trim();
    if (restaurantId.isEmpty) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'restaurantRequiredError',
      ));
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final bundle = await _appConfigRepository.loadAppConfig(
        restaurantId: restaurantId,
        lang: locale,
        appType: 'waiter',
      );

      final theme = bundle.theme;
      final primary = _parseColor(theme.primaryColor, const Color(0xFFFF5722));
      final secondary =
          _parseColor(theme.secondaryColor, const Color(0xFFFFC107));
      final background =
          _parseColor(theme.backgroundColor, const Color(0xFFF5F5F5));
      final surface = _parseColor(theme.surfaceColor, Colors.white);
      final onPrimary = _parseColor(theme.textOnPrimary, Colors.white);
      final onBackground =
          _parseColor(theme.textOnBackground, const Color(0xFF212121));

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
          displayLarge: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          bodyLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
      );

      emit(AppConfigState(
        themeData: customTheme,
        localizedStrings: bundle.strings,
        restaurantName: theme.restaurantName.isNotEmpty
            ? theme.restaurantName
            : bundle.restaurantName,
        localeCode: locale,
        isLoading: false,
        hasRemoteConfig: true,
        restaurantId: restaurantId,
        branchId: state.branchId,
        branchName: state.branchName,
        countriesDefaultCode: bundle.countriesDefaultCode,
        countries: bundle.countries,
        errorMessage: null,
      ));
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[AppConfigCubit] loadRemoteConfiguration failed: $e\n$stack');
      }
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'appConfigLoadError',
      ));
    }
  }

  Future<void> clearRemoteConfiguration() async {
    clearRestaurant();
    await loadBootstrap(locale: state.localeCode);
  }

  static Color _parseColor(Object? value, Color fallback) {
    if (value == null) return fallback;
    final raw = value.toString().trim();
    if (raw.isEmpty) return fallback;

    try {
      if (raw.startsWith('#')) {
        final hex = raw.replaceFirst('#', '');
        final normalized = hex.length == 6 ? 'FF$hex' : hex;
        return Color(int.parse(normalized, radix: 16));
      }
      if (raw.startsWith('0x')) {
        return Color(int.parse(raw));
      }
      return Color(int.parse(raw, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  String translate(String key, {Map<String, String>? replacements}) {
    String translated = state.localizedStrings[key] ?? key;
    if (replacements != null) {
      for (final entry in replacements.entries) {
        final placeholder =
            entry.key.startsWith('{') ? entry.key : '{${entry.key}}';
        translated = translated.replaceAll(placeholder, entry.value);
      }
    }
    return translated;
  }
}
