import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/domain/models/dish.dart';
import 'package:restaurantwaiter/domain/models/manual_order.dart';
import 'package:restaurantwaiter/domain/models/reservation_item.dart';
import 'package:restaurantwaiter/domain/repositories/order_repository.dart';
import 'package:restaurantwaiter/infrastructure/repositories/menu_repository.dart';

import 'manual_order_state.dart';

class ManualOrderCubit extends Cubit<ManualOrderState> {
  final MenuRepository menuRepository;
  final OrderRepository orderRepository;
  final String restaurantId;
  final String branchId;
  final String accessToken;
  final String localeCode;

  ManualOrderCubit({
    required this.menuRepository,
    required this.orderRepository,
    required this.restaurantId,
    required this.branchId,
    required this.accessToken,
    required this.localeCode,
  }) : super(const ManualOrderState());

  Future<void> loadMenu() async {
    emit(state.copyWith(status: ManualOrderStatus.loading));
    try {
      final categories = await menuRepository.loadCategories(
        localeCode,
        restaurantId,
        branchId,
        accessToken,
      );

      if (categories.isEmpty) {
        emit(state.copyWith(status: ManualOrderStatus.error));
        return;
      }

      // Show the menu as soon as the catalog is ready. Tables are loaded
      // separately because the availability endpoint can be slow or fail
      // (e.g. outside branch hours) without blocking the whole screen.
      emit(state.copyWith(
        status: ManualOrderStatus.loaded,
        categories: categories,
        selectedCategoryId: categories.first.id,
        tables: const [],
      ));
    } catch (e, stack) {
      debugPrint('ManualOrder loadMenu failed: $e\n$stack');
      emit(state.copyWith(status: ManualOrderStatus.error));
      return;
    }

    await _loadTables();
  }

  Future<void> _loadTables() async {
    try {
      final tables = await orderRepository.getAvailableTables(
        branchId: branchId,
        accessToken: accessToken,
      );
      if (isClosed) return;
      emit(state.copyWith(
        tables: tables,
        selectedTableId:
            state.selectedTableId ?? (tables.isNotEmpty ? tables.first.tableId : null),
      ));
    } catch (e, stack) {
      debugPrint('ManualOrder loadTables failed: $e\n$stack');
    }
  }

  void selectCategory(String categoryId) {
    emit(state.copyWith(selectedCategoryId: categoryId));
  }

  void selectTable(String tableId) {
    emit(state.copyWith(selectedTableId: tableId));
  }

  void addDish(Dish dish) {
    final cart = Map<String, ReservationItem>.from(state.cart);
    final existing = cart[dish.id];
    if (existing != null) {
      cart[dish.id] = ReservationItem(
        dishId: existing.dishId,
        dishName: existing.dishName,
        quantity: existing.quantity + 1,
        unitPrice: existing.unitPrice,
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

  void removeDish(String dishId) {
    final cart = Map<String, ReservationItem>.from(state.cart);
    final existing = cart[dishId];
    if (existing == null) return;
    if (existing.quantity <= 1) {
      cart.remove(dishId);
    } else {
      cart[dishId] = ReservationItem(
        dishId: existing.dishId,
        dishName: existing.dishName,
        quantity: existing.quantity - 1,
        unitPrice: existing.unitPrice,
        additions: existing.additions,
      );
    }
    emit(state.copyWith(cart: cart));
  }

  /// Returns null on success, or an error i18n key on failure.
  Future<String?> submit({
    required int guestCount,
    String? notes,
  }) async {
    final tableId = state.selectedTableId;
    if (tableId == null || tableId.isEmpty) return 'manualOrderTableRequired';
    if (state.items.isEmpty) return 'manualOrderEmptyError';

    emit(state.copyWith(submitting: true));
    try {
      await orderRepository.createManualOrder(
        order: ManualOrder(
          restaurantId: restaurantId,
          branchId: branchId,
          tableId: tableId,
          guestCount: guestCount,
          notes: notes,
          items: state.items,
        ),
        accessToken: accessToken,
      );
      emit(state.copyWith(submitting: false));
      return null;
    } catch (_) {
      emit(state.copyWith(submitting: false));
      return 'manualOrderSubmitError';
    }
  }
}
