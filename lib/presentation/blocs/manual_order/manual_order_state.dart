import 'package:equatable/equatable.dart';
import 'package:restaurantwaiter/domain/models/category_menu.dart';
import 'package:restaurantwaiter/domain/models/reservation_item.dart';
import 'package:restaurantwaiter/domain/models/table_model.dart';

enum ManualOrderStatus { loading, loaded, error }

class ManualOrderState extends Equatable {
  final ManualOrderStatus status;
  final List<CategoryMenu> categories;
  final String selectedCategoryId;
  final List<TableModel> tables;
  final String? selectedTableId;

  /// Cart keyed by dishId.
  final Map<String, ReservationItem> cart;
  final bool submitting;

  const ManualOrderState({
    this.status = ManualOrderStatus.loading,
    this.categories = const [],
    this.selectedCategoryId = '',
    this.tables = const [],
    this.selectedTableId,
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

  double get total =>
      cart.values.fold(0.0, (sum, item) => sum + item.subtotal);

  ManualOrderState copyWith({
    ManualOrderStatus? status,
    List<CategoryMenu>? categories,
    String? selectedCategoryId,
    List<TableModel>? tables,
    String? selectedTableId,
    Map<String, ReservationItem>? cart,
    bool? submitting,
  }) {
    return ManualOrderState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      tables: tables ?? this.tables,
      selectedTableId: selectedTableId ?? this.selectedTableId,
      cart: cart ?? this.cart,
      submitting: submitting ?? this.submitting,
    );
  }

  @override
  List<Object?> get props => [
        status,
        categories,
        selectedCategoryId,
        tables,
        selectedTableId,
        items.map((e) => '${e.dishId}:${e.quantity}').join(','),
        submitting,
      ];
}
