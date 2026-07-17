import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/domain/models/table_layout.dart';
import 'package:restaurantwaiter/domain/repositories/table_layout_repository.dart';
import 'package:restaurantwaiter/domain/repositories/table_qr_repository.dart';
import 'package:restaurantwaiter/infrastructure/services/table_qr_pdf_service.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/auth_state.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/authevent.dart';
import 'package:restaurantwaiter/presentation/blocs/table_layout/table_layout_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/table_layout/table_layout_state.dart';
import 'package:restaurantwaiter/presentation/widgets/admin_guard.dart';
import 'package:restaurantwaiter/presentation/widgets/branch_guard.dart';

class TableOrganizerScreen extends StatelessWidget {
  const TableOrganizerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appConfig = context.read<AppConfigCubit>().state;
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return AdminGuard(
      child: BranchGuard(
        child: BlocProvider(
          key: ValueKey('table-layout-${appConfig.branchId}'),
          create: (_) => TableLayoutCubit(
            repository: context.read<TableLayoutRepository>(),
            branchId: appConfig.branchId,
            accessToken: authState.waiter.token,
          )..load(),
          child: const _TableOrganizerView(),
        ),
      ),
    );
  }
}

class _TableOrganizerView extends StatelessWidget {
  const _TableOrganizerView();

  static const double _elementSize = 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
        title: Text(
          t('tableOrganizerTitle'),
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          BlocBuilder<TableLayoutCubit, TableLayoutState>(
            builder: (context, state) {
              return TextButton.icon(
                onPressed: state.status != TableLayoutStatus.ready
                    ? null
                    : () => _exportQrPdf(context),
                icon: Icon(Icons.qr_code_2_rounded,
                    color: theme.colorScheme.onPrimary),
                label: Text(
                  t('tableOrganizerQrPdf'),
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                ),
              );
            },
          ),
          BlocBuilder<TableLayoutCubit, TableLayoutState>(
            builder: (context, state) {
              return TextButton.icon(
                onPressed: state.saving ? null : () => _save(context),
                icon: state.saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Icon(Icons.save_rounded, color: theme.colorScheme.onPrimary),
                label: Text(
                  t('tableOrganizerSave'),
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<TableLayoutCubit, TableLayoutState>(
        builder: (context, state) {
          if (state.status == TableLayoutStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == TableLayoutStatus.error) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text(t('menuLoadError')),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.read<TableLayoutCubit>().load(),
                    child: Text(t('waiterRetry')),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              _Palette(),
              _FloorSelector(
                currentFloor: state.selectedFloor,
                floorCount: state.floorCount,
                onFloorChanged: (f) =>
                    context.read<TableLayoutCubit>().selectFloor(f),
                onAddFloor: () =>
                    context.read<TableLayoutCubit>().addFloor(),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: state.floorElements.isEmpty
                        ? _EmptyCanvasHint()
                        : Stack(
                            children: state.floorElements
                                .map((e) => _DraggableElement(
                                      element: e,
                                      table: e.isTable
                                          ? state.tables
                                              .where((t) => t.tableId == e.id)
                                              .firstOrNull
                                          : null,
                                      size: _elementSize,
                                    ))
                                .toList(),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final t = context.read<AppConfigCubit>().translate;
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final ok = await context.read<TableLayoutCubit>().save();
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? t('tableOrganizerSaved') : t('tableOrganizerSaveError')),
        backgroundColor: ok ? null : theme.colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _exportQrPdf(BuildContext context) async {
    final t = context.read<AppConfigCubit>().translate;
    final appConfig = context.read<AppConfigCubit>().state;
    final authState = context.read<AuthCubit>().state;
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    if (authState is! AuthAuthenticated) return;

    try {
      final tokens = await context.read<TableQrRepository>().getBranchTokens(
            branchId: appConfig.branchId,
            accessToken: authState.waiter.token,
          );

      if (tokens.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(t('tableOrganizerQrNoTables')),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await TableQrPdfService().printBranchQrPdf(
        branchName: appConfig.branchName,
        tokens: tokens,
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(t('tableOrganizerQrError')),
          backgroundColor: theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _FloorSelector extends StatelessWidget {
  final int currentFloor;
  final int floorCount;
  final ValueChanged<int> onFloorChanged;
  final VoidCallback onAddFloor;

  const _FloorSelector({
    required this.currentFloor,
    required this.floorCount,
    required this.onFloorChanged,
    required this.onAddFloor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text(t('floor'), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          ...List.generate(
            floorCount,
            (i) {
              final f = i + 1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$f'),
                  selected: currentFloor == f,
                  onSelected: (_) => onFloorChanged(f),
                ),
              );
            },
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onAddFloor,
            icon: const Icon(Icons.add_rounded),
            label: Text(t('tableOrganizerAddFloor')),
          ),
        ],
      ),
    );
  }
}

class _Palette extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;
    final cubit = context.read<TableLayoutCubit>();

    final items = <_PaletteItem>[
      _PaletteItem(LayoutElementType.table, Icons.table_restaurant_rounded, t('tableOrganizerAddTable')),
      _PaletteItem(LayoutElementType.entrance, Icons.door_front_door_rounded, t('tableElementEntrance')),
      _PaletteItem(LayoutElementType.exit, Icons.exit_to_app_rounded, t('tableElementExit')),
      _PaletteItem(LayoutElementType.reception, Icons.room_service_rounded, t('tableElementReception')),
      _PaletteItem(LayoutElementType.bar, Icons.local_bar_rounded, t('tableElementBar')),
      _PaletteItem(LayoutElementType.kitchen, Icons.soup_kitchen_rounded, t('tableElementKitchen')),
      _PaletteItem(LayoutElementType.restroom, Icons.wc_rounded, t('tableElementRestroom')),
      _PaletteItem(LayoutElementType.stairs, Icons.stairs_rounded, t('tableElementStairs')),
      _PaletteItem(LayoutElementType.elevator, Icons.elevator_rounded, t('tableElementElevator')),
      _PaletteItem(LayoutElementType.counter, Icons.countertops_rounded, t('tableElementCounter')),
    ];

    return Container(
      height: 68,
      color: theme.colorScheme.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => cubit.addElement(item.type, item.label),
              child: Container(
                width: 56,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PaletteItem {
  final LayoutElementType type;
  final IconData icon;
  final String label;
  _PaletteItem(this.type, this.icon, this.label);
}

class _EmptyCanvasHint extends StatelessWidget {
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
            Icon(Icons.touch_app_rounded,
                size: 48,
                color: theme.colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              t('tableOrganizerEmptyHint'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraggableElement extends StatelessWidget {
  final LayoutElement element;
  final LayoutTable? table;
  final double size;

  const _DraggableElement({
    required this.element,
    this.table,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<TableLayoutCubit>();

    return Positioned(
      left: element.x,
      top: element.y,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) =>
            cubit.moveElement(element.id, details.delta.dx, details.delta.dy),
        onTap: () => _showElementSheet(context),
        child: element.isTable
            ? _TableChip(
                tableNumber: table?.tableNumber ?? int.tryParse(element.label) ?? 0,
                capacity: table?.capacity ?? 4,
                size: size,
                theme: theme,
              )
            : _FixtureChip(element: element, size: size, theme: theme),
      ),
    );
  }

  void _showElementSheet(BuildContext context) {
    final cubit = context.read<TableLayoutCubit>();
    final table =
        cubit.state.tables.where((t) => t.tableId == element.id).firstOrNull;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: table != null
            ? _TableEditSheet(
                tableId: table.tableId,
                initialTableNumber: table.tableNumber,
                initialCapacity: table.capacity,
                canDelete: table.isPending,
              )
            : _ElementLabelSheet(
                elementId: element.id,
                initialLabel: element.label,
                canDelete: true,
              ),
      ),
    );
  }
}

class _ElementLabelSheet extends StatefulWidget {
  final String elementId;
  final String initialLabel;
  final bool canDelete;

  const _ElementLabelSheet({
    required this.elementId,
    required this.initialLabel,
    required this.canDelete,
  });

  @override
  State<_ElementLabelSheet> createState() => _ElementLabelSheetState();
}

class _ElementLabelSheetState extends State<_ElementLabelSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLabel);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    context
        .read<TableLayoutCubit>()
        .renameElement(widget.elementId, _controller.text.trim());
    Navigator.pop(context);
  }

  void _delete() {
    context.read<TableLayoutCubit>().removeElement(widget.elementId);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.read<AppConfigCubit>().translate;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _apply(),
              decoration: InputDecoration(
                labelText: t('tableOrganizerLabel'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.canDelete)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(t('tableOrganizerDelete')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (widget.canDelete) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _apply,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(t('tableOrganizerApply')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TableEditSheet extends StatefulWidget {
  final String tableId;
  final int initialTableNumber;
  final int initialCapacity;
  final bool canDelete;

  const _TableEditSheet({
    required this.tableId,
    required this.initialTableNumber,
    required this.initialCapacity,
    required this.canDelete,
  });

  @override
  State<_TableEditSheet> createState() => _TableEditSheetState();
}

class _TableEditSheetState extends State<_TableEditSheet> {
  late final TextEditingController _numberController;
  late final TextEditingController _capacityController;

  @override
  void initState() {
    super.initState();
    _numberController =
        TextEditingController(text: '${widget.initialTableNumber}');
    _capacityController =
        TextEditingController(text: '${widget.initialCapacity}');
  }

  @override
  void dispose() {
    _numberController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  void _apply() {
    final number = int.tryParse(_numberController.text.trim());
    final capacity = int.tryParse(_capacityController.text.trim());
    if (number == null || number < 1 || capacity == null || capacity < 1) {
      return;
    }
    context.read<TableLayoutCubit>().updateTable(
          widget.tableId,
          tableNumber: number,
          capacity: capacity,
        );
    Navigator.pop(context);
  }

  void _delete() {
    context.read<TableLayoutCubit>().removeElement(widget.tableId);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.read<AppConfigCubit>().translate;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _numberController,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: t('tableOrganizerTableNumber'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _capacityController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _apply(),
              decoration: InputDecoration(
                labelText: t('tableOrganizerCapacity'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.canDelete)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(t('tableOrganizerDelete')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (widget.canDelete) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _apply,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(t('tableOrganizerApply')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chips ─────────────────────────────────────────────────────────────────────

class _TableChip extends StatelessWidget {
  final int tableNumber;
  final int capacity;
  final double size;
  final ThemeData theme;

  const _TableChip({
    required this.tableNumber,
    required this.capacity,
    required this.size,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.table_restaurant_rounded,
                color: theme.colorScheme.onPrimary, size: 16),
            Text(
              '$tableNumber',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
            Text(
              '${capacity}p',
              style: TextStyle(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FixtureChip extends StatelessWidget {
  final LayoutElement element;
  final double size;
  final ThemeData theme;

  const _FixtureChip({required this.element, required this.size, required this.theme});

  static IconData _iconFor(LayoutElementType type) => switch (type) {
        LayoutElementType.entrance    => Icons.door_front_door_rounded,
        LayoutElementType.exit        => Icons.exit_to_app_rounded,
        LayoutElementType.reception   => Icons.room_service_rounded,
        LayoutElementType.bar         => Icons.local_bar_rounded,
        LayoutElementType.kitchen     => Icons.soup_kitchen_rounded,
        LayoutElementType.restroom    => Icons.wc_rounded,
        LayoutElementType.stairs      => Icons.stairs_rounded,
        LayoutElementType.elevator    => Icons.elevator_rounded,
        LayoutElementType.counter     => Icons.countertops_rounded,
        LayoutElementType.table       => Icons.table_restaurant_rounded,
      };

  static Color _accentFor(LayoutElementType type) => switch (type) {
        LayoutElementType.entrance    => const Color(0xFF4CAF50),
        LayoutElementType.exit        => const Color(0xFFF44336),
        LayoutElementType.reception   => const Color(0xFF9C27B0),
        LayoutElementType.bar         => const Color(0xFFFF9800),
        LayoutElementType.kitchen     => const Color(0xFFE91E63),
        LayoutElementType.restroom    => const Color(0xFF2196F3),
        LayoutElementType.stairs      => const Color(0xFF795548),
        LayoutElementType.elevator    => const Color(0xFF607D8B),
        LayoutElementType.counter     => const Color(0xFF009688),
        LayoutElementType.table       => const Color(0xFF3F51B5),
      };

  @override
  Widget build(BuildContext context) {
    final color = _accentFor(element.type);
    return Container(
      width: size + 8,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_iconFor(element.type), color: Colors.white, size: 16),
          const SizedBox(height: 1),
          Text(
            element.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
