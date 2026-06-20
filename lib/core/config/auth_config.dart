import 'package:flutter/foundation.dart';

class AuthConfig {
  AuthConfig._();

  static bool _loginEnabledInDev = false;

  /// In production login is always required. In debug/profile it can be toggled.
  static bool get isLoginRequired => kReleaseMode || _loginEnabledInDev;

  static bool get loginEnabledInDev => _loginEnabledInDev;

  static bool get canToggleLogin => !kReleaseMode;

  static void setLoginEnabledInDev(bool enabled) {
    if (kReleaseMode) return;
    _loginEnabledInDev = enabled;
  }
}
