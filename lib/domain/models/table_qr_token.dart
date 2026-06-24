class TableQrToken {
  final String restaurantId;
  final String branchId;
  final String tableId;
  final int tableNumber;
  final int floor;
  final String qrToken;

  const TableQrToken({
    required this.restaurantId,
    required this.branchId,
    required this.tableId,
    required this.tableNumber,
    required this.floor,
    required this.qrToken,
  });

  factory TableQrToken.fromJson(Map<String, dynamic> json) => TableQrToken(
        restaurantId: (json['restaurantId'] ?? json['RestaurantId']).toString(),
        branchId: (json['branchId'] ?? json['BranchId']).toString(),
        tableId: (json['tableId'] ?? json['TableId']).toString(),
        tableNumber:
            ((json['tableNumber'] ?? json['TableNumber']) as num?)?.toInt() ??
                0,
        floor: ((json['floor'] ?? json['Floor']) as num?)?.toInt() ?? 1,
        qrToken: (json['qrToken'] ?? json['QrToken']).toString(),
      );
}
