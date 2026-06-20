import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/domain/models/table_layout.dart';
import 'package:restaurantwaiter/domain/repositories/table_layout_repository.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/table_layout/table_layout_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/table_layout/table_layout_state.dart';
import 'package:restaurantwaiter/presentation/widgets/branch_guard.dart';

class TableOrganizerScreen extends StatelessWidget {
  const TableOrganizerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appConfig = context.read<AppConfigCubit>().state;
    return BranchGuard(
      child: BlocProvider(
        create: (_) => TableLayoutCubit(
          repository: context.read<TableLayoutRepository>(),
          branchId: appConfig.branchId,
        )..load(),
        child: const _TableOrganizerView(),
      ),
    );
  }
}

class _TableOrganizerView extends StatelessWidget {
  const _TableOrganizerView();

  static const double _elementSize = 72;

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
          return Column(
            children: [
              _Palette(),
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
                    child: state.elements.isEmpty
                        ? _EmptyCanvasHint()
                        : Stack(
                            children: state.elements
                                .map((e) => _DraggableElement(
                                      element: e,
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
}

class _Palette extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.read<AppConfigCubit>().translate;
    final cubit = context.read<TableLayoutCubit>();

    final items = <_PaletteItem>[
      _PaletteItem(
        type: LayoutElementType.table,
        icon: Icons.table_restaurant_rounded,
        label: t('tableOrganizerAddTable'),
      ),
      _PaletteItem(
        type: LayoutElementType.entrance,
        icon: Icons.door_front_door_rounded,
        label: t('tableElementEntrance'),
      ),
      _PaletteItem(
        type: LayoutElementType.restroom,
        icon: Icons.wc_rounded,
        label: t('tableElementRestroom'),
      ),
      _PaletteItem(
        type: LayoutElementType.bar,
        icon: Icons.local_bar_rounded,
        label: t('tableElementBar'),
      ),
      _PaletteItem(
        type: LayoutElementType.kitchen,
        icon: Icons.soup_kitchen_rounded,
        label: t('tableElementKitchen'),
      ),
    ];

    return Container(
      height: 92,
      color: theme.colorScheme.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => cubit.addElement(item.type, item.label),
              child: Container(
                width: 76,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, color: theme.colorScheme.primary),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface,
                      ),
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

  _PaletteItem({required this.type, required this.icon, required this.label});
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
  final double size;

  const _DraggableElement({required this.element, required this.size});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<TableLayoutCubit>();

    return Positioned(
      left: element.x,
      top: element.y,
      child: GestureDetector(
        onPanUpdate: (details) =>
            cubit.moveElement(element.id, details.delta.dx, details.delta.dy),
        onTap: () => _showElementSheet(context),
        child: element.isTable
            ? _TableChip(label: element.label, size: size, theme: theme)
            : _FixtureChip(element: element, size: size, theme: theme),
      ),
    );
  }

  Future<void> _showElementSheet(BuildContext context) async {
    final t = context.read<AppConfigCubit>().translate;
    final cubit = context.read<TableLayoutCubit>();
    final controller = TextEditingController(text: element.label);

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: t('tableOrganizerLabel'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        cubit.removeElement(element.id);
                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(t('tableOrganizerDelete')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(sheetContext).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        cubit.renameElement(
                            element.id, controller.text.trim());
                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: Text(t('tableOrganizerApply')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
  }
}

class _TableChip extends StatelessWidget {
  final String label;
  final double size;
  final ThemeData theme;

  const _TableChip({
    required this.label,
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
                color: theme.colorScheme.onPrimary, size: 22),
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
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

  const _FixtureChip({
    required this.element,
    required this.size,
    required this.theme,
  });

  IconData get _icon => switch (element.type) {
        LayoutElementType.entrance => Icons.door_front_door_rounded,
        LayoutElementType.restroom => Icons.wc_rounded,
        LayoutElementType.bar => Icons.local_bar_rounded,
        LayoutElementType.kitchen => Icons.soup_kitchen_rounded,
        LayoutElementType.table => Icons.table_restaurant_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 12,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.9),
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
          Icon(_icon, color: Colors.white, size: 22),
          const SizedBox(height: 2),
          Text(
            element.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
