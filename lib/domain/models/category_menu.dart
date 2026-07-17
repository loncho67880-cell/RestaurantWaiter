import 'package:equatable/equatable.dart';
import 'dish.dart';

class CategoryMenu extends Equatable {
  final String id;
  final String name;
  final int order;
  final List<Dish> dishes;
  final String imageUrl;

  const CategoryMenu({
    required this.id,
    required this.name,
    required this.order,
    required this.dishes,
    this.imageUrl = '',
  });

  factory CategoryMenu.fromJson(Map<String, dynamic> json) {
    return CategoryMenu(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      order: json['order'] is int
          ? json['order'] as int
          : int.tryParse(json['order']?.toString() ?? '') ?? 0,
      dishes: (json['dishes'] as List)
          .map((dishJson) => Dish.fromJson(dishJson))
          .toList(),
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, name, order, dishes, imageUrl];
}
