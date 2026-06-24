import 'package:dio/dio.dart';
import 'package:restaurantwaiter/domain/exceptions/waiter_not_registered_exception.dart';
import 'package:restaurantwaiter/domain/models/waiter.dart';

import '../../domain/repositories/auth_repository.dart';
import '../services/google_auth_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final Dio dio;
  final GoogleAuthService googleAuthService;
  final String restaurantId;

  AuthRepositoryImpl({
    required this.dio,
    required this.googleAuthService,
    required this.restaurantId,
  });

  @override
  Future<Waiter> signInWithGoogle() async {
    final idToken = await googleAuthService.signIn();

    try {
      final response = await dio.post(
        '/api/waiterauth/google',
        data: {
          'idToken': idToken,
          'restaurantId': restaurantId,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final waiterData =
          data['waiter'] as Map<String, dynamic>? ?? data;

      return Waiter.fromJson(
        waiterData,
        token: data['accessToken'] as String,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        final body = e.response?.data;
        final message = body is Map<String, dynamic>
            ? body['message'] as String? ?? body['Message'] as String?
            : null;
        throw WaiterNotRegisteredException(
          message ??
              'No está registrado como mesero. Contacte al administrador.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await googleAuthService.signOut();
  }
}
