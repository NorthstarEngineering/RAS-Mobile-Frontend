import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/entities/stock_movement.dart';

class StockPageShell extends StatelessWidget {
  const StockPageShell({
    super.key,
    required this.title,
    required this.child,
    this.tab = 0,
    this.showNavigation = true,
  });

  final String title;
  final Widget child;
  final int tab;
  final bool showNavigation;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      title: Text(title),
      actions: const [Icon(Icons.notifications_none), SizedBox(width: 14)],
    ),
    body: SafeArea(child: child),
    bottomNavigationBar: showNavigation
        ? StockBottomNavigation(selectedIndex: tab)
        : null,
  );
}

class StockBottomNavigation extends StatelessWidget {
  const StockBottomNavigation({super.key, required this.selectedIndex});
  final int selectedIndex;

  static const _paths = [
    '/kitchen',
    '/kitchen/items',
    '/kitchen/movements',
    '/inventory',
    '/inventory/value',
  ];
  static const _labels = [
    'الرئيسية',
    'الأصناف',
    'الحركات',
    'المخزون',
    'القيمة',
  ];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.inventory_2_outlined,
    Icons.swap_horiz,
    Icons.warehouse_outlined,
    Icons.analytics_outlined,
  ];

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: (index) => context.go(_paths[index]),
    destinations: List.generate(
      _paths.length,
      (index) => NavigationDestination(
        icon: Icon(_icons[index]),
        label: _labels[index],
      ),
    ),
  );
}

class StockScrollBody extends StatelessWidget {
  const StockScrollBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(AppDimens.paddingMd),
  });
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class StockSectionTitle extends StatelessWidget {
  const StockSectionTitle(this.title, {super.key, this.trailing, this.icon});
  final String title;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (icon != null) ...[
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
      ],
      Expanded(
        child: Text(
          title,
          style: AppTypography.headlineSm.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      ?trailing,
    ],
  );
}

class StockMetricCard extends StatelessWidget {
  const StockMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppDimens.paddingMd),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null)
          Icon(icon, color: color ?? AppColors.primary, size: 20),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: AppTypography.headlineSm.copyWith(
            color: color ?? AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class StockItemCard extends StatelessWidget {
  const StockItemCard({super.key, required this.item, required this.onTap});
  final StockItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: AppColors.surfaceContainerLowest,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                StockLevelBadge(level: item.level),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${item.sku} • ${item.category}',
              style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
            ),
            const Divider(height: 18),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppDimens.paddingMd,
              runSpacing: AppDimens.paddingSm,
              children: [
                Text(
                  '${_format(item.quantity)} ${item.unit}',
                  style: AppTypography.headlineSm.copyWith(
                    color: _levelColor(item.level),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'التكلفة ${_format(item.unitCost)} ج.م / ${item.unit}',
                  style: AppTypography.labelSm,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class StockLevelBadge extends StatelessWidget {
  const StockLevelBadge({super.key, required this.level});
  final StockLevel level;

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(level);
    final label = switch (level) {
      StockLevel.critical => 'حرج',
      StockLevel.low => 'مخزون منخفض',
      StockLevel.available => 'متوفر',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(label, style: AppTypography.labelSm.copyWith(color: color)),
    );
  }
}

class StockMovementCard extends StatelessWidget {
  const StockMovementCard({super.key, required this.movement});
  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final color = _movementColor(movement.type);
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border(right: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${movement.code} • ${movement.time}',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ),
              Text(
                movement.quantityLabel,
                style: AppTypography.labelMd.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            movement.itemName,
            style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '${movement.sku} • ${movement.description}',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class StockFilterChips extends StatelessWidget {
  const StockFilterChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: labels
          .map(
            (label) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: selected == label,
                onSelected: (_) => onSelected(label),
              ),
            ),
          )
          .toList(),
    ),
  );
}

Color _levelColor(StockLevel level) => switch (level) {
  StockLevel.critical => AppColors.error,
  StockLevel.low => AppColors.warning,
  StockLevel.available => AppColors.success,
};

Color _movementColor(StockMovementType type) => switch (type) {
  StockMovementType.issue => AppColors.error,
  StockMovementType.receipt => AppColors.success,
  StockMovementType.transfer => AppColors.tertiary,
  StockMovementType.adjustment => AppColors.secondary,
};

String _format(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
