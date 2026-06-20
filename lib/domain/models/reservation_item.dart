class ReservationItem {
  final String dishId;
  final String dishName;
  int quantity;
  final double unitPrice;
  final String additions;

  ReservationItem({
    required this.dishId,
    required this.dishName,
    required this.quantity,
    required this.unitPrice,
    this.additions = '',
  });

  Map<String, dynamic> toJson() => {
        'dishId': dishId,
        'dishName': dishName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'additions': additions,
      };

  factory ReservationItem.fromJson(Map<String, dynamic> json) => ReservationItem(
        dishId: (json['dishId'] ?? json['DishId'])?.toString() ?? '',
        dishName: (json['dishName'] ?? json['DishName']) as String? ?? '',
        quantity: _readQuantity(json['quantity'] ?? json['Quantity']),
        unitPrice:
            ((json['unitPrice'] ?? json['UnitPrice']) as num?)?.toDouble() ?? 0,
        additions: (json['additions'] ?? json['Additions']) as String? ?? '',
      );

  static int _readQuantity(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double get subtotal => unitPrice * quantity;
}
