import 'package:equatable/equatable.dart';
import 'package:restaurantwaiter/domain/models/reservation.dart';

enum WaiterReservationsStatus { loading, loaded, error }

class WaiterReservationsState extends Equatable {
  final WaiterReservationsStatus status;
  final List<Reservation> reservations;
  final String? confirmingId;
  final String? markingReadyId;
  final String? errorKey;
  final String? errorMessage;

  const WaiterReservationsState({
    this.status = WaiterReservationsStatus.loading,
    this.reservations = const [],
    this.confirmingId,
    this.markingReadyId,
    this.errorKey,
    this.errorMessage,
  });

  WaiterReservationsState copyWith({
    WaiterReservationsStatus? status,
    List<Reservation>? reservations,
    String? confirmingId,
    String? markingReadyId,
    String? errorKey,
    String? errorMessage,
    bool clearConfirmingId = false,
    bool clearMarkingReadyId = false,
    bool clearErrors = false,
  }) {
    return WaiterReservationsState(
      status: status ?? this.status,
      reservations: reservations ?? this.reservations,
      confirmingId:
          clearConfirmingId ? null : (confirmingId ?? this.confirmingId),
      markingReadyId:
          clearMarkingReadyId ? null : (markingReadyId ?? this.markingReadyId),
      errorKey: clearErrors ? null : (errorKey ?? this.errorKey),
      errorMessage: clearErrors ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, reservations, confirmingId, markingReadyId, errorKey, errorMessage];
}
