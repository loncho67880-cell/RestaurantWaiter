import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:restaurantwaiter/domain/models/reservation.dart';
import 'package:restaurantwaiter/domain/models/reservation_item.dart';
import 'package:restaurantwaiter/domain/repositories/reservation_repository.dart';

class ReservationRepositoryImpl implements ReservationRepository {
  final Dio _dio;

  ReservationRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<List<Reservation>> getActiveReservations({
    required String branchId,
    required String accessToken,
  }) async {
    if (branchId.trim().isEmpty) {
      throw Exception('branchId no seleccionado. Elige una sede primero.');
    }

    final options =
        Options(headers: {'Authorization': 'Bearer $accessToken'});

    try {
      final response = await _dio.get(
        '/api/reservations/branch/$branchId/active',
        options: options,
      );

      final reservations = _parseList(response.data);
      debugPrint(
        '[Reservations] branch=$branchId count=${reservations.length}',
      );
      if (reservations.isNotEmpty) return reservations;

      // Some environments return an empty list from /active while still
      // exposing reservations through the generic branch query endpoint.
      return await _fetchFromGenericEndpoint(
        branchId: branchId,
        options: options,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      debugPrint(
        '[Reservations] active failed status=$status body=$body message=${e.message}',
      );

      if (status == 401) {
        throw Exception(
          'Sesión inválida. Inicia sesión con Google (no uses "Entrar sin login").',
        );
      }

      try {
        return await _fetchFromGenericEndpoint(
          branchId: branchId,
          options: options,
        );
      } on DioException {
        throw Exception(
          'No se pudieron cargar las reservas${status != null ? ' (HTTP $status)' : ''}. '
          'Verifica apiBaseUrl en appsettings y que el Gateway/API esté encendido.',
        );
      }
    } catch (e) {
      debugPrint('[Reservations] parse/load error: $e');
      rethrow;
    }
  }

  @override
  Future<Reservation> confirmByWaiter({
    required String reservationId,
    required String accessToken,
  }) async {
    final response = await _dio.put(
      '/api/reservations/$reservationId/confirm-waiter',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return Reservation.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Reservation> confirmAtTableByWaiter({
    required String reservationId,
    required String accessToken,
  }) async {
    final response = await _dio.put(
      '/api/reservations/$reservationId/confirm-at-table/waiter',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return Reservation.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Reservation> updateItemsByWaiter({
    required String reservationId,
    required List<ReservationItem> items,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.put(
        '/api/reservations/$reservationId/items',
        data: {
          'items': items.map((i) => i.toJson()).toList(),
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return Reservation.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      debugPrint(
        '[Reservations] updateItemsByWaiter failed status=$status body=$body',
      );
      final message = _extractApiMessage(body);
      throw Exception(
        message ??
            'No se pudo guardar la pre-orden${status != null ? ' (HTTP $status)' : ''}',
      );
    }
  }

  String? _extractApiMessage(dynamic body) {
    if (body is Map<String, dynamic>) {
      final message = body['message'] ?? body['Message'];
      if (message != null) return message.toString();
    }
    if (body is String && body.isNotEmpty) return body;
    return null;
  }

  @override
  Future<void> markReadyForPayment({
    required String reservationId,
    required String accessToken,
  }) async {
    await _dio.put(
      '/api/reservations/$reservationId/ready-for-payment',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  @override
  Future<Reservation> cancelByWaiter({
    required String reservationId,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.put(
        '/api/reservations/$reservationId/cancel-waiter',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return Reservation.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      debugPrint(
        '[Reservations] cancelByWaiter failed status=$status body=$body',
      );
      final message = _extractApiMessage(body);
      throw Exception(
        message ??
            'No se pudo cancelar la reserva${status != null ? ' (HTTP $status)' : ''}',
      );
    }
  }

  List<Reservation> _parseList(dynamic data) {
    final list = _extractList(data);
    return list
        .map((e) => Reservation.fromJson(e as Map<String, dynamic>))
        .where((r) => !r.isReadyForPayment && _isToday(r.reservationDate))
        .toList();
  }

  bool _isToday(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List<dynamic>) return data;
    if (data is Map<String, dynamic>) {
      for (final key in const ['data', 'reservations', 'items', 'results']) {
        final value = data[key];
        if (value is List<dynamic>) return value;
      }
    }
    throw FormatException('Respuesta de reservas no es una lista: $data');
  }

  Future<List<Reservation>> _fetchFromGenericEndpoint({
    required String branchId,
    required Options options,
  }) async {
    final response = await _dio.get(
      '/api/reservations',
      queryParameters: {'branchId': branchId},
      options: options,
    );
    final reservations = _parseList(response.data);
    final filtered = reservations
        .where((r) => !r.isCancelled && _isToday(r.reservationDate))
        .toList();
    debugPrint(
      '[Reservations] generic branch=$branchId count=${filtered.length}',
    );
    return filtered;
  }
}
