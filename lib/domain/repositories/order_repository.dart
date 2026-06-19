import '../models/manual_order.dart';
import '../models/table_model.dart';

abstract class OrderRepository {
  /// Lists the tables of a branch that are free right now, so the waiter can
  /// pick one for a walk-in order.
  Future<List<TableModel>> getAvailableTables({
    required String branchId,
    required String accessToken,
  });

  /// Submits a manual (walk-in) order for a table without a reservation.
  Future<void> createManualOrder({
    required ManualOrder order,
    required String accessToken,
  });
}
