import 'package:dio/dio.dart';
import 'package:restaurantwaiter/domain/models/reservation.dart';
import 'package:restaurantwaiter/domain/repositories/reservation_repository.dart';

class ReservationRepositoryImpl implements ReservationRepository {
  final Dio _dio;

  ReservationRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<List<Reservation>> getActiveReservations({
    required String branchId,
    required String accessToken,
  }) async {
    final options =
        Options(headers: {'Authorization': 'Bearer $accessToken'});

    try {
      // NEW/EXPECTED waiter endpoint: active reservations for a branch.
      final response = await _dio.get(
        '/api/reservations/branch/$branchId/active',
        options: options,
      );
      return _parseList(response.data);
    } on DioException {
      // Graceful fallback to the generic reservations endpoint filtered by
      // branch, in case the waiter-specific route is not yet deployed.
      final response = await _dio.get(
        '/api/reservations',
        queryParameters: {'branchId': branchId},
        options: options,
      );
      return _parseList(response.data)
          .where((r) => !r.isCancelled)
          .toList();
    }
  }

  @override
  Future<Reservation> confirmByWaiter({
    required String reservationId,
    required String accessToken,
  }) async {
    // NEW/EXPECTED endpoint: sets preOrderStatus to EnPreparacion (to kitchen).
    final response = await _dio.put(
      '/api/reservations/$reservationId/confirm-waiter',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return Reservation.fromJson(response.data as Map<String, dynamic>);
  }

  List<Reservation> _parseList(dynamic data) {
    final list = data as List<dynamic>;
    return list
        .map((e) => Reservation.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
