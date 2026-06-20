import 'package:equatable/equatable.dart';
import 'package:restaurantwaiter/domain/models/category_menu.dart';
import 'package:restaurantwaiter/domain/models/reservation_item.dart';

enum EditReservationOrderStatus { loading, loaded, error }

class EditReservationOrderState extends Equatable {
  final EditReservationOrderStatus status;
  final List<CategoryMenu> categories;
  final String selectedCategoryId;
  final Map<String, ReservationItem> cart;
  final bool submitting;

  const EditReservationOrderState({
    this.status = EditReservationOrderStatus.loading,
    this.categories = const [],
    this.selectedCategoryId = '',
    this.cart = const {},
    this.submitting = false,
  });

  CategoryMenu? get selectedCategory {
    for (final c in categories) {
      if (c.id == selectedCategoryId) return c;
    }
    return categories.isNotEmpty ? categories.first : null;
  }

  List<ReservationItem> get items => cart.values.toList();

  int get totalItems =>
      cart.values.fold(0, (sum, item) => sum + item.quantity);

  bool get canSave => cart.values.any((item) => item.quantity > 0);

  double get total =>
      cart.values.fold(0.0, (sum, item) => sum + item.subtotal);

  EditReservationOrderState copyWith({
    EditReservationOrderStatus? status,
    List<CategoryMenu>? categories,
    String? selectedCategoryId,
    Map<String, ReservationItem>? cart,
    bool? submitting,
  }) {
    return EditReservationOrderState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      cart: cart ?? this.cart,
      submitting: submitting ?? this.submitting,
    );
  }

  @override
  List<Object?> get props => [
        status,
        categories,
        selectedCategoryId,
        items.map((e) => '${e.dishId}:${e.quantity}').join(','),
        submitting,
      ];
}
