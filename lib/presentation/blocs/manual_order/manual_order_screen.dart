import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/domain/models/dish.dart';
import 'package:restaurantwaiter/domain/models/table_model.dart';
import 'package:restaurantwaiter/domain/repositories/order_repository.dart';
import 'package:restaurantwaiter/infrastructure/repositories/menu_repository.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/auth_state.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/authevent.dart';
import 'package:restaurantwaiter/presentation/blocs/manual_order/manual_order_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/manual_order/manual_order_state.dart';

class ManualOrderScreen extends StatelessWidget {
  const ManualOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final appConfig = context.read<AppConfigCubit>().state;

    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return BlocProvider(
      create: (_) => ManualOrderCubit(
        menuRepository: context.read<MenuRepository>(),
        orderRepository: context.read<OrderRepository>(),
        restaurantId: appConfig.restaurantId,
        branchId: appConfig.branchId,
        accessToken: authState.customer.token,
        localeCode: appConfig.localeCode,
      )..loadMenu(),
      child: const _ManualOrderView(),
    );
  }
}

class _ManualOrderView extends StatefulWidget {
  const _ManualOrderView();

  @override
  State<_ManualOrderView> createState() => _ManualOrderViewState();
}

class _ManualOrderViewState extends State<_ManualOrderView> {
  final _notesController = TextEditingController();
  int _guestCount = 1;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = context.read<AppConfigCubit>().translate;
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final errorKey = await context.read<ManualOrderCubit>().submit(
          guestCount: _guestCount,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

    if (!mounted) return;

    if (errorKey == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(t('manualOrderSubmitSuccess')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      navigator.pop();
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(t(errorKey)),
          backgroundColor: theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        title: Text(
          t('manualOrderTitle'),
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
      ),
      body: BlocBuilder<ManualOrderCubit, ManualOrderState>(
        builder: (context, state) {
          switch (state.status) {
            case ManualOrderStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case ManualOrderStatus.error:
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(t('menuLoadError'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () =>
                            context.read<ManualOrderCubit>().loadMenu(),
                        child: Text(t('waiterRetry')),
                      ),
                    ],
                  ),
                ),
              );
            case ManualOrderStatus.loaded:
              return _buildContent(context, state);
          }
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ManualOrderState state) {
    final theme = Theme.of(context);
    final category = state.selectedCategory;

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _TableAndGuestsCard(
                    tables: state.tables,
                    selectedTableId: state.selectedTableId,
                    guestCount: _guestCount,
                    notesController: _notesController,
                    onTableChanged: (id) =>
                        context.read<ManualOrderCubit>().selectTable(id),
                    onGuestChanged: (v) => setState(() => _guestCount = v),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: state.categories.map((c) {
                      final selected = c.id == state.selectedCategoryId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c.name),
                          selected: selected,
                          onSelected: (_) => context
                              .read<ManualOrderCubit>()
                              .selectCategory(c.id),
                          selectedColor:
                              theme.colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (category != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final dish = category.dishes[index];
                        return _DishCard(
                          dish: dish,
                          quantity: context
                              .read<ManualOrderCubit>()
                              .quantityOf(dish.id),
                        );
                      },
                      childCount: category.dishes.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _CartBar(
          totalItems: state.totalItems,
          total: state.total,
          submitting: state.submitting,
          onSubmit: state.totalItems == 0 || state.submitting ? null : _submit,
        ),
      ],
    );
  }
}

class _TableAndGuestsCard extends StatelessWidget {
  final List<TableModel> tables;
  final String? selectedTableId;
  final TextEditingController notesController;
  final int guestCount;
  final ValueChanged<String> onTableChanged;
  final ValueChanged<int> onGuestChanged;

  const _TableAndGuestsCard({
    required this.tables,
    required this.selectedTableId,
    required this.notesController,
    required this.guestCount,
    required this.onTableChanged,
    required this.onGuestChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tables.isEmpty)
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(child: Text(t('manualOrderNoTables'))),
              ],
            )
          else
            DropdownButtonFormField<String>(
              initialValue: selectedTableId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: t('manualOrderSelectTable'),
                prefixIcon: const Icon(Icons.table_restaurant_rounded),
                border: const OutlineInputBorder(),
              ),
              items: tables
                  .map(
                    (table) => DropdownMenuItem(
                      value: table.tableId,
                      child: Text(
                        '${t('tableNum')} ${table.tableNumber} · '
                        '${t('floor')} ${table.floor} · '
                        '${table.capacity}p',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onTableChanged(value);
              },
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.people_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(t('guestCount'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton.filledTonal(
                onPressed:
                    guestCount > 1 ? () => onGuestChanged(guestCount - 1) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$guestCount',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              IconButton.filledTonal(
                onPressed: () => onGuestChanged(guestCount + 1),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            decoration: InputDecoration(
              labelText: t('notesLabel'),
              hintText: t('notesHint'),
              prefixIcon: const Icon(Icons.notes_rounded),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  final Dish dish;
  final int quantity;

  const _DishCard({required this.dish, required this.quantity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ManualOrderCubit>();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  dish.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    child: Icon(Icons.restaurant_rounded,
                        color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dish.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              '\$${dish.price.toStringAsFixed(0)}',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            if (quantity == 0)
              SizedBox(
                width: double.infinity,
                height: 36,
                child: OutlinedButton(
                  onPressed: () => cubit.addDish(dish),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: theme.colorScheme.primary,
                  ),
                  child: const Icon(Icons.add_rounded, size: 20),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _QtyButton(
                    icon: Icons.remove_rounded,
                    onTap: () => cubit.removeDish(dish.id),
                  ),
                  Text('$quantity',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  _QtyButton(
                    icon: Icons.add_rounded,
                    onTap: () => cubit.addDish(dish),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: theme.colorScheme.primary),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  final int totalItems;
  final double total;
  final bool submitting;
  final VoidCallback? onSubmit;

  const _CartBar({
    required this.totalItems,
    required this.total,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('manualOrderItemsCount',
                      replacements: {'{count}': '$totalItems'}),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  '\$${total.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: onSubmit,
                icon: submitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(t('manualOrderSubmit')),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
