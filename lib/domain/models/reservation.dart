import 'package:restaurantwaiter/core/utils/reservation_datetime.dart';

import 'reservation_item.dart';

enum ReservationStatus { pending, confirmed, cancelled }

enum PreOrderStatus {
  none,
  pendingWaiterConfirmation,
  inPreparation,
}

class Reservation {
  final String id;
  final String branchId;
  final String tableId;
  final int tableNumber;
  final int floor;
  final DateTime reservationDate;
  final int guestCount;
  final ReservationStatus status;
  final PreOrderStatus preOrderStatus;
  final String? notes;
  final List<ReservationItem> items;

  const Reservation({
    required this.id,
    required this.branchId,
    required this.tableId,
    required this.tableNumber,
    required this.floor,
    required this.reservationDate,
    required this.guestCount,
    required this.status,
    this.preOrderStatus = PreOrderStatus.none,
    this.notes,
    required this.items,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
        id: json['id'] as String,
        branchId: json['branchId'] as String? ?? '',
        tableId: json['tableId'] as String,
        tableNumber: json['tableNumber'] as int,
        floor: json['floor'] as int,
        reservationDate:
            parseApiReservationDate(json['reservationDate'] as String),
        guestCount: json['guestCount'] as int,
        status: _parseStatus(json['status'] as String?),
        preOrderStatus: _parsePreOrderStatus(json['preOrderStatus'] as String?),
        notes: json['notes'] as String?,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => ReservationItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static ReservationStatus _parseStatus(String? s) => switch (s) {
        'Confirmada' => ReservationStatus.confirmed,
        'Cancelada' => ReservationStatus.cancelled,
        _ => ReservationStatus.pending,
      };

  static PreOrderStatus _parsePreOrderStatus(String? s) => switch (s) {
        'PendienteConfirmacionMesero' => PreOrderStatus.pendingWaiterConfirmation,
        'ConfirmadoMesero' || 'EnCocina' || 'EnPreparacion' =>
          PreOrderStatus.inPreparation,
        _ => PreOrderStatus.none,
      };

  double get totalPreOrder =>
      items.fold(0.0, (sum, item) => sum + item.subtotal);

  bool get isCancelled => status == ReservationStatus.cancelled;

  bool get isUpcoming => reservationDate.isAfter(DateTime.now());

  bool get isAwaitingWaiter =>
      preOrderStatus == PreOrderStatus.pendingWaiterConfirmation;

  bool get isInPreparation => preOrderStatus == PreOrderStatus.inPreparation;

  /// A reservation the waiter can still send to the kitchen: it must have
  /// pre-ordered items and not be cancelled nor already in preparation.
  bool get canWaiterConfirm =>
      !isCancelled && items.isNotEmpty && !isInPreparation;
}
