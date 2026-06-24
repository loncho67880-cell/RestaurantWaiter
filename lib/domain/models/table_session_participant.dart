import 'reservation_item.dart';

class TableSessionParticipant {
  final String customerId;
  final String customerName;
  final String status;
  final List<ReservationItem> items;

  const TableSessionParticipant({
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.items,
  });

  factory TableSessionParticipant.fromJson(Map<String, dynamic> json) {
    final customerId =
        (json['customerId'] ?? json['CustomerId'])?.toString() ?? '';
    final customerName =
        (json['customerName'] ?? json['CustomerName'])?.toString() ?? '';
    final rawItems = json['items'] ?? json['Items'];

    return TableSessionParticipant(
      customerId: customerId,
      customerName: customerName,
      status: (json['status'] ?? json['Status'])?.toString() ?? 'LeyendoQR',
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => ReservationItem.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : const [],
    );
  }

  bool get isOrderConfirmed => status == 'PedidoConfirmado';

  String get displayName {
    final trimmed = customerName.trim();
    if (trimmed.isEmpty) return customerName;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
}
