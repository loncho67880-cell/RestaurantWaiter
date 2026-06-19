import '../models/reservation.dart';

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
}
