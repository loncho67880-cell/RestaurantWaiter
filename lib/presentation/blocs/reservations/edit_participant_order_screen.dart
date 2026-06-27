import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/core/utils/order_cart.dart';
import 'package:restaurantwaiter/domain/models/category_menu.dart';
import 'package:restaurantwaiter/domain/models/dish.dart';
import 'package:restaurantwaiter/domain/models/reservation.dart';
import 'package:restaurantwaiter/domain/models/reservation_item.dart';
import 'package:restaurantwaiter/domain/models/table_session_participant.dart';
import 'package:restaurantwaiter/domain/repositories/reservation_repository.dart';
import 'package:restaurantwaiter/domain/repositories/table_session_repository.dart';
import 'package:restaurantwaiter/infrastructure/repositories/menu_repository.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/auth_state.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/authevent.dart';
import 'package:restaurantwaiter/presentation/widgets/branch_guard.dart';
import 'package:restaurantwaiter/presentation/widgets/menu_category_selector.dart';

class EditParticipantOrderScreen extends StatefulWidget {
  final String sessionId;
  final TableSessionParticipant participant;
  final Reservation reservation;

  const EditParticipantOrderScreen({
    super.key,
    required this.sessionId,
    required this.participant,
    required this.reservation,
  });

  @override
  State<EditParticipantOrderScreen> createState() =>
      _EditParticipantOrderScreenState();
}

class _EditParticipantOrderScreenState extends State<EditParticipantOrderScreen>
    with WidgetsBindingObserver {
  late Map<String, ReservationItem> _cart;
  bool _loadingMenu = true;
  bool _saving = false;
  String? _error;
  List<CategoryMenu> _categories = [];
  String _selectedCategoryId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cart = {};
    _loadInitialData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_saving) {
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    final authState = context.read<AuthCubit>().state;
    final appConfig = context.read<AppConfigCubit>().state;
    if (authState is! AuthAuthenticated) return;

    if (_categories.isEmpty) {
      setState(() {
        _loadingMenu = true;
        _error = null;
      });
    }

    try {
      final participants =
          await context.read<TableSessionRepository>().getParticipants(
                sessionId: widget.sessionId,
                accessToken: authState.waiter.token,
              );
      final participant = participants
              .where((p) => p.customerId == widget.participant.customerId)
              .firstOrNull ??
          widget.participant;

      final categories = await context.read<MenuRepository>().loadCategories(
            appConfig.localeCode,
            appConfig.restaurantId,
            appConfig.branchId,
            authState.waiter.token,
          );
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedCategoryId =
            categories.isEmpty ? '' : categories.first.id;
        _cart = OrderCart.reconcileWithMenu(
          OrderCart.fromItems(participant.items),
          categories,
        );
        _loadingMenu = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMenu = false;
        _error = e.toString();
      });
    }
  }

  int _quantityOf(Dish dish) => OrderCart.quantityForDish(_cart, dish);

  void _addDish(Dish dish) {
    setState(() => _cart = OrderCart.addDish(_cart, dish));
  }

  void _decrementDish(Dish dish) {
    setState(() => _cart = OrderCart.removeDish(_cart, dish));
  }

  Future<void> _save() async {
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return;

    setState(() => _saving = true);
    try {
      final items = _cart.values
          .where(
            (item) =>
                item.quantity > 0 &&
                (item.dishId.isNotEmpty || item.dishName.trim().isNotEmpty),
          )
          .toList();

      await context.read<TableSessionRepository>().updateParticipantItems(
            sessionId: widget.sessionId,
            customerId: widget.participant.customerId,
            items: items,
            accessToken: authState.waiter.token,
          );

      final reservations =
          await context.read<ReservationRepository>().getActiveReservations(
                branchId: context.read<AppConfigCubit>().state.branchId,
                accessToken: authState.waiter.token,
              );
      final updated = reservations
          .where((r) => r.id == widget.sessionId)
          .firstOrNull;

      if (!mounted) return;
      Navigator.pop(context, updated ?? widget.reservation);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  CategoryMenu? get _selectedCategory {
    for (final category in _categories) {
      if (category.id == _selectedCategoryId) return category;
    }
    return _categories.isNotEmpty ? _categories.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;
    final category = _selectedCategory;

    return BranchGuard(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.colorScheme.primary,
          iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
          title: Text(
            t('editParticipantOrderTitle', replacements: {
              'name': widget.participant.displayName,
            }),
            style: TextStyle(color: theme.colorScheme.onPrimary),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : Text(
                      t('saveBtn'),
                      style: TextStyle(color: theme.colorScheme.onPrimary),
                    ),
            ),
          ],
        ),
        body: _loadingMenu
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : category == null
                    ? Center(child: Text(t('menuLoadError')))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          MenuCategorySelector(
                            categories: _categories,
                            selectedCategoryId: _selectedCategoryId,
                            onCategorySelected: (id) =>
                                setState(() => _selectedCategoryId = id),
                          ),
                          const SizedBox(height: 12),
                          ...category.dishes.map(
                            (dish) => ListTile(
                              title: Text(dish.name),
                              subtitle:
                                  Text('\$${dish.price.toStringAsFixed(0)}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: _quantityOf(dish) > 0
                                        ? () => _decrementDish(dish)
                                        : null,
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  Text('${_quantityOf(dish)}'),
                                  IconButton(
                                    onPressed: () => _addDish(dish),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}
