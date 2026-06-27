import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/core/utils/reservation_datetime.dart';
import 'package:restaurantwaiter/domain/models/reservation.dart';
import 'package:restaurantwaiter/domain/repositories/reservation_repository.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/auth_state.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/authevent.dart';
import 'package:restaurantwaiter/presentation/blocs/manual_order/manual_order_screen.dart';
import 'package:restaurantwaiter/presentation/blocs/reservations/reservation_detail_screen.dart';
import 'package:restaurantwaiter/presentation/blocs/reservations/waiter_reservations_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/reservations/waiter_reservations_state.dart';
import 'package:restaurantwaiter/presentation/widgets/branch_guard.dart';

class ActiveReservationsScreen extends StatelessWidget {
  const ActiveReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final appConfig = context.read<AppConfigCubit>().state;

    if (authState is! AuthAuthenticated) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return BranchGuard(
      child: BlocProvider(
        create: (_) => WaiterReservationsCubit(
          reservationRepository: context.read<ReservationRepository>(),
          branchId: appConfig.branchId,
          accessToken: authState.waiter.token,
        )..load(),
        child: const _ActiveReservationsView(),
      ),
    );
  }
}

class _ActiveReservationsView extends StatelessWidget {
  const _ActiveReservationsView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        title: Text(
          t('waiterHomeTitle'),
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: t('waiterRefresh'),
            icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.onPrimary),
            onPressed: () => context.read<WaiterReservationsCubit>().load(),
          ),
          IconButton(
            tooltip: t('logout'),
            icon: Icon(Icons.logout_rounded, color: theme.colorScheme.onPrimary),
            onPressed: () async {
              context.read<AppConfigCubit>().clearBranch();
              await context.read<AuthCubit>().signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      drawer: _WaiterDrawer(onManualOrder: () => _openManualOrder(context)),
      body: BlocBuilder<WaiterReservationsCubit, WaiterReservationsState>(
        builder: (context, state) {
          switch (state.status) {
            case WaiterReservationsStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case WaiterReservationsStatus.error:
              return _ErrorView(
                message: state.errorMessage,
                onRetry: () => context.read<WaiterReservationsCubit>().load(),
              );
            case WaiterReservationsStatus.loaded:
              if (state.reservations.isEmpty) {
                return _EmptyView(
                  onRefresh: () => context.read<WaiterReservationsCubit>().load(),
                );
              }
              return RefreshIndicator(
                onRefresh: () => context.read<WaiterReservationsCubit>().load(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Text(
                      t('waiterHomeSubtitle'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...state.reservations.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _ReservationCard(
                          reservation: r,
                          onTap: () => _openDetail(context, r),
                        ),
                      ),
                    ),
                  ],
                ),
              );
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        onPressed: () => _openManualOrder(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(t('manualOrderTitle')),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, Reservation reservation) async {
    final cubit = context.read<WaiterReservationsCubit>();
    final result = await Navigator.push<ReservationDetailResult>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: ReservationDetailScreen(reservation: reservation),
        ),
      ),
    );
    if (!context.mounted || result == null) return;
    switch (result) {
      case ReservationDetailUpdated(:final reservation):
        cubit.replaceReservation(reservation);
      case ReservationDetailCancelled():
        cubit.removeReservation(reservation.id);
    }
  }

  Future<void> _openManualOrder(BuildContext context) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ManualOrderScreen(),
      ),
    );
    if (created == true && context.mounted) {
      await context.read<WaiterReservationsCubit>().load();
    }
  }
}

class _WaiterDrawer extends StatelessWidget {
  final Future<void> Function() onManualOrder;

  const _WaiterDrawer({required this.onManualOrder});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;
    final appConfig = context.read<AppConfigCubit>().state;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: theme.colorScheme.primary),
              child: Row(
                children: [
                  Icon(Icons.room_service_rounded,
                      color: theme.colorScheme.onPrimary, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          t('waiterHomeTitle'),
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (appConfig.branchName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            appConfig.branchName,
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary
                                  .withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.event_seat_rounded,
                  color: theme.colorScheme.primary),
              title: Text(t('waiterHomeTitle')),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.storefront_rounded,
                  color: theme.colorScheme.primary),
              title: Text(t('changeBranch')),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/branch-select');
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.restaurant_rounded, color: theme.colorScheme.primary),
              title: Text(t('manualOrderTitle')),
              onTap: () async {
                Navigator.pop(context);
                await onManualOrder();
              },
            ),
          ],
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
            Icon(Icons.event_busy_rounded,
                size: 56, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              t('waiterNoReservations'),
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

class _ErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const _ErrorView({
    this.message,
    required this.onRetry,
  });

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
            Icon(Icons.error_outline_rounded,
                size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message ?? t('waiterReservationsLoadError'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(t('waiterRetry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback onTap;

  const _ReservationCard({
    required this.reservation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;
    final locale = context.read<AppConfigCubit>().state.localeCode;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor().withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusLabel(t),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${t('reservationId')}: ${reservation.id.substring(0, reservation.id.length < 8 ? reservation.id.length : 8).toUpperCase()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.table_restaurant_rounded,
                label: t('tableLabel'),
                value:
                    '${t('floor')} ${reservation.floor} — ${t('tableNum')} ${reservation.tableNumber}',
              ),
              _DetailRow(
                icon: Icons.schedule_rounded,
                label: t('dateLabel'),
                value: formatReservationDateTime(
                  reservation.reservationDate,
                  locale,
                ),
              ),
              _DetailRow(
                icon: Icons.people_rounded,
                label: t('guestCount'),
                value: '${reservation.guestCount} ${t('persons')}',
              ),
              if (reservation.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  t('preOrderTitle'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                ...reservation.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${item.quantity}x ${item.dishName}',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${t('preOrderTotal')} \$${reservation.totalPreOrder.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              if (reservation.notes != null &&
                  reservation.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.notes_rounded,
                  label: t('notesLabel'),
                  value: reservation.notes!,
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Color _statusColor() {
        if (reservation.isReadingQr) return Colors.purple;
        if (reservation.isInPreparation) return Colors.teal;
    if (reservation.isAwaitingWaiter) return Colors.blue;
    if (reservation.canWaiterConfirmArrival) return Colors.deepOrange;
    return switch (reservation.status) {
      ReservationStatus.confirmed => Colors.green,
      ReservationStatus.cancelled => Colors.red,
      ReservationStatus.pending => Colors.orange,
    };
  }

  String _statusLabel(
    String Function(String, {Map<String, String>? replacements}) t,
  ) {
    if (reservation.isReadingQr) return t('statusReadingQr');
    if (reservation.isInPreparation) return t('statusInPreparation');
    if (reservation.isAwaitingWaiter) return t('statusPendingWaiter');
    if (reservation.canWaiterConfirmArrival) return t('statusAwaitingArrival');
    return switch (reservation.status) {
      ReservationStatus.confirmed => t('statusConfirmed'),
      ReservationStatus.cancelled => t('statusCancelled'),
      ReservationStatus.pending => t('statusPending'),
    };
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
