import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/domain/models/category_menu.dart';
import 'package:restaurantwaiter/domain/models/dish.dart';
import 'package:restaurantwaiter/domain/models/manual_order.dart';
import 'package:restaurantwaiter/domain/models/reservation_item.dart';
import 'package:restaurantwaiter/domain/models/table_model.dart';
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
      final results = await Future.wait([
        menuRepository.loadCategories(
          localeCode,
          restaurantId,
          branchId,
          accessToken,
        ),
        orderRepository.getAvailableTables(
          branchId: branchId,
          accessToken: accessToken,
        ),
      ]);

      final categories = results[0] as List<CategoryMenu>;
      final tables = results[1] as List<TableModel>;

      if (categories.isEmpty) {
        emit(state.copyWith(status: ManualOrderStatus.error));
        return;
      }
      emit(state.copyWith(
        status: ManualOrderStatus.loaded,
        categories: categories,
        selectedCategoryId: categories.first.id,
        tables: tables,
      ));
    } catch (_) {
      emit(state.copyWith(status: ManualOrderStatus.error));
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
      existing.quantity += 1;
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
      existing.quantity -= 1;
    }
    emit(state.copyWith(cart: cart));
  }

  int quantityOf(String dishId) => state.cart[dishId]?.quantity ?? 0;

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
