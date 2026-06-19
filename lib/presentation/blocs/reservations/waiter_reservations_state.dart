import 'package:equatable/equatable.dart';
import 'package:restaurantwaiter/domain/models/reservation.dart';

enum WaiterReservationsStatus { loading, loaded, error }

class WaiterReservationsState extends Equatable {
  final WaiterReservationsStatus status;
  final List<Reservation> reservations;
  final String? confirmingId;
  final String? errorKey;

  const WaiterReservationsState({
    this.status = WaiterReservationsStatus.loading,
    this.reservations = const [],
    this.confirmingId,
    this.errorKey,
  });

  WaiterReservationsState copyWith({
    WaiterReservationsStatus? status,
    List<Reservation>? reservations,
    String? confirmingId,
    String? errorKey,
  }) {
    return WaiterReservationsState(
      status: status ?? this.status,
      reservations: reservations ?? this.reservations,
      confirmingId: confirmingId,
      errorKey: errorKey,
    );
  }

  @override
  List<Object?> get props => [status, reservations, confirmingId, errorKey];
}
