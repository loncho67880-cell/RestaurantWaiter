import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/core/utils/reservation_datetime.dart';
import 'package:restaurantwaiter/domain/models/reservation.dart';
import 'package:restaurantwaiter/domain/models/table_session_snapshot.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';
import 'package:restaurantwaiter/domain/models/table_session_participant.dart';
import 'package:restaurantwaiter/domain/repositories/table_session_repository.dart';
import 'package:restaurantwaiter/infrastructure/services/table_session_realtime_service.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/authevent.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/auth_state.dart';
import 'package:restaurantwaiter/presentation/blocs/reservations/edit_participant_order_screen.dart';
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

class _ReservationDetailScreenState extends State<ReservationDetailScreen>
    with WidgetsBindingObserver {
  late Reservation _reservation;
  bool _confirmingArrival = false;
  bool _confirming = false;
  bool _markingReady = false;
  bool _cancelling = false;
  bool _refreshing = false;
  Timer? _liveRefreshFallbackTimer;
  StreamSubscription<TableSessionSnapshot>? _realtimeSub;

  bool get _needsLiveRefresh =>
      _reservation.isReadingQr || _reservation.hasTableSessionParticipants;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reservation = widget.reservation;
    if (_needsLiveRefresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshReservation();
        _startLiveSync();
      });
      _liveRefreshFallbackTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) {
          if (mounted) _refreshReservation(silent: true);
        },
      );
    }
  }

  @override
  void dispose() {
    _liveRefreshFallbackTimer?.cancel();
    _stopLiveSync();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _needsLiveRefresh) {
      _refreshReservation(silent: true);
    }
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

  bool _confirmingParticipant = false;

  Future<void> _confirmParticipant(String customerId) async {
    setState(() => _confirmingParticipant = true);
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return;

    try {
      await context.read<TableSessionRepository>().confirmParticipant(
            sessionId: _reservation.id,
            customerId: customerId,
            accessToken: authState.waiter.token,
          );
      await _refreshReservation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<AppConfigCubit>().translate(
                'waiterConfirmParticipantSuccess',
              )),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _confirmingParticipant = false);
    }
  }

  Future<void> _editParticipantOrder(TableSessionParticipant participant) async {
    await _refreshReservation(silent: true);
    if (!mounted) return;

    final freshParticipant = _reservation.participants
            .where((p) => p.customerId == participant.customerId)
            .firstOrNull ??
        participant;

    final updated = await Navigator.push<Reservation>(
      context,
      MaterialPageRoute(
        builder: (_) => EditParticipantOrderScreen(
          sessionId: _reservation.id,
          participant: freshParticipant,
          reservation: _reservation,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _reservation = updated);
      context.read<WaiterReservationsCubit>().replaceReservation(updated);
    } else if (mounted && _needsLiveRefresh) {
      await _refreshReservation(silent: true);
    }
  }

  Future<void> _refreshReservation({bool silent = false}) async {
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return;

    if (!silent) setState(() => _refreshing = true);

    try {
      final participants =
          await context.read<TableSessionRepository>().getParticipants(
                sessionId: _reservation.id,
                accessToken: authState.waiter.token,
              );
      if (!mounted) return;

      _applyParticipants(participants, silent: silent);
    } catch (_) {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _startLiveSync() async {
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return;

    final service = context.read<TableSessionRealtimeService>();
    try {
      service.setRefreshCallback(
        _reservation.id,
        () {
          if (mounted) _refreshReservation(silent: true);
        },
      );

      await _realtimeSub?.cancel();
      _realtimeSub = service.updatesFor(_reservation.id).listen(
        _onSessionSnapshot,
        onError: (Object error, StackTrace stack) {
          debugPrint('[ReservationDetail] realtime error: $error\n$stack');
        },
      );

      await service.watchSession(
        sessionId: _reservation.id,
        accessToken: authState.waiter.token,
      );

      final latest = service.latestSnapshot(_reservation.id);
      if (latest != null && mounted) {
        _onSessionSnapshot(latest);
      }
    } catch (error, stack) {
      debugPrint('[ReservationDetail] failed to start realtime: $error\n$stack');
    }
  }

  Future<void> _stopLiveSync() async {
    await _realtimeSub?.cancel();
    _realtimeSub = null;
    if (!mounted) return;
    try {
      final service = context.read<TableSessionRealtimeService>();
      service.clearRefreshCallback(_reservation.id);
      await service.unwatchSession(_reservation.id);
    } catch (_) {
      // Best effort during dispose.
    }
  }

  void _onSessionSnapshot(TableSessionSnapshot snapshot) {
    if (!mounted) return;
    _applyParticipants(
      snapshot.participants,
      allParticipantsConfirmed: snapshot.allParticipantsConfirmed,
      canFinalizeTable: snapshot.canFinalizeTable,
      silent: true,
    );
  }

  void _applyParticipants(
    List<TableSessionParticipant> participants, {
    bool? allParticipantsConfirmed,
    bool? canFinalizeTable,
    bool silent = false,
  }) {
    setState(() {
      _reservation = Reservation(
        id: _reservation.id,
        branchId: _reservation.branchId,
        tableId: _reservation.tableId,
        tableNumber: _reservation.tableNumber,
        floor: _reservation.floor,
        reservationDate: _reservation.reservationDate,
        guestCount: _reservation.guestCount,
        status: _reservation.status,
        preOrderStatus: _reservation.preOrderStatus,
        notes: _reservation.notes,
        customerName: _reservation.customerName,
        customerPhone: _reservation.customerPhone,
        items: participants.expand((p) => p.items).toList(),
        participants: participants,
        allParticipantsConfirmed: allParticipantsConfirmed ??
            (participants.isNotEmpty &&
                participants.every((p) => p.isOrderConfirmed)),
        canFinalizeTable: canFinalizeTable ??
            (participants.isNotEmpty &&
                participants.every((p) => p.isOrderConfirmed) &&
                _reservation.isReadingQr),
      );
      if (!silent) _refreshing = false;
    });
    context.read<WaiterReservationsCubit>().replaceReservation(_reservation);
  }

  Future<void> _editOrder() async {
    if (_reservation.isReadingQr || _reservation.hasTableSessionParticipants) {
      await _refreshReservation();
      if (!mounted) return;
      if (_reservation.isReadingQr || _reservation.hasTableSessionParticipants) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<AppConfigCubit>().translate(
                    'waiterEditOrderTableSessionHint',
                  ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

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
        actions: [
          if (_needsLiveRefresh)
            IconButton(
              onPressed: _refreshing ? null : () => _refreshReservation(),
              icon: _refreshing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      color: theme.colorScheme.onPrimary,
                    ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _needsLiveRefresh
            ? () => _refreshReservation()
            : () async {},
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
            if (_reservation.hasTableSessionParticipants) ...[
              const SizedBox(height: 16),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('tableSessionParticipantsTitle'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._reservation.participants.map(
                      (participant) => _ParticipantTile(
                        participant: participant,
                        onEdit: participant.isOrderConfirmed
                            ? null
                            : () => _editParticipantOrder(participant),
                        onConfirm: participant.isOrderConfirmed
                            ? null
                            : () => _confirmParticipant(participant.customerId),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
      ),
    );
  }

  String _statusLabel(
    String Function(String, {Map<String, String>? replacements}) t,
  ) {
    if (_reservation.isReadingQr) return t('statusReadingQr');
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

class _ParticipantTile extends StatelessWidget {
  final TableSessionParticipant participant;
  final VoidCallback? onEdit;
  final VoidCallback? onConfirm;

  const _ParticipantTile({
    required this.participant,
    this.onEdit,
    this.onConfirm,
  });

  String _statusLabel(String Function(String) t) {
    if (participant.isOrderConfirmed) {
      return t('participantStatusConfirmed');
    }
    if (participant.status == 'Ordenando') {
      return t('participantStatusOrdering');
    }
    return t('participantStatusReadingQr');
  }

  String _itemsSummary() {
    if (participant.items.isEmpty) return '—';
    return participant.items
        .map((i) => '${i.quantity} ${i.dishName}')
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;
    final textColor = theme.colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  participant.displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              Chip(
                label: Text(
                  _statusLabel(t),
                  style: TextStyle(
                    fontSize: 11,
                    color: participant.isOrderConfirmed
                        ? Colors.green.shade800
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                visualDensity: VisualDensity.compact,
                backgroundColor: participant.isOrderConfirmed
                    ? Colors.green.withValues(alpha: 0.12)
                    : theme.colorScheme.primaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _itemsSummary(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor.withValues(alpha: 0.75),
            ),
          ),
          if (onEdit != null || onConfirm != null) ...[
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (onEdit != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(t('editParticipantOrderBtn')),
                    ),
                  ),
                if (onConfirm != null)
                  FilledButton.tonal(
                    onPressed: onConfirm,
                    child: Text(
                      t('confirmParticipantOrderBtn', replacements: {
                        'name': participant.displayName,
                      }),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
