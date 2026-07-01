class WaiterRestaurant {
  final String id;
  final String name;

  const WaiterRestaurant({
    required this.id,
    required this.name,
  });

  factory WaiterRestaurant.fromJson(Map<String, dynamic> json) {
    return WaiterRestaurant(
      id: (json['id'] ?? json['restaurantId'] ?? json['RestaurantId'])
          .toString(),
      name: (json['name'] ?? json['restaurantName'] ?? json['RestaurantName'])
              as String? ??
          '',
    );
  }

  static List<WaiterRestaurant> listFromJson(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(WaiterRestaurant.fromJson)
        .where((r) => r.id.isNotEmpty)
        .toList();
  }
}
