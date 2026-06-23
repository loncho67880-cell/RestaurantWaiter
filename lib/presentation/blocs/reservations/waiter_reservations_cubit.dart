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

  Future<void> load() async {
    emit(state.copyWith(
      status: WaiterReservationsStatus.loading,
      clearErrors: true,
    ));
    try {
      final reservations =
          await reservationRepository.getActiveReservations(
        branchId: branchId,
        accessToken: accessToken,
      );
      _sortReservations(reservations);

      emit(state.copyWith(
        status: WaiterReservationsStatus.loaded,
        reservations: reservations,
      ));
    } catch (e, stack) {
      debugPrint('ERROR loading reservations: $e');
      debugPrint('$stack');
      emit(state.copyWith(
        status: WaiterReservationsStatus.error,
        errorKey: 'waiterReservationsLoadError',
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  /// Returns null on success, or an error i18n key on failure.
  Future<String?> confirm(String reservationId) async {
    emit(state.copyWith(confirmingId: reservationId));
    try {
      final updated = await reservationRepository.confirmByWaiter(
        reservationId: reservationId,
        accessToken: accessToken,
      );

      final updatedList = state.reservations
          .map((r) => r.id == updated.id ? updated : r)
          .toList();
      _sortReservations(updatedList);

      emit(state.copyWith(
        reservations: updatedList,
        clearConfirmingId: true,
      ));
      return null;
    } catch (_) {
      emit(state.copyWith(clearConfirmingId: true));
      return 'waiterConfirmError';
    }
  }

  Future<String?> markReadyForPayment(String reservationId) async {
    emit(state.copyWith(markingReadyId: reservationId));
    try {
      await reservationRepository.markReadyForPayment(
        reservationId: reservationId,
        accessToken: accessToken,
      );

      final updatedList = state.reservations
          .where((r) => r.id != reservationId)
          .toList();

      emit(state.copyWith(
        reservations: updatedList,
        clearMarkingReadyId: true,
      ));
      return null;
    } catch (_) {
      emit(state.copyWith(clearMarkingReadyId: true));
      return 'waiterMarkReadyError';
    }
  }

  void replaceReservation(Reservation updated) {
    final updatedList = state.reservations
        .map((r) => r.id == updated.id ? updated : r)
        .toList();
    _sortReservations(updatedList);
    emit(state.copyWith(reservations: updatedList));
  }

  void removeReservation(String reservationId) {
    emit(state.copyWith(
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
        if (r.isAwaitingWaiter) return 0;
        if (r.isInPreparation) return 1;
        return 2;
      }

      final priorityCompare = priority(a).compareTo(priority(b));
      if (priorityCompare != 0) return priorityCompare;
      return a.reservationDate.compareTo(b.reservationDate);
    });
  }
}
