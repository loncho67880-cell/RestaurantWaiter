import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;

  static const String serverClientId =
      '603426797094-iemdg9vr03nr351hk4tehueh7e5toj5k.apps.googleusercontent.com';

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    if (kIsWeb) {
      await _googleSignIn.initialize(clientId: serverClientId);
    } else {
      await _googleSignIn.initialize(serverClientId: serverClientId);
    }
    _initialized = true;
  }

  Future<String?> signIn() async {
    try {
      await _ensureInitialized();
      final account = await _googleSignIn.authenticate();
      final auth = await account.authentication;
      return auth.idToken;
    } on GoogleSignInException catch (e) {
      final code = e.code.name;
      final detail = e.description ?? 'sin detalle';
      debugPrint('[GoogleSignIn] code=$code | $detail');
      throw Exception(_friendlyMessage(e.code, detail));
    } catch (e) {
      debugPrint('[GoogleSignIn] error inesperado: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  static String _friendlyMessage(
    GoogleSignInExceptionCode code,
    String detail,
  ) {
    switch (code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Configuración de Google Sign-In incorrecta. Verifica el OAuth client.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google Play Services no disponible o mal configurado.';
      case GoogleSignInExceptionCode.canceled:
        return 'Inicio de sesión cancelado.';
      case GoogleSignInExceptionCode.interrupted:
        return 'El proceso fue interrumpido. Intenta de nuevo.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'No se puede mostrar Google Sign-In. Agrega una cuenta Google en Ajustes → Cuentas.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'El usuario no coincide con el usuario actual.';
      case GoogleSignInExceptionCode.unknownError:
        return 'Error desconocido de Google Sign-In: $detail';
    }
  }
}
