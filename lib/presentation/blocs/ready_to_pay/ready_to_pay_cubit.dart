import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/domain/repositories/order_repository.dart';

import 'ready_to_pay_state.dart';

class ReadyToPayCubit extends Cubit<ReadyToPayState> {
  final OrderRepository orderRepository;
  final String branchId;
  final String accessToken;

  ReadyToPayCubit({
    required this.orderRepository,
    required this.branchId,
    required this.accessToken,
  }) : super(const ReadyToPayState());

  Future<void> load() async {
    emit(state.copyWith(status: ReadyToPayStatus.loading));
    try {
      final reservations = await orderRepository.getReadyForPayment(
        branchId: branchId,
        accessToken: accessToken,
      );
      emit(state.copyWith(status: ReadyToPayStatus.loaded, reservations: reservations));
    } catch (e, stack) {
      debugPrint('[ReadyToPay] load failed: $e\n$stack');
      emit(state.copyWith(
        status: ReadyToPayStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> markAsPaid(String reservationId) async {
    emit(state.copyWith(markingPaidId: reservationId));
    try {
      await orderRepository.markAsPaidByWaiter(
        reservationId: reservationId,
        accessToken: accessToken,
      );
      final updated = state.reservations
          .where((r) => r.id != reservationId)
          .toList();
      emit(state.copyWith(
        reservations: updated,
        clearMarkingPaidId: true,
        status: ReadyToPayStatus.loaded,
      ));
      return null;
    } catch (e) {
      emit(state.copyWith(clearMarkingPaidId: true));
      return 'readyToPayMarkError';
    }
  }
}
