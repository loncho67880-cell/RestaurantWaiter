import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:restaurantwaiter/core/utils/reservation_datetime.dart';
import 'package:restaurantwaiter/domain/models/manual_order.dart';
import 'package:restaurantwaiter/domain/models/reservation.dart';
import 'package:restaurantwaiter/domain/models/table_model.dart';
import 'package:restaurantwaiter/domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  final Dio _dio;

  OrderRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<List<TableModel>> getAvailableTables({
    required String branchId,
    required String accessToken,
  }) async {
    if (branchId.trim().isEmpty) {
      throw Exception('branchId no seleccionado. Elige una sede primero.');
    }

    try {
      // Reuses the existing tables endpoint with "now" so the waiter sees
      // tables that are free at this moment for a walk-in.
      final response = await _dio.get(
        '/api/reservations/tables',
        queryParameters: {
          'branchId': branchId,
          'reservationDate': formatApiReservationDate(DateTime.now()),
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      return _parseTables(response.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      debugPrint(
        '[Tables] getAvailableTables failed status=$status body=$body message=${e.message}',
      );
      rethrow;
    }
  }

  List<TableModel> _parseTables(dynamic data) {
    final list = _extractList(data);
    return list
        .map((e) => TableModel.fromJson(e as Map<String, dynamic>))
        .where((t) => t.isAvailable)
        .toList();
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List<dynamic>) return data;
    if (data is Map<String, dynamic>) {
      for (final key in const ['data', 'tables', 'items', 'results']) {
        final value = data[key];
        if (value is List<dynamic>) return value;
      }
    }
    throw FormatException('Respuesta de mesas no es una lista: $data');
  }

  @override
  Future<void> createManualOrder({
    required ManualOrder order,
    required String accessToken,
  }) async {
    // Backend endpoint: creates a walk-in order that goes straight to the
    // kitchen (PreOrderStatus = EnCocina). Implemented as an already-confirmed
    // reservation. Expected payload (see ManualOrder.toJson):
    // {
    //   "restaurantId": "<uuid>",
    //   "branchId": "<uuid>",
    //   "tableId": "<uuid>",
    //   "guestCount": 4,
    //   "notes": "optional",
    //   "items": [
    //     { "dishId", "dishName", "quantity", "unitPrice", "additions" }
    //   ]
    // }
    await _dio.post(
      '/api/orders/walk-in',
      data: order.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  @override
  Future<List<Reservation>> getReadyForPayment({
    required String branchId,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.get(
        '/api/reservations/branch/$branchId/ready-for-payment',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final list = _extractList(response.data);
      return list
          .map((e) => Reservation.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('[ReadyToPay] getReadyForPayment failed: ${e.message}');
      rethrow;
    }
  }

  @override
  Future<Reservation> markAsPaidByWaiter({
    required String reservationId,
    required String accessToken,
  }) async {
    final response = await _dio.put(
      '/api/reservations/$reservationId/mark-paid/waiter',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return Reservation.fromJson(response.data as Map<String, dynamic>);
  }
}
