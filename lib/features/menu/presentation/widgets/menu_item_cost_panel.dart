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
      builder: _summary,
    );
  }

  Widget _summary(ItemCost? summary) => Column(
    children: [
      if (summary == null)
        const ListTile(title: Text('مفيش تكلفة مسجلة للصنف'))
      else ...[
        _metric('التكلفة', summary.amount, 'ج.م'),
        _metric('إجمالي الربح', summary.grossProfit, 'ج.م'),
        _metric('نسبة تكلفة المكونات', summary.foodCostPercent, '%'),
      ],
      OutlinedButton(
        onPressed: () => _edit(summary),
        child: const Text('تعديل تكلفة الصنف'),
      ),
    ],
  );

  Future<void> _edit(ItemCost? summary) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => _CostAmountDialog(initialAmount: summary?.amount),
    );
    if (!mounted || amount == null) return;
    setState(() {
      _cost = sl<ApiItemCostRepository>().updateAmount(widget.itemId, amount);
    });
  }

  Widget _metric(String label, double amount, String unit) => ListTile(
    title: Text(label),
    subtitle: Text('${amount.toStringAsFixed(2)} $unit'),
  );
}

class _CostAmountDialog extends StatefulWidget {
  const _CostAmountDialog({required this.initialAmount});
  final double? initialAmount;
  @override
  State<_CostAmountDialog> createState() => _CostAmountDialogState();
}

class _CostAmountDialogState extends State<_CostAmountDialog> {
  final _form = GlobalKey<FormState>();
  double? _amount;

  String? _validate(String? input) {
    final value = double.tryParse(input?.trim() ?? '');
    if (value == null || !value.isFinite || value <= 0) {
      return 'أدخل تكلفة أكبر من صفر';
    }
    _amount = value;
    return null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('تعديل تكلفة الصنف'),
    content: Form(
      key: _form,
      child: TextFormField(
        initialValue: widget.initialAmount?.toStringAsFixed(2),
        decoration: const InputDecoration(labelText: 'التكلفة بالجنيه'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: _validate,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) Navigator.pop(context, _amount);
        },
        child: const Text('حفظ'),
      ),
    ],
  );
}
