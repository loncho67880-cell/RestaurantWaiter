import 'package:dio/dio.dart';
import 'package:restaurantwaiter/domain/models/customer.dart';
import 'package:restaurantwaiter/domain/models/customer_profile_data.dart';

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
  Future<Customer> signInWithGoogle() async {
    final idToken = await googleAuthService.signIn();

    // The backend distinguishes the "waiter" role from the same Google login
    // endpoint based on the authenticated account.
    final response = await dio.post(
      '/api/GoogleAuth/google',
      data: {
        'idToken': idToken,
        'restaurantId': restaurantId,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final customerData =
        data['customer'] as Map<String, dynamic>? ?? data;

    return Customer.fromJson(
      customerData,
      token: data['accessToken'] as String,
    );
  }

  @override
  Future<Customer> updateProfile(
    Customer customer,
    CustomerProfileData profile,
  ) async {
    final response = await dio.put(
      '/api/GoogleAuth/profile',
      data: profile.toJson(),
      options: Options(
        headers: {'Authorization': 'Bearer ${customer.token}'},
      ),
    );

    return Customer.fromJson(
      response.data as Map<String, dynamic>,
      token: customer.token,
    );
  }

  @override
  Future<void> signOut() async {
    await googleAuthService.signOut();
  }
}
