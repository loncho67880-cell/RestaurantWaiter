import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:restaurantwaiter/domain/models/category_menu.dart';
import 'package:restaurantwaiter/domain/models/dish.dart';
import 'package:restaurantwaiter/domain/models/reservation.dart';
import 'package:restaurantwaiter/domain/models/reservation_item.dart';
import 'package:restaurantwaiter/domain/repositories/reservation_repository.dart';
import 'package:restaurantwaiter/infrastructure/repositories/menu_repository.dart';

import 'edit_reservation_order_state.dart';

class EditReservationOrderCubit extends Cubit<EditReservationOrderState> {
  final MenuRepository menuRepository;
  final ReservationRepository reservationRepository;
  final Reservation reservation;
  final String restaurantId;
  final String branchId;
  final String accessToken;
  final String localeCode;

  EditReservationOrderCubit({
    required this.menuRepository,
    required this.reservationRepository,
    required this.reservation,
    required this.restaurantId,
    required this.branchId,
    required this.accessToken,
    required this.localeCode,
  }) : super(EditReservationOrderState(
          cart: _initialCart(reservation.items),
        ));

  static Map<String, ReservationItem> _initialCart(
    List<ReservationItem> items,
  ) {
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

  Future<void> loadMenu() async {
    emit(state.copyWith(status: EditReservationOrderStatus.loading));
    try {
      final categories = await menuRepository.loadCategories(
        localeCode,
        restaurantId,
        branchId,
        accessToken,
      );

      if (categories.isEmpty) {
        emit(state.copyWith(status: EditReservationOrderStatus.error));
        return;
      }

      final reconciledCart = _reconcileCartWithMenu(state.cart, categories);

      emit(state.copyWith(
        status: EditReservationOrderStatus.loaded,
        categories: categories,
        selectedCategoryId: categories.first.id.toString(),
        cart: reconciledCart,
      ));
    } catch (e, stack) {
      debugPrint('EditReservationOrder loadMenu failed: $e\n$stack');
      emit(state.copyWith(status: EditReservationOrderStatus.error));
    }
  }

  void selectCategory(String categoryId) {
    emit(state.copyWith(selectedCategoryId: categoryId));
  }

  void addDish(Dish dish) {
    final cart = Map<String, ReservationItem>.from(state.cart);
    final key = _cartKeyForDish(cart, dish);
    if (key != null) {
      final existing = cart.remove(key)!;
      cart[dish.id] = ReservationItem(
        dishId: dish.id,
        dishName: dish.name,
        quantity: existing.quantity + 1,
        unitPrice: dish.price,
        additions: existing.additions,
      );
    } else {
      cart[dish.id] = ReservationItem(
        dishId: dish.id,
        dishName: dish.name,
        quantity: 1,
        unitPrice: dish.price,
      );
    }
    emit(state.copyWith(cart: cart));
  }

  void removeDish(Dish dish) {
    final cart = Map<String, ReservationItem>.from(state.cart);
    final key = _cartKeyForDish(cart, dish);
    if (key == null) return;

    final existing = cart[key]!;
    if (existing.quantity <= 1) {
      cart.remove(key);
    } else {
      cart[key] = ReservationItem(
        dishId: existing.dishId.isNotEmpty ? existing.dishId : dish.id,
        dishName: existing.dishName,
        quantity: existing.quantity - 1,
        unitPrice: existing.unitPrice,
        additions: existing.additions,
      );
    }
    emit(state.copyWith(cart: cart));
  }

  int quantityForDish(Dish dish) {
    final key = _cartKeyForDish(state.cart, dish);
    if (key == null) return 0;
    return state.cart[key]?.quantity ?? 0;
  }

  String? _cartKeyForDish(Map<String, ReservationItem> cart, Dish dish) {
    if (cart.containsKey(dish.id)) return dish.id;

    final normalizedId = _normalizeKey(dish.id);
    for (final key in cart.keys) {
      if (_normalizeKey(key) == normalizedId) return key;
    }

    final normalizedName = _normalizeKey(dish.name);
    for (final entry in cart.entries) {
      if (_normalizeKey(entry.value.dishName) == normalizedName) return entry.key;
    }
    return null;
  }

  Map<String, ReservationItem> _reconcileCartWithMenu(
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
      } else if (item.dishId.isNotEmpty) {
        reconciled[item.dishId] = item;
      }
    }
    return reconciled;
  }

  String _normalizeKey(String value) => value.toLowerCase().trim();

  /// Returns updated [Reservation] on success, or an error i18n key on failure.
  Future<Object?> save() async {
    final items = state.items
        .where((item) => item.quantity > 0 && item.dishId.isNotEmpty)
        .toList();

    if (items.isEmpty) {
      return 'waiterEditOrderNoValidItems';
    }

    emit(state.copyWith(submitting: true));
    try {
      final updated = await reservationRepository.updateItemsByWaiter(
        reservationId: reservation.id,
        items: items,
        accessToken: accessToken,
      );
      emit(state.copyWith(submitting: false));
      return updated;
    } catch (e, stack) {
      debugPrint('EditReservationOrder save failed: $e\n$stack');
      emit(state.copyWith(submitting: false));
      if (e is Exception && e.toString().contains('Exception:')) {
        return e.toString().replaceFirst('Exception: ', '');
      }
      return 'waiterEditOrderError';
    }
  }
}
