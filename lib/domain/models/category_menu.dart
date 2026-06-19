import 'package:equatable/equatable.dart';
import 'dish.dart';

class CategoryMenu extends Equatable {
  final String id;
  final String name;
  final int order;
  final List<Dish> dishes;

  const CategoryMenu({
    required this.id,
    required this.name,
    required this.order,
    required this.dishes,
  });

  factory CategoryMenu.fromJson(Map<String, dynamic> json) {
    return CategoryMenu(
      id: json['id'],
      name: json['name'],
      order: json['order'],
      dishes: (json['dishes'] as List)
          .map((dishJson) => Dish.fromJson(dishJson))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [id, name, order, dishes];
}
