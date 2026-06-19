class TableModel {
  final String tableId;
  final int tableNumber;
  final int floor;
  final int capacity;
  final bool isAvailable;

  const TableModel({
    required this.tableId,
    required this.tableNumber,
    required this.floor,
    required this.capacity,
    required this.isAvailable,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) => TableModel(
        tableId: json['tableId'] as String,
        tableNumber: json['tableNumber'] as int,
        floor: json['floor'] as int,
        capacity: json['capacity'] as int,
        isAvailable: json['isAvailable'] as bool? ?? true,
      );
}
