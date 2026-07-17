import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/domain/models/reservation.dart';
import 'package:restaurantwaiter/domain/repositories/reservation_repository.dart';

import 'waiter_reservations_state.dart';

class WaiterReservationsCubit extends Cubit<WaiterReservationsState> {
  final ReservationRepository reservationRepository;
  final String branchId;
  final String accessToken;

  WaiterReservationsCubit({
    required this.reservationRepository,
    required this.branchId,
    required this.accessToken,
  }) : super(const WaiterReservationsState());

  void _emitState(WaiterReservationsState newState) {
    if (!isClosed) emit(newState);
  }

  Future<void> load() async {
    if (isClosed) return;
    _emitState(state.copyWith(
      status: WaiterReservationsStatus.loading,
      clearErrors: true,
    ));
    try {
      final reservations =
          await reservationRepository.getActiveReservations(
        branchId: branchId,
        accessToken: accessToken,
      );
      if (isClosed) return;
      _sortReservations(reservations);

      _emitState(state.copyWith(
        status: WaiterReservationsStatus.loaded,
        reservations: reservations,
      ));
    } catch (e, stack) {
      if (isClosed) return;
      debugPrint('ERROR loading reservations: $e');
      debugPrint('$stack');
      _emitState(state.copyWith(
        status: WaiterReservationsStatus.error,
        errorKey: 'waiterReservationsLoadError',
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  /// Returns null on success, or an error i18n key on failure.
  Future<String?> confirmArrival(String reservationId) async {
    if (isClosed) return 'waiterConfirmArrivalError';
    _emitState(state.copyWith(confirmingId: reservationId));
    try {
      final updated = await reservationRepository.confirmAtTableByWaiter(
        reservationId: reservationId,
        accessToken: accessToken,
      );
      if (isClosed) return 'waiterConfirmArrivalError';

      final updatedList = state.reservations
          .map((r) => r.id == updated.id ? updated : r)
          .toList();
      _sortReservations(updatedList);

      _emitState(state.copyWith(
        reservations: updatedList,
        clearConfirmingId: true,
      ));
      return null;
    } catch (_) {
      _emitState(state.copyWith(clearConfirmingId: true));
      return 'waiterConfirmArrivalError';
    }
  }

  /// Returns null on success, or an error i18n key on failure.
  Future<String?> confirm(String reservationId) async {
    if (isClosed) return 'waiterConfirmError';
    _emitState(state.copyWith(confirmingId: reservationId));
    try {
      final updated = await reservationRepository.confirmByWaiter(
        reservationId: reservationId,
        accessToken: accessToken,
      );
      if (isClosed) return 'waiterConfirmError';

      final updatedList = state.reservations
          .map((r) => r.id == updated.id ? updated : r)
          .toList();
      _sortReservations(updatedList);

      _emitState(state.copyWith(
        reservations: updatedList,
        clearConfirmingId: true,
      ));
      return null;
    } catch (_) {
      _emitState(state.copyWith(clearConfirmingId: true));
      return 'waiterConfirmError';
    }
  }

  Future<String?> markReadyForPayment(String reservationId) async {
    if (isClosed) return 'waiterMarkReadyError';
    _emitState(state.copyWith(markingReadyId: reservationId));
    try {
      await reservationRepository.markReadyForPayment(
        reservationId: reservationId,
        accessToken: accessToken,
      );
      if (isClosed) return 'waiterMarkReadyError';

      final updatedList = state.reservations
          .where((r) => r.id != reservationId)
          .toList();

      _emitState(state.copyWith(
        reservations: updatedList,
        clearMarkingReadyId: true,
      ));
      return null;
    } catch (_) {
      _emitState(state.copyWith(clearMarkingReadyId: true));
      return 'waiterMarkReadyError';
    }
  }

  void replaceReservation(Reservation updated) {
    if (isClosed) return;
    final updatedList = state.reservations
        .map((r) => r.id == updated.id ? updated : r)
        .toList();
    _sortReservations(updatedList);
    _emitState(state.copyWith(reservations: updatedList));
  }

  void removeReservation(String reservationId) {
    if (isClosed) return;
    _emitState(state.copyWith(
      reservations:
          state.reservations.where((r) => r.id != reservationId).toList(),
    ));
  }

  Future<String?> cancel(String reservationId) async {
    try {
      await reservationRepository.cancelByWaiter(
        reservationId: reservationId,
        accessToken: accessToken,
      );
      if (isClosed) return 'cancelReservationError';
      removeReservation(reservationId);
      return null;
    } catch (_) {
      return 'cancelReservationError';
    }
  }

  /// Pending waiter confirmation first, then in preparation, then by time.
  void _sortReservations(List<Reservation> reservations) {
    reservations.sort((a, b) {
      int priority(Reservation r) {
        if (r.isReadingQr) return 0;
        if (r.isAwaitingWaiter) return 1;
        if (r.canWaiterConfirmArrival) return 2;
        if (r.isInPreparation) return 3;
        return 4;
      }

      final priorityCompare = priority(a).compareTo(priority(b));
      if (priorityCompare != 0) return priorityCompare;
      return a.reservationDate.compareTo(b.reservationDate);
    });
  }
}
