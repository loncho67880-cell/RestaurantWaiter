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
        dishId: json['dishId'] as String,
        dishName: json['dishName'] as String,
        quantity: json['quantity'] as int,
        unitPrice: (json['unitPrice'] as num).toDouble(),
        additions: json['additions'] as String? ?? '',
      );

  double get subtotal => unitPrice * quantity;
}
