import 'package:equatable/equatable.dart';
import 'package:restaurantwaiter/domain/models/reservation.dart';

enum ReadyToPayStatus { loading, loaded, error }

class ReadyToPayState extends Equatable {
  final ReadyToPayStatus status;
  final List<Reservation> reservations;
  final String? markingPaidId;
  final String? errorMessage;

  const ReadyToPayState({
    this.status = ReadyToPayStatus.loading,
    this.reservations = const [],
    this.markingPaidId,
    this.errorMessage,
  });

  ReadyToPayState copyWith({
    ReadyToPayStatus? status,
    List<Reservation>? reservations,
    String? markingPaidId,
    bool clearMarkingPaidId = false,
    String? errorMessage,
  }) {
    return ReadyToPayState(
      status: status ?? this.status,
      reservations: reservations ?? this.reservations,
      markingPaidId: clearMarkingPaidId ? null : (markingPaidId ?? this.markingPaidId),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, reservations, markingPaidId, errorMessage];
}
