import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/core/utils/order_cart.dart';
import 'package:restaurantwaiter/domain/models/category_menu.dart';
import 'package:restaurantwaiter/domain/models/dish.dart';
import 'package:restaurantwaiter/domain/models/reservation.dart';
import 'package:restaurantwaiter/domain/models/reservation_item.dart';
import 'package:restaurantwaiter/domain/models/table_session_participant.dart';
import 'package:restaurantwaiter/domain/models/table_session_snapshot.dart';
import 'package:restaurantwaiter/domain/repositories/reservation_repository.dart';
import 'package:restaurantwaiter/domain/repositories/table_session_repository.dart';
import 'package:restaurantwaiter/infrastructure/repositories/menu_repository.dart';
import 'package:restaurantwaiter/infrastructure/services/table_session_realtime_service.dart';
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
  StreamSubscription<TableSessionSnapshot>? _realtimeSub;
  Timer? _pollTimer;
  Timer? _autoSaveTimer;
  bool _syncing = false;
  late final TableSessionRealtimeService _realtimeService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _realtimeService = context.read<TableSessionRealtimeService>();
    _cart = {};
    _initLiveSync();
    _loadInitialData();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _pollTimer?.cancel();
    _realtimeSub?.cancel();
    _realtimeService.clearRefreshCallback(widget.sessionId);
    _realtimeService.unwatchSession(widget.sessionId);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_saving) {
      _loadInitialData();
    }
  }

  Future<void> _initLiveSync() async {
    _realtimeService.setRefreshCallback(
      widget.sessionId,
      () {
        if (mounted && !_saving) {
          _refreshParticipantCart(showNotice: false);
        }
      },
    );

    _realtimeSub = _realtimeService.updatesFor(widget.sessionId).listen(
      _onSessionSnapshot,
      onError: (Object error, StackTrace stack) {
        debugPrint('[EditParticipantOrder] realtime error: $error\n$stack');
      },
    );

    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (mounted && !_saving && !_loadingMenu) {
          _refreshParticipantCart(showNotice: false);
        }
      },
    );

    await _startLiveSync();
  }

  Future<void> _refreshParticipantCart({bool showNotice = false}) async {
    if (_categories.isEmpty) return;

    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return;

    try {
      final participants =
          await context.read<TableSessionRepository>().getParticipants(
                sessionId: widget.sessionId,
                accessToken: authState.waiter.token,
              );
      if (!mounted) return;

      final participant = participants
          .where(
            (p) =>
                p.customerId.toLowerCase() ==
                widget.participant.customerId.toLowerCase(),
          )
          .firstOrNull;
      if (participant == null) return;

      _applyParticipantCart(participant, showNotice: showNotice);
    } catch (e, stack) {
      debugPrint('[EditParticipantOrder] refresh failed: $e\n$stack');
    }
  }

  void _applyParticipantCart(
    TableSessionParticipant participant, {
    bool showNotice = true,
  }) {
    if (participant.isOrderConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<AppConfigCubit>().translate(
                  'participantOrderConfirmedRemotely',
                ),
          ),
        ),
      );
      Navigator.pop(context, widget.reservation);
      return;
    }

    final newCart = OrderCart.reconcileWithMenu(
      OrderCart.fromItems(participant.items),
      _categories,
    );
    if (OrderCart.hasSameQuantities(_cart, newCart)) return;

    setState(() => _cart = newCart);
    if (!showNotice) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.read<AppConfigCubit>().translate(
                'participantOrderUpdatedRemotely',
              ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

      final latest = _realtimeService.latestSnapshot(widget.sessionId);
      if (latest != null) {
        final liveParticipant = latest.participants
            .where(
              (p) =>
                  p.customerId.toLowerCase() ==
                  widget.participant.customerId.toLowerCase(),
            )
            .firstOrNull;
        if (liveParticipant != null) {
          _applyParticipantCart(liveParticipant, showNotice: false);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMenu = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _startLiveSync() async {
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return;

    try {
      await _realtimeService.watchSession(
        sessionId: widget.sessionId,
        accessToken: authState.waiter.token,
      );
      await _realtimeSub?.cancel();
      _realtimeSub = _realtimeService.updatesFor(widget.sessionId).listen(
        _onSessionSnapshot,
        onError: (Object error, StackTrace stack) {
          debugPrint('[EditParticipantOrder] realtime error: $error\n$stack');
        },
      );
    } catch (error, stack) {
      debugPrint('[EditParticipantOrder] failed to start realtime: $error\n$stack');
    }
  }

  void _onSessionSnapshot(TableSessionSnapshot snapshot) {
    if (!mounted || _saving || _syncing || _categories.isEmpty) return;

    final participant = snapshot.participants
        .where(
          (p) =>
              p.customerId.toLowerCase() ==
              widget.participant.customerId.toLowerCase(),
        )
        .firstOrNull;
    if (participant == null) return;

    _applyParticipantCart(participant);
  }

  int _quantityOf(Dish dish) => OrderCart.quantityForDish(_cart, dish);

  List<ReservationItem> _cartItems() => _cart.values
      .where(
        (item) =>
            item.quantity > 0 &&
            (item.dishId.isNotEmpty || item.dishName.trim().isNotEmpty),
      )
      .toList();

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted && !_saving) {
        _persistCart(showErrors: false);
      }
    });
  }

  Future<bool> _persistCart({bool showErrors = true}) async {
    if (_loadingMenu) return false;

    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return false;

    final items = _cartItems();
    setState(() => _syncing = true);

    try {
      await context.read<TableSessionRepository>().updateParticipantItems(
            sessionId: widget.sessionId,
            customerId: widget.participant.customerId,
            items: items,
            accessToken: authState.waiter.token,
          );
      return true;
    } catch (e) {
      if (showErrors && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _addDish(Dish dish) {
    setState(() => _cart = OrderCart.addDish(_cart, dish));
    _scheduleAutoSave();
  }

  void _decrementDish(Dish dish) {
    setState(() => _cart = OrderCart.removeDish(_cart, dish));
    _scheduleAutoSave();
  }

  Future<void> _save() async {
    _autoSaveTimer?.cancel();
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return;

    setState(() => _saving = true);
    try {
      final saved = await _persistCart(showErrors: true);
      if (!saved || !mounted) return;

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
    } finally {
      if (mounted) setState(() => _saving = false);
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
              onPressed: (_saving || _syncing) ? null : _save,
              child: _saving || _syncing
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
