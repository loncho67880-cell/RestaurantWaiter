import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/core/utils/reservation_datetime.dart';
import 'package:restaurantwaiter/domain/models/reservation.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/reservations/edit_reservation_order_screen.dart';
import 'package:restaurantwaiter/presentation/blocs/reservations/waiter_reservations_cubit.dart';
import 'package:url_launcher/url_launcher.dart';

/// Result of the reservation detail screen.
sealed class ReservationDetailResult {}

class ReservationDetailUpdated extends ReservationDetailResult {
  final Reservation reservation;
  ReservationDetailUpdated(this.reservation);
}

class ReservationDetailCancelled extends ReservationDetailResult {}

class ReservationDetailScreen extends StatefulWidget {
  final Reservation reservation;

  const ReservationDetailScreen({super.key, required this.reservation});

  @override
  State<ReservationDetailScreen> createState() => _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  late Reservation _reservation;
  bool _confirmingArrival = false;
  bool _confirming = false;
  bool _markingReady = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _reservation = widget.reservation;
  }

  Future<void> _callCustomer(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: digits);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _confirmArrival() async {
    setState(() => _confirmingArrival = true);
    final cubit = context.read<WaiterReservationsCubit>();
    final t = context.read<AppConfigCubit>().translate;
    final errorKey = await cubit.confirmArrival(_reservation.id);
    if (!mounted) return;
    setState(() => _confirmingArrival = false);

    if (errorKey == null) {
      final updated = cubit.state.reservations
          .where((r) => r.id == _reservation.id)
          .firstOrNull;
      if (updated != null) setState(() => _reservation = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('waiterConfirmArrivalSuccess')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(t(errorKey));
    }
  }

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    final cubit = context.read<WaiterReservationsCubit>();
    final t = context.read<AppConfigCubit>().translate;
    final errorKey = await cubit.confirm(_reservation.id);
    if (!mounted) return;
    setState(() => _confirming = false);

    if (errorKey == null) {
      final updated = cubit.state.reservations
          .where((r) => r.id == _reservation.id)
          .firstOrNull;
      if (updated != null) setState(() => _reservation = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('waiterConfirmSuccess')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(t(errorKey));
    }
  }

  Future<void> _markReady() async {
    setState(() => _markingReady = true);
    final cubit = context.read<WaiterReservationsCubit>();
    final t = context.read<AppConfigCubit>().translate;
    final errorKey = await cubit.markReadyForPayment(_reservation.id);
    if (!mounted) return;
    setState(() => _markingReady = false);

    if (errorKey == null) {
      Navigator.pop(context, ReservationDetailCancelled());
    } else {
      _showError(t(errorKey));
    }
  }

  Future<void> _cancel() async {
    final t = context.read<AppConfigCubit>().translate;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('cancelReservationTitle')),
        content: Text(t('cancelReservationWaiterMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('cancelReservationDismiss')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('cancelReservationConfirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    final errorKey =
        await context.read<WaiterReservationsCubit>().cancel(_reservation.id);
    if (!mounted) return;
    setState(() => _cancelling = false);

    if (errorKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('cancelReservationSuccess')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, ReservationDetailCancelled());
    } else {
      _showError(t(errorKey));
    }
  }

  Future<void> _editOrder() async {
    final updated = await Navigator.push<Reservation>(
      context,
      MaterialPageRoute(
        builder: (_) => EditReservationOrderScreen(reservation: _reservation),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _reservation = updated);
      context.read<WaiterReservationsCubit>().replaceReservation(updated);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: theme.colorScheme.onPrimary,
          onPressed: () => Navigator.pop(
            context,
            ReservationDetailUpdated(_reservation),
          ),
        ),
        title: Text(
          t('reservationDetailTitle'),
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('customerSectionTitle'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.person_rounded,
                    label: t('customerNameLabel'),
                    value: _reservation.hasCustomerContact
                        ? _reservation.customerName!
                        : t('walkInCustomerLabel'),
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.phone_rounded,
                    label: t('customerPhoneLabel'),
                    value: (_reservation.customerPhone?.trim().isNotEmpty ?? false)
                        ? _reservation.customerPhone!
                        : t('noPhoneAvailable'),
                  ),
                  if (_reservation.customerPhone?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _callCustomer(_reservation.customerPhone!),
                        icon: const Icon(Icons.call_rounded),
                        label: Text(t('callCustomerBtn')),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('reservationInfoTitle'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.table_restaurant_rounded,
                    label: t('tableLabel'),
                    value:
                        '${t('floor')} ${_reservation.floor} — ${t('tableNum')} ${_reservation.tableNumber}',
                  ),
                  _InfoRow(
                    icon: Icons.schedule_rounded,
                    label: t('dateLabel'),
                    value: formatReservationDateTime(
                      _reservation.reservationDate,
                      locale,
                    ),
                  ),
                  _InfoRow(
                    icon: Icons.people_rounded,
                    label: t('guestCount'),
                    value: '${_reservation.guestCount} ${t('persons')}',
                  ),
                  _InfoRow(
                    icon: Icons.info_outline_rounded,
                    label: t('statusLabel'),
                    value: _statusLabel(t),
                  ),
                  if (_reservation.notes != null &&
                      _reservation.notes!.isNotEmpty)
                    _InfoRow(
                      icon: Icons.notes_rounded,
                      label: t('notesLabel'),
                      value: _reservation.notes!,
                    ),
                ],
              ),
            ),
            if (_reservation.items.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('preOrderTitle'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._reservation.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Text(
                              '${item.quantity}×',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item.dishName)),
                            Text(
                              '\$${item.subtotal.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${t('preOrderTotal')} \$${_reservation.totalPreOrder.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (_reservation.canWaiterEditOrder) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _editOrder,
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(t('waiterEditOrderBtn')),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_reservation.canWaiterConfirmArrival) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _confirmingArrival ? null : _confirmArrival,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                  ),
                  icon: _confirmingArrival
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.event_seat_rounded),
                  label: Text(t('waiterConfirmArrivalBtn')),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_reservation.canWaiterConfirm) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _confirming ? null : _confirm,
                  icon: _confirming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.soup_kitchen_rounded),
                  label: Text(t('waiterConfirmBtn')),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_reservation.canMarkReadyForPayment) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _markingReady ? null : _markReady,
                  style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                  icon: _markingReady
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.payments_rounded),
                  label: Text(t('waiterMarkReadyBtn')),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_reservation.canWaiterCancel)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _cancelling ? null : _cancel,
                  icon: _cancelling
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.error,
                          ),
                        )
                      : Icon(Icons.cancel_outlined,
                          color: theme.colorScheme.error),
                  label: Text(
                    t('cancelReservationBtn'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.error),
                  ),
                ),
              ),
          ],
        ),
    );
  }

  String _statusLabel(
    String Function(String, {Map<String, String>? replacements}) t,
  ) {
    if (_reservation.isInPreparation) return t('statusInPreparation');
    if (_reservation.isAwaitingWaiter) return t('statusPendingWaiter');
    if (_reservation.canWaiterConfirmArrival) return t('statusAwaitingArrival');
    return switch (_reservation.status) {
      ReservationStatus.confirmed => t('statusConfirmed'),
      ReservationStatus.cancelled => t('statusCancelled'),
      ReservationStatus.pending => t('statusPending'),
    };
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
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
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
