import 'reservation_item.dart';

/// An order created by a waiter for a walk-in table (no prior reservation).
///
/// Sent to the `POST /api/orders/walk-in` backend endpoint, which creates an
/// already-confirmed reservation routed straight to the kitchen.
class ManualOrder {
  final String restaurantId;
  final String branchId;
  final String tableId;
  final int guestCount;
  final String? notes;
  final List<ReservationItem> items;

  const ManualOrder({
    required this.restaurantId,
    required this.branchId,
    required this.tableId,
    required this.guestCount,
    this.notes,
    required this.items,
  });

  double get total => items.fold(0.0, (sum, item) => sum + item.subtotal);

  Map<String, dynamic> toJson() => {
        'restaurantId': restaurantId,
        'branchId': branchId,
        'tableId': tableId,
        'guestCount': guestCount,
        'notes': notes,
        // Reuses the reservation item shape (dishId, dishName, quantity,
        // unitPrice, additions) so the kitchen consumes a consistent payload.
        'items': items.map((i) => i.toJson()).toList(),
      };
}
