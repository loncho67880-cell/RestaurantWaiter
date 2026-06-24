import 'package:restaurantwaiter/core/utils/reservation_datetime.dart';

import 'table_session_participant.dart';

import 'reservation_item.dart';

enum ReservationStatus { pending, confirmed, cancelled }

enum PreOrderStatus {
  none,
  readingQr,
  pendingWaiterConfirmation,
  inPreparation,
  readyForPayment,
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
  final String? customerName;
  final String? customerPhone;
  final List<ReservationItem> items;
  final List<TableSessionParticipant> participants;
  final bool allParticipantsConfirmed;
  final bool canFinalizeTable;

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
    this.customerName,
    this.customerPhone,
    required this.items,
    this.participants = const [],
    this.allParticipantsConfirmed = false,
    this.canFinalizeTable = false,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
        id: _readString(json['id']),
        branchId: _readString(json['branchId']),
        tableId: _readString(json['tableId']),
        tableNumber: _readInt(json['tableNumber'] ?? _tableField(json, 'number')),
        floor: _readInt(json['floor'] ?? _tableField(json, 'floor')),
        reservationDate: parseApiReservationDate(
          _readString(json['reservationDate']),
        ),
        guestCount: _readInt(json['guestCount']),
        status: _parseStatus(json['status'] as String?),
        preOrderStatus: _parsePreOrderStatus(json['preOrderStatus'] as String?),
        notes: json['notes'] as String?,
        customerName: json['customerName'] as String? ??
            json['CustomerName'] as String?,
        customerPhone: json['customerPhone'] as String? ??
            json['CustomerPhone'] as String?,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => ReservationItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        participants: _parseParticipants(json),
        allParticipantsConfirmed:
            json['allParticipantsConfirmed'] == true ||
                json['AllParticipantsConfirmed'] == true,
        canFinalizeTable:
            json['canFinalizeTable'] == true ||
                json['CanFinalizeTable'] == true,
      );

  static List<TableSessionParticipant> _parseParticipants(
    Map<String, dynamic> json,
  ) {
    final raw = json['participants'] ?? json['Participants'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => TableSessionParticipant.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .toList();
  }

  static String _readString(dynamic value) => value?.toString() ?? '';

  static int _readInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static dynamic _tableField(Map<String, dynamic> json, String field) {
    final table = json['table'];
    if (table is Map<String, dynamic>) return table[field];
    return null;
  }

  static ReservationStatus _parseStatus(String? s) => switch (s) {
        'Confirmada' => ReservationStatus.confirmed,
        'Cancelada' => ReservationStatus.cancelled,
        _ => ReservationStatus.pending,
      };

  static PreOrderStatus _parsePreOrderStatus(String? s) => switch (s) {
        'LeyendoQR' => PreOrderStatus.readingQr,
        'PendienteConfirmacionMesero' => PreOrderStatus.pendingWaiterConfirmation,
        'ConfirmadoMesero' || 'EnCocina' || 'EnPreparacion' =>
          PreOrderStatus.inPreparation,
        'ListoParaPagar' => PreOrderStatus.readyForPayment,
        _ => PreOrderStatus.none,
      };

  double get totalPreOrder =>
      items.fold(0.0, (sum, item) => sum + item.subtotal);

  bool get isCancelled => status == ReservationStatus.cancelled;

  bool get isUpcoming => reservationDate.isAfter(DateTime.now());

  bool get isReadingQr => preOrderStatus == PreOrderStatus.readingQr;

  bool get isAwaitingWaiter =>
      preOrderStatus == PreOrderStatus.pendingWaiterConfirmation;

  bool get isInPreparation => preOrderStatus == PreOrderStatus.inPreparation;

  bool get isReadyForPayment => preOrderStatus == PreOrderStatus.readyForPayment;

  bool get canMarkReadyForPayment => !isCancelled && isInPreparation;

  bool get hasTableSessionParticipants => participants.isNotEmpty;

  /// Waiter can adjust the pre-order while QR session is active or awaiting confirmation.
  bool get canWaiterEditOrder =>
      !isCancelled &&
      (isReadingQr || isAwaitingWaiter || preOrderStatus == PreOrderStatus.none);

  /// Waiter can mark that the customer is at the table (without the app).
  bool get canWaiterConfirmArrival =>
      !isCancelled && preOrderStatus == PreOrderStatus.none;

  /// A reservation the waiter can still send to the kitchen.
  bool get canWaiterConfirm =>
      !isCancelled &&
      (isAwaitingWaiter || isReadingQr || preOrderStatus == PreOrderStatus.none) &&
      items.isNotEmpty;

  /// Waiter may cancel before the order is sent to the kitchen.
  bool get canWaiterCancel =>
      !isCancelled && !isInPreparation && !isReadyForPayment;

  bool get hasCustomerContact =>
      customerName != null && customerName!.trim().isNotEmpty;

  Reservation copyWith({
    ReservationStatus? status,
    PreOrderStatus? preOrderStatus,
    List<ReservationItem>? items,
    String? customerName,
    String? customerPhone,
  }) =>
      Reservation(
        id: id,
        branchId: branchId,
        tableId: tableId,
        tableNumber: tableNumber,
        floor: floor,
        reservationDate: reservationDate,
        guestCount: guestCount,
        status: status ?? this.status,
        preOrderStatus: preOrderStatus ?? this.preOrderStatus,
        notes: notes,
        customerName: customerName ?? this.customerName,
        customerPhone: customerPhone ?? this.customerPhone,
        items: items ?? this.items,
      );
}
