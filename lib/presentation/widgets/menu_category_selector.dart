import 'package:flutter/material.dart';
import 'package:restaurantwaiter/domain/models/category_menu.dart';

import 'menu_category_visual.dart';

/// Horizontal category picker with icon tiles — used across order screens.
class MenuCategorySelector extends StatelessWidget {
  final List<CategoryMenu> categories;
  final String selectedCategoryId;
  final ValueChanged<String> onCategorySelected;
  final EdgeInsetsGeometry padding;

  const MenuCategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final category = categories[index];
          return _CategoryTile(
            label: category.name,
            selected: category.id == selectedCategoryId,
            visual: MenuCategoryVisual.forName(category.name),
            onTap: () => onCategorySelected(category.id),
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final bool selected;
  final MenuCategoryVisual visual;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.selected,
    required this.visual,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final iconBg = selected
        ? primary
        : visual.accent.withValues(alpha: 0.12);
    final iconColor = selected ? theme.colorScheme.onPrimary : visual.accent;
    final labelColor =
        selected ? primary : theme.colorScheme.onSurface.withValues(alpha: 0.65);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(18),
                  border: selected
                      ? null
                      : Border.all(
                          color: visual.accent.withValues(alpha: 0.25),
                        ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(visual.icon, color: iconColor, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
