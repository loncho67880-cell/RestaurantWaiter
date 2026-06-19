import 'package:dio/dio.dart';
import 'package:restaurantwaiter/domain/models/manual_order.dart';
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
    // Reuses the existing tables endpoint with "now" so the waiter sees tables
    // that are free at this moment for a walk-in.
    final response = await _dio.get(
      '/api/reservations/tables',
      queryParameters: {
        'branchId': branchId,
        'reservationDate': DateTime.now().toUtc().toIso8601String(),
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = response.data as List<dynamic>;
    return data
        .map((e) => TableModel.fromJson(e as Map<String, dynamic>))
        .toList();
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
}
