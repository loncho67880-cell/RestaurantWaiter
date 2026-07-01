import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/core/utils/reservation_datetime.dart';
import 'package:restaurantwaiter/core/utils/theme_contrast.dart';
import 'package:restaurantwaiter/domain/models/reservation.dart';
import 'package:restaurantwaiter/domain/repositories/order_repository.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/auth_state.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/authevent.dart';
import 'package:restaurantwaiter/presentation/blocs/ready_to_pay/ready_to_pay_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/ready_to_pay/ready_to_pay_state.dart';
import 'package:restaurantwaiter/presentation/widgets/branch_guard.dart';

class ReadyToPayScreen extends StatelessWidget {
  const ReadyToPayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final appConfig = context.read<AppConfigCubit>().state;

    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return BranchGuard(
      child: BlocProvider(
        create: (_) => ReadyToPayCubit(
          orderRepository: context.read<OrderRepository>(),
          branchId: appConfig.branchId,
          accessToken: authState.waiter.token,
        )..load(),
        child: const _ReadyToPayView(),
      ),
    );
  }
}

class _ReadyToPayView extends StatelessWidget {
  const _ReadyToPayView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        automaticallyImplyLeading: false,
        title: Text(
          t('readyToPayTitle'),
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.onPrimary),
            tooltip: t('waiterRefresh'),
            onPressed: () => context.read<ReadyToPayCubit>().load(),
          ),
        ],
      ),
      body: BlocBuilder<ReadyToPayCubit, ReadyToPayState>(
        builder: (context, state) {
          switch (state.status) {
            case ReadyToPayStatus.loading:
              return const Center(child: CircularProgressIndicator());

            case ReadyToPayStatus.error:
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        state.errorMessage ?? t('waiterReservationsLoadError'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => context.read<ReadyToPayCubit>().load(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(t('waiterRetry')),
                      ),
                    ],
                  ),
                ),
              );

            case ReadyToPayStatus.loaded:
              if (state.reservations.isEmpty) {
                return _EmptyView(
                  onRefresh: () => context.read<ReadyToPayCubit>().load(),
                );
              }
              return RefreshIndicator(
                onRefresh: () => context.read<ReadyToPayCubit>().load(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: state.reservations.length,
                  itemBuilder: (context, i) {
                    final r = state.reservations[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _ReadyCard(
                        reservation: r,
                        isMarkingPaid: state.markingPaidId == r.id,
                        onMarkPaid: () => _markPaid(context, r),
                      ),
                    );
                  },
                ),
              );
          }
        },
      ),
    );
  }

  Future<void> _markPaid(BuildContext context, Reservation r) async {
    final t = context.read<AppConfigCubit>().translate;
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    final errorKey = await context.read<ReadyToPayCubit>().markAsPaid(r.id);
    if (!context.mounted) return;

    if (errorKey == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(t('readyToPayMarkSuccess')),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
}

class _ReadyCard extends StatelessWidget {
  final Reservation reservation;
  final bool isMarkingPaid;
  final VoidCallback onMarkPaid;

  const _ReadyCard({
    required this.reservation,
    required this.isMarkingPaid,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;
    final appConfig = context.read<AppConfigCubit>().state;

    return Theme(
      data: ThemeContrast.lightCardTheme(theme),
      child: Card(
        elevation: 2,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: table + time
              Row(
                children: [
                  Icon(Icons.table_restaurant_rounded,
                      color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${t('tableNum')} ${reservation.tableNumber}  ·  ${t('floor')} ${reservation.floor}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: ThemeContrast.onLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.payments_rounded, size: 14, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(
                        t('readyToPayBadge'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Date + guests
            Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 16, color: ThemeContrast.onLightMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    formatReservationDateTime(
                        reservation.reservationDate, appConfig.localeCode),
                    style: const TextStyle(color: ThemeContrast.onLightMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.people_rounded,
                    size: 16, color: ThemeContrast.onLightMuted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${reservation.guestCount} ${t('guestCount').toLowerCase()}',
                    style: const TextStyle(color: ThemeContrast.onLightMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Items
            if (reservation.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ...reservation.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        '${item.quantity}×',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.dishName,
                          style: const TextStyle(color: ThemeContrast.onLight),
                        ),
                      ),
                      Text(
                        '\$${item.subtotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: ThemeContrast.onLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  t('totalLabel', replacements: {
                    '{total}': '\$${reservation.totalPreOrder.toStringAsFixed(0)}'
                  }),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isMarkingPaid ? null : onMarkPaid,
                icon: isMarkingPaid
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: Text(isMarkingPaid ? t('readyToPayMarking') : t('readyToPayMarkBtn')),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 72,
                color: Colors.green.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              t('readyToPayEmpty'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(t('waiterRefresh')),
            ),
          ],
        ),
      ),
    );
  }
}
