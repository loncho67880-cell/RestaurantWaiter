import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:restaurantwaiter/core/utils/order_cart.dart';
import 'package:restaurantwaiter/domain/models/dish.dart';
import 'package:restaurantwaiter/domain/models/reservation.dart';
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
          cart: OrderCart.fromItems(reservation.items),
        ));

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

      final reconciledCart = OrderCart.reconcileWithMenu(state.cart, categories);

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
    emit(state.copyWith(cart: OrderCart.addDish(state.cart, dish)));
  }

  void removeDish(Dish dish) {
    emit(state.copyWith(cart: OrderCart.removeDish(state.cart, dish)));
  }

  int quantityForDish(Dish dish) => OrderCart.quantityForDish(state.cart, dish);

  /// Returns updated [Reservation] on success, or an error i18n key on failure.
  Future<Object?> save() async {
    final items = state.items
        .where(
          (item) =>
              item.quantity > 0 &&
              (item.dishId.isNotEmpty || item.dishName.trim().isNotEmpty),
        )
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
