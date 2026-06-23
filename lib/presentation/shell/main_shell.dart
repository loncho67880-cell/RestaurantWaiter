import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/auth_state.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/authevent.dart';
import 'package:restaurantwaiter/presentation/blocs/ready_to_pay/ready_to_pay_screen.dart';
import 'package:restaurantwaiter/presentation/blocs/reservations/active_reservations_screen.dart';
import 'package:restaurantwaiter/presentation/blocs/table_layout/table_organizer_screen.dart';

/// Root shell with bottom navigation. Replaces the previous drawer-only layout.
/// Tabs: 0 = Reservas activas | [1 = Configurar mesas] | Por pagar
class MainShell extends StatefulWidget {
  final int initialTab;

  const MainShell({super.key, this.initialTab = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
  }

  List<Widget> _pages(bool isAdmin) => isAdmin
      ? const [
          ActiveReservationsScreen(),
          TableOrganizerScreen(),
          ReadyToPayScreen(),
        ]
      : const [
          ActiveReservationsScreen(),
          ReadyToPayScreen(),
        ];

  int _clampIndex(int index, int pageCount) =>
      index < 0 ? 0 : (index >= pageCount ? pageCount - 1 : index);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final isAdmin =
            authState is AuthAuthenticated && authState.waiter.isAdmin;
        final pages = _pages(isAdmin);
        final selectedIndex = _clampIndex(_selectedIndex, pages.length);

        if (selectedIndex != _selectedIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedIndex = selectedIndex);
          });
        }

        return Scaffold(
          body: IndexedStack(
            index: selectedIndex,
            children: pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            backgroundColor: theme.colorScheme.surface,
            indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.event_note_rounded),
                selectedIcon: Icon(Icons.event_note_rounded,
                    color: theme.colorScheme.primary),
                label: t('navReservations'),
              ),
              if (isAdmin)
                NavigationDestination(
                  icon: const Icon(Icons.grid_view_rounded),
                  selectedIcon: Icon(Icons.grid_view_rounded,
                      color: theme.colorScheme.primary),
                  label: t('navConfigTables'),
                ),
              NavigationDestination(
                icon: const Icon(Icons.payments_rounded),
                selectedIcon: Icon(Icons.payments_rounded,
                    color: theme.colorScheme.primary),
                label: t('navReadyToPay'),
              ),
            ],
          ),
        );
      },
    );
  }
}
