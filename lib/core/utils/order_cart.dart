import 'package:restaurantwaiter/domain/models/category_menu.dart';
import 'package:restaurantwaiter/domain/models/dish.dart';
import 'package:restaurantwaiter/domain/models/reservation_item.dart';

class OrderCart {
  OrderCart._();

  static Map<String, ReservationItem> fromItems(List<ReservationItem> items) {
    final cart = <String, ReservationItem>{};
    for (final item in items) {
      if (item.quantity <= 0) continue;
      final key = item.dishId.isNotEmpty ? item.dishId : item.dishName;
      final existing = cart[key];
      if (existing != null) {
        cart[key] = ReservationItem(
          dishId: item.dishId.isNotEmpty ? item.dishId : existing.dishId,
          dishName: item.dishName,
          quantity: existing.quantity + item.quantity,
          unitPrice: item.unitPrice,
          additions: item.additions,
        );
      } else {
        cart[key] = ReservationItem(
          dishId: item.dishId,
          dishName: item.dishName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          additions: item.additions,
        );
      }
    }
    return cart;
  }

  static Map<String, ReservationItem> reconcileWithMenu(
    Map<String, ReservationItem> cart,
    List<CategoryMenu> categories,
  ) {
    final dishes = categories.expand((c) => c.dishes).toList();
    final byId = {
      for (final d in dishes) _normalizeKey(d.id): d,
    };
    final byName = {
      for (final d in dishes) _normalizeKey(d.name): d,
    };

    final reconciled = <String, ReservationItem>{};
    for (final item in cart.values) {
      if (item.quantity <= 0) continue;

      final dish = byId[_normalizeKey(item.dishId)] ??
          byName[_normalizeKey(item.dishName)];

      if (dish != null) {
        final existing = reconciled[dish.id];
        reconciled[dish.id] = ReservationItem(
          dishId: dish.id,
          dishName: dish.name,
          quantity: (existing?.quantity ?? 0) + item.quantity,
          unitPrice: dish.price,
          additions: item.additions,
        );
      } else {
        final key =
            item.dishId.isNotEmpty ? item.dishId : item.dishName.trim();
        if (key.isEmpty) continue;
        final existing = reconciled[key];
        reconciled[key] = ReservationItem(
          dishId: item.dishId,
          dishName: item.dishName,
          quantity: (existing?.quantity ?? 0) + item.quantity,
          unitPrice: item.unitPrice,
          additions: item.additions,
        );
      }
    }
    return reconciled;
  }

  static String? keyForDish(Map<String, ReservationItem> cart, Dish dish) {
    if (cart.containsKey(dish.id)) return dish.id;

    final normalizedId = _normalizeKey(dish.id);
    for (final key in cart.keys) {
      if (_normalizeKey(key) == normalizedId) return key;
    }

    final normalizedName = _normalizeKey(dish.name);
    for (final entry in cart.entries) {
      if (_normalizeKey(entry.value.dishName) == normalizedName) {
        return entry.key;
      }
    }
    return null;
  }

  static int quantityForDish(Map<String, ReservationItem> cart, Dish dish) {
    final key = keyForDish(cart, dish);
    if (key == null) return 0;
    return cart[key]?.quantity ?? 0;
  }

  static Map<String, ReservationItem> addDish(
    Map<String, ReservationItem> cart,
    Dish dish,
  ) {
    final updated = Map<String, ReservationItem>.from(cart);
    final key = keyForDish(updated, dish);
    if (key != null) {
      final existing = updated.remove(key)!;
      updated[dish.id] = ReservationItem(
        dishId: dish.id,
        dishName: dish.name,
        quantity: existing.quantity + 1,
        unitPrice: dish.price,
        additions: existing.additions,
      );
    } else {
      updated[dish.id] = ReservationItem(
        dishId: dish.id,
        dishName: dish.name,
        quantity: 1,
        unitPrice: dish.price,
      );
    }
    return updated;
  }

  static Map<String, ReservationItem> removeDish(
    Map<String, ReservationItem> cart,
    Dish dish,
  ) {
    final updated = Map<String, ReservationItem>.from(cart);
    final key = keyForDish(updated, dish);
    if (key == null) return updated;

    final existing = updated[key]!;
    if (existing.quantity <= 1) {
      updated.remove(key);
    } else {
      updated[key] = ReservationItem(
        dishId: existing.dishId.isNotEmpty ? existing.dishId : dish.id,
        dishName: existing.dishName,
        quantity: existing.quantity - 1,
        unitPrice: existing.unitPrice,
        additions: existing.additions,
      );
    }
    return updated;
  }

  static bool hasSameQuantities(
    Map<String, ReservationItem> left,
    Map<String, ReservationItem> right,
  ) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      final other = right[entry.key];
      if (other == null || other.quantity != entry.value.quantity) {
        return false;
      }
    }
    return true;
  }

  static String _normalizeKey(String value) => value.toLowerCase().trim();
}
