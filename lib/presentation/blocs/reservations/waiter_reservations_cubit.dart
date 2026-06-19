import 'package:flutter_bloc/flutter_bloc.dart';
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
      errorKey: null,
    ));
    try {
      final reservations =
          await reservationRepository.getActiveReservations(
        branchId: branchId,
        accessToken: accessToken,
      )
            ..sort((a, b) => a.reservationDate.compareTo(b.reservationDate));

      emit(state.copyWith(
        status: WaiterReservationsStatus.loaded,
        reservations: reservations,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: WaiterReservationsStatus.error,
        errorKey: 'waiterReservationsLoadError',
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

      emit(state.copyWith(
        reservations: updatedList,
        confirmingId: null,
      ));
      return null;
    } catch (_) {
      emit(state.copyWith(confirmingId: null));
      return 'waiterConfirmError';
    }
  }
}
