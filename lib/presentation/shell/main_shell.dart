import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/ready_to_pay/ready_to_pay_screen.dart';
import 'package:restaurantwaiter/presentation/blocs/reservations/active_reservations_screen.dart';
import 'package:restaurantwaiter/presentation/blocs/table_layout/table_organizer_screen.dart';

/// Root shell with bottom navigation. Replaces the previous drawer-only layout.
/// Tabs: 0 = Reservas activas | 1 = Configurar mesas | 2 = Listos para pagar
class MainShell extends StatefulWidget {
  final int initialTab;

  const MainShell({super.key, this.initialTab = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _selectedIndex;

  // Keep pages alive by building them once.
  static final List<Widget> _pages = [
    const ActiveReservationsScreen(),
    const TableOrganizerScreen(),
    const ReadyToPayScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.event_note_rounded),
            selectedIcon: Icon(Icons.event_note_rounded, color: theme.colorScheme.primary),
            label: t('navReservations'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded, color: theme.colorScheme.primary),
            label: t('navConfigTables'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.payments_rounded),
            selectedIcon: Icon(Icons.payments_rounded, color: theme.colorScheme.primary),
            label: t('navReadyToPay'),
          ),
        ],
      ),
    );
  }
}
