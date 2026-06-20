import 'package:flutter/material.dart';

/// Visual identity for a menu category chip (icon + accent color).
class MenuCategoryVisual {
  final IconData icon;
  final Color accent;

  const MenuCategoryVisual({required this.icon, required this.accent});

  static MenuCategoryVisual forName(String name) {
    final key = name.toLowerCase().trim();

    if (_matches(key, ['carne', 'carnes', 'meat', 'meats', 'grill'])) {
      return const MenuCategoryVisual(
        icon: Icons.kebab_dining_rounded,
        accent: Color(0xFFE53935),
      );
    }
    if (_matches(key, ['sopa', 'sopas', 'soup', 'soups', 'caldo'])) {
      return const MenuCategoryVisual(
        icon: Icons.ramen_dining_rounded,
        accent: Color(0xFFFF8F00),
      );
    }
    if (_matches(key, ['pasta', 'pastas', 'fideo', 'fideos'])) {
      return const MenuCategoryVisual(
        icon: Icons.dinner_dining_rounded,
        accent: Color(0xFFFFB300),
      );
    }
    if (_matches(key, ['bebida', 'bebidas', 'drink', 'drinks', 'bar'])) {
      return const MenuCategoryVisual(
        icon: Icons.local_bar_rounded,
        accent: Color(0xFF1E88E5),
      );
    }
    if (_matches(key, ['postre', 'postres', 'dessert', 'desserts', 'dulce'])) {
      return const MenuCategoryVisual(
        icon: Icons.cake_rounded,
        accent: Color(0xFFEC407A),
      );
    }
    if (_matches(key, ['ensalada', 'ensaladas', 'salad', 'salads', 'verde'])) {
      return const MenuCategoryVisual(
        icon: Icons.eco_rounded,
        accent: Color(0xFF43A047),
      );
    }
    if (_matches(key, ['marisco', 'mariscos', 'pescado', 'seafood', 'fish'])) {
      return const MenuCategoryVisual(
        icon: Icons.set_meal_rounded,
        accent: Color(0xFF00838F),
      );
    }
    if (_matches(key, ['entrada', 'entradas', 'appetizer', 'starter'])) {
      return const MenuCategoryVisual(
        icon: Icons.tapas_rounded,
        accent: Color(0xFF8E24AA),
      );
    }

    return const MenuCategoryVisual(
      icon: Icons.restaurant_menu_rounded,
      accent: Color(0xFF6D4C41),
    );
  }

  static bool _matches(String key, List<String> tokens) =>
      tokens.any((t) => key.contains(t));
}
