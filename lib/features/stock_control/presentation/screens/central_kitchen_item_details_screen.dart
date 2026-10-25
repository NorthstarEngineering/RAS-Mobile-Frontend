import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../data/stock_preview_data.dart';
import '../../domain/entities/stock_item.dart';
import '../widgets/stock_widgets.dart';

class CentralKitchenItemDetailsScreen extends StatelessWidget {
  const CentralKitchenItemDetailsScreen({super.key, required this.itemId});
  final String itemId;

  StockItem get _item => StockPreviewData.centralKitchenItems.firstWhere(
    (item) => item.id == itemId,
    orElse: () => StockPreviewData.centralKitchenItems.first,
  );

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return StockPageShell(
      title: 'تفاصيل الصنف',
      showNavigation: false,
      child: StockScrollBody(
        children: [
          if (item.level == StockLevel.critical) _criticalBanner(item),
          _identityCard(item),
          const SizedBox(height: 12),
          _metrics(item),
          const SizedBox(height: 16),
          _capacity(item),
          const SizedBox(height: 16),
          _specifications(item),
          const SizedBox(height: 16),
          _recent(context),
          const SizedBox(height: 16),
          _actions(context, item),
        ],
      ),
    );
  }

  Widget _criticalBanner(StockItem item) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: AppColors.errorContainer,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        child: Text(
          'تنبيه مخزون حرج • عجز ${_missing(item)} ${item.unit} لتغطية حد الأمان',
        ),
      ),
    ),
  );

  Widget _identityCard(StockItem item) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.category, style: const TextStyle(color: AppColors.primary)),
          Text(
            item.name,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          Text(item.sku, style: const TextStyle(color: AppColors.secondary)),
          const Divider(),
          Text('الموقع: ${item.location}'),
        ],
      ),
    ),
  );

  Widget _metrics(StockItem item) => Row(
    children: [
      Expanded(
        child: StockMetricCard(
          label: 'الكمية الحالية',
          value: '${_quantity(item.quantity)} ${item.unit}',
          color: AppColors.error,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: StockMetricCard(
          label: 'تكلفة الوحدة',
          value: '${item.unitCost.toStringAsFixed(2)} ج.م',
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: StockMetricCard(
          label: 'قيمة المخزون',
          value: '${_money(item.totalValue)} ج.م',
        ),
      ),
    ],
  );

  Widget _capacity(StockItem item) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StockSectionTitle('مستوى الامتلاء وسعة المستودع'),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (item.quantity / item.capacity).clamp(0, 1),
            minHeight: 9,
            color: AppColors.primary,
          ),
          const SizedBox(height: 8),
          Text(
            'الرصيد ${_quantity(item.quantity)} ${item.unit} • حد الأمان ${_quantity(item.safetyStock)} • السعة ${_quantity(item.capacity)}',
          ),
        ],
      ),
    ),
  );

  Widget _specifications(StockItem item) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StockSectionTitle('المواصفات والبيانات التشغيلية'),
          const SizedBox(height: 10),
          Text('وحدة القياس: ${item.unit}'),
          const Divider(height: 16),
          const Text('معدل الصرف اليومي: 45 كجم / يوم'),
          const Divider(height: 16),
          const Text('آخر توريد وارد: 14 أبريل 2024 • 100 كجم'),
          const Divider(height: 16),
          const Text('صلاحية الدفعة الحالية: 18 يوماً متبقية'),
        ],
      ),
    ),
  );

  Widget _recent(BuildContext context) => Column(
    children: [
      StockSectionTitle(
        'سجل حركات المخزون',
        trailing: TextButton(
          onPressed: () => context.push('/kitchen/movements'),
          child: const Text('عرض الكل'),
        ),
      ),
      for (final movement in StockPreviewData.centralMovements.take(3))
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: StockMovementCard(movement: movement),
        ),
    ],
  );

  Widget _actions(BuildContext context, StockItem item) => Column(
    children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => context.push('/kitchen/items/create'),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('تعديل بيانات الصنف'),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => context.push('/inventory/adjust/${item.id}'),
          icon: const Icon(Icons.tune),
          label: const Text('إذن صرف يدوي / تعديل الرصيد'),
        ),
      ),
    ],
  );

  String _quantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  String _money(double value) => value.toStringAsFixed(0);
  String _missing(StockItem item) =>
      _quantity((item.safetyStock - item.quantity).clamp(0, item.safetyStock));
}
