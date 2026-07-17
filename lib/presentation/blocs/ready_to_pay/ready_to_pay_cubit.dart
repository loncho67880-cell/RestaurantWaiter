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

  void _emitState(ReadyToPayState newState) {
    if (!isClosed) emit(newState);
  }

  Future<void> load() async {
    if (isClosed) return;
    _emitState(state.copyWith(status: ReadyToPayStatus.loading));
    try {
      final reservations = await orderRepository.getReadyForPayment(
        branchId: branchId,
        accessToken: accessToken,
      );
      if (isClosed) return;
      _emitState(state.copyWith(
        status: ReadyToPayStatus.loaded,
        reservations: reservations,
      ));
    } catch (e, stack) {
      if (isClosed) return;
      debugPrint('[ReadyToPay] load failed: $e\n$stack');
      _emitState(state.copyWith(
        status: ReadyToPayStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> markAsPaid(String reservationId) async {
    if (isClosed) return 'readyToPayMarkError';
    _emitState(state.copyWith(markingPaidId: reservationId));
    try {
      await orderRepository.markAsPaidByWaiter(
        reservationId: reservationId,
        accessToken: accessToken,
      );
      if (isClosed) return 'readyToPayMarkError';
      final updated = state.reservations
          .where((r) => r.id != reservationId)
          .toList();
      _emitState(state.copyWith(
        reservations: updated,
        clearMarkingPaidId: true,
        status: ReadyToPayStatus.loaded,
      ));
      return null;
    } catch (e) {
      _emitState(state.copyWith(clearMarkingPaidId: true));
      return 'readyToPayMarkError';
    }
  }
}
