import 'package:dio/dio.dart';
import 'package:restaurantwaiter/domain/exceptions/waiter_not_registered_exception.dart';
import 'package:restaurantwaiter/domain/models/auth_sign_in_result.dart';
import 'package:restaurantwaiter/domain/models/waiter.dart';
import 'package:restaurantwaiter/domain/models/waiter_restaurant.dart';

import '../../domain/repositories/auth_repository.dart';
import '../services/google_auth_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final Dio dio;
  final GoogleAuthService googleAuthService;

  AuthRepositoryImpl({
    required this.dio,
    required this.googleAuthService,
  });

  @override
  Future<AuthSignInResult> signInWithGoogle() async {
    final idToken = await googleAuthService.signIn();

    try {
      final response = await dio.post(
        '/api/waiterauth/google',
        data: {'idToken': idToken},
      );

      return _parseAuthResponse(response.data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<Waiter> selectRestaurant(String restaurantId) async {
    try {
      final response = await dio.post(
        '/api/waiterauth/select-restaurant',
        data: {'restaurantId': restaurantId},
      );

      final result = _parseAuthResponse(response.data);
      return result.waiter;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  AuthSignInResult _parseAuthResponse(Object? raw) {
    final data = raw as Map<String, dynamic>;
    final waiterData = data['waiter'] as Map<String, dynamic>? ?? data;
    final restaurants = _parseRestaurants(data, waiterData);

    return AuthSignInResult(
      waiter: Waiter.fromJson(
        waiterData,
        token: data['accessToken'] as String,
      ),
      restaurants: restaurants,
    );
  }

  List<WaiterRestaurant> _parseRestaurants(
    Map<String, dynamic> data,
    Map<String, dynamic> waiterData,
  ) {
    final fromRoot = WaiterRestaurant.listFromJson(
      data['restaurants'] ?? data['Restaurants'],
    );
    if (fromRoot.isNotEmpty) return fromRoot;

    final fromWaiter = WaiterRestaurant.listFromJson(
      waiterData['restaurants'] ??
          waiterData['Restaurants'] ??
          waiterData['assignedRestaurants'] ??
          waiterData['AssignedRestaurants'],
    );
    if (fromWaiter.isNotEmpty) return fromWaiter;

    final singleId = (waiterData['restaurantId'] ??
            waiterData['RestaurantId'] ??
            data['restaurantId'] ??
            data['RestaurantId'])
        ?.toString();
    if (singleId != null && singleId.isNotEmpty) {
      final name = (waiterData['restaurantName'] ??
              waiterData['RestaurantName'] ??
              data['restaurantName'] ??
              data['RestaurantName'])
          as String?;
      return [WaiterRestaurant(id: singleId, name: name ?? '')];
    }

    return const [];
  }

  Never _mapDioException(DioException e) {
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
    throw e;
  }

  @override
  Future<void> signOut() async {
    await googleAuthService.signOut();
  }
}
