import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/core/utils/reservation_datetime.dart';
import 'package:restaurantwaiter/domain/models/dish.dart';
import 'package:restaurantwaiter/domain/models/reservation.dart';
import 'package:restaurantwaiter/domain/repositories/reservation_repository.dart';
import 'package:restaurantwaiter/infrastructure/repositories/menu_repository.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/auth_state.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/authevent.dart';
import 'package:restaurantwaiter/presentation/blocs/reservations/edit_reservation_order_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/reservations/edit_reservation_order_state.dart';
import 'package:restaurantwaiter/presentation/widgets/branch_guard.dart';
import 'package:restaurantwaiter/presentation/widgets/menu_category_selector.dart';

class EditReservationOrderScreen extends StatelessWidget {
  final Reservation reservation;

  const EditReservationOrderScreen({super.key, required this.reservation});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final appConfig = context.read<AppConfigCubit>().state;

    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return BranchGuard(
      child: BlocProvider(
        create: (_) => EditReservationOrderCubit(
          menuRepository: context.read<MenuRepository>(),
          reservationRepository: context.read<ReservationRepository>(),
          reservation: reservation,
          restaurantId: appConfig.restaurantId,
          branchId: appConfig.branchId,
          accessToken: authState.waiter.token,
          localeCode: appConfig.localeCode,
        )..loadMenu(),
        child: _EditReservationOrderView(reservation: reservation),
      ),
    );
  }
}

class _EditReservationOrderView extends StatelessWidget {
  final Reservation reservation;

  const _EditReservationOrderView({required this.reservation});

  Future<void> _save(BuildContext context) async {
    final t = context.read<AppConfigCubit>().translate;
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final result = await context.read<EditReservationOrderCubit>().save();
    if (!context.mounted) return;

    if (result is Reservation) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(t('waiterEditOrderSuccess')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      navigator.pop(result);
    } else if (result is String) {
      final isKnownKey = result.startsWith('waiter') || result.startsWith('manual');
      messenger.showSnackBar(
        SnackBar(
          content: Text(isKnownKey ? t(result) : result),
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
    final locale = context.read<AppConfigCubit>().state.localeCode;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        title: Text(
          t('waiterEditOrderTitle'),
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
      ),
      body: BlocBuilder<EditReservationOrderCubit, EditReservationOrderState>(
        builder: (context, state) {
          switch (state.status) {
            case EditReservationOrderStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case EditReservationOrderStatus.error:
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
                            context.read<EditReservationOrderCubit>().loadMenu(),
                        child: Text(t('waiterRetry')),
                      ),
                    ],
                  ),
                ),
              );
            case EditReservationOrderStatus.loaded:
              return _buildContent(context, state, t, locale, theme);
          }
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    EditReservationOrderState state,
    String Function(String, {Map<String, String>? replacements}) t,
    String locale,
    ThemeData theme,
  ) {
    final category = state.selectedCategory;

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
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
                        Text(
                          '${t('floor')} ${reservation.floor} — '
                          '${t('tableNum')} ${reservation.tableNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatReservationDateTime(
                            reservation.reservationDate,
                            locale,
                          ),
                          style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t('waiterEditOrderHint'),
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (state.items.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('waiterEditOrderCurrent'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...state.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '${item.quantity}x ${item.dishName}',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: MenuCategorySelector(
                  categories: state.categories,
                  selectedCategoryId: state.selectedCategoryId,
                  onCategorySelected:
                      context.read<EditReservationOrderCubit>().selectCategory,
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
                        return BlocBuilder<EditReservationOrderCubit,
                            EditReservationOrderState>(
                          buildWhen: (prev, curr) =>
                              prev.cart != curr.cart ||
                              prev.selectedCategoryId != curr.selectedCategoryId,
                          builder: (context, cartState) {
                            return _DishCard(
                              dish: dish,
                              quantity: context
                                  .read<EditReservationOrderCubit>()
                                  .quantityForDish(dish),
                            );
                          },
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
          onSubmit: !state.canSave || state.submitting
              ? null
              : () => _save(context),
        ),
      ],
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
    final cubit = context.read<EditReservationOrderCubit>();

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
                    onTap: () => cubit.removeDish(dish),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              width: double.infinity,
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
                    : const Icon(Icons.save_rounded),
                label: Text(t('waiterEditOrderSave')),
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
