import '../models/reservation.dart';
import '../models/reservation_item.dart';

abstract class ReservationRepository {
  /// Active reservations for a branch (used by the waiter home).
  Future<List<Reservation>> getActiveReservations({
    required String branchId,
    required String accessToken,
  });

  /// Confirms a reservation's pre-order at the table, moving its
  /// [PreOrderStatus] to `EnPreparacion` so the order goes to the kitchen.
  Future<Reservation> confirmByWaiter({
    required String reservationId,
    required String accessToken,
  });

  /// Marks that the customer is at the table when they did not confirm in the app.
  Future<Reservation> confirmAtTableByWaiter({
    required String reservationId,
    required String accessToken,
  });

  /// Marks an in-preparation reservation as ready for payment; it leaves the
  /// active waiter list on the backend.
  Future<void> markReadyForPayment({
    required String reservationId,
    required String accessToken,
  });

  /// Replaces pre-order items while the reservation awaits waiter confirmation.
  Future<Reservation> updateItemsByWaiter({
    required String reservationId,
    required List<ReservationItem> items,
    required String accessToken,
  });

  /// Cancels a reservation on behalf of the waiter (before kitchen).
  Future<Reservation> cancelByWaiter({
    required String reservationId,
    required String accessToken,
  });
}
