import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../data/repositories/api_item_cost_repository.dart';
import 'menu_load_view.dart';

class MenuItemCostPanel extends StatefulWidget {
  const MenuItemCostPanel({super.key, required this.itemId});
  final String itemId;

  @override
  State<MenuItemCostPanel> createState() => _MenuItemCostPanelState();
}

class _MenuItemCostPanelState extends State<MenuItemCostPanel> {
  Future<ItemCost?>? _cost;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MenuItemCostPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId) _load();
  }

  void _load() {
    if (sl.isRegistered<ApiItemCostRepository>()) {
      _cost = sl<ApiItemCostRepository>().getCost(widget.itemId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cost = _cost;
    if (cost == null) return const SizedBox.shrink();
    return MenuLoadView<ItemCost?>(
      future: cost,
      onRetry: () => setState(_load),
      builder: (summary) => summary == null
          ? const ListTile(title: Text('مفيش تكلفة مسجلة للصنف'))
          : Column(
              children: [
                _metric('التكلفة', summary.amount, 'ج.م'),
                _metric('إجمالي الربح', summary.grossProfit, 'ج.م'),
                _metric('نسبة تكلفة المكونات', summary.foodCostPercent, '%'),
              ],
            ),
    );
  }

  Widget _metric(String label, double amount, String unit) => ListTile(
    title: Text(label),
    subtitle: Text('${amount.toStringAsFixed(2)} $unit'),
  );
}
