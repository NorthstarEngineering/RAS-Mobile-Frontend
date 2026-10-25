import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../data/stock_preview_data.dart';
import '../../domain/entities/stock_item.dart';
import '../widgets/stock_widgets.dart';

class InventoryItemDetailsScreen extends StatelessWidget {
  const InventoryItemDetailsScreen({super.key, required this.itemId});
  final String itemId;

  StockItem get _item => StockPreviewData.branchItems.firstWhere(
    (item) => item.id == itemId,
    orElse: () => StockPreviewData.branchItems.first,
  );

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return StockPageShell(
      title: 'تفاصيل المخزون',
      showNavigation: false,
      child: StockScrollBody(
        children: [
          if (item.level == StockLevel.critical) _warning(item),
          _identity(item),
          const SizedBox(height: 12),
          _metrics(item),
          const SizedBox(height: 14),
          _stockLevel(item),
          const SizedBox(height: 14),
          _operations(item),
          const SizedBox(height: 14),
          _movements(),
          const SizedBox(height: 14),
          _actions(context, item),
        ],
      ),
    );
  }

  Widget _warning(StockItem item) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: AppColors.errorContainer,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        child: Text(
          'تنبيه نقص المخزون الحرج • الرصيد ${_quantity(item.quantity)} ${item.unit} أقل من حد الأمان المعتمد.',
        ),
      ),
    ),
  );

  Widget _identity(StockItem item) => Card(
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
          Text('رمز الصنف (SKU) • ${item.sku}'),
          const Divider(),
          Text('الموقع: ${item.location}'),
        ],
      ),
    ),
  );

  Widget _metrics(StockItem item) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: StockMetricCard(
              label: 'الكمية الحالية',
              value: '${_quantity(item.quantity)} ${item.unit}',
              color: item.level == StockLevel.critical
                  ? AppColors.error
                  : AppColors.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StockMetricCard(
              label: 'حد الأمان',
              value: '${_quantity(item.safetyStock)} ${item.unit}',
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
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
              value: '${item.totalValue.toStringAsFixed(0)} ج.م',
            ),
          ),
        ],
      ),
    ],
  );

  Widget _stockLevel(StockItem item) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StockSectionTitle('مؤشر الاستيعاب وإعادة الطلب'),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (item.quantity / item.capacity).clamp(0, 1),
            minHeight: 9,
          ),
          const SizedBox(height: 8),
          Text(
            'السعة القصوى ${_quantity(item.capacity)} ${item.unit} • الإشغال الفعلي ${((item.quantity / item.capacity) * 100).round()}%',
          ),
        ],
      ),
    ),
  );

  Widget _operations(StockItem item) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StockSectionTitle('البيانات الفنية والتشغيلية'),
          const SizedBox(height: 8),
          Text('وحدة القياس المعتمدة: ${item.unit}'),
          const Divider(height: 18),
          const Text('متوسط الاستهلاك اليومي: 25 كجم / يوم'),
          const Divider(height: 18),
          const Text('آخر استلام توريد: اليوم 08:30 ص'),
        ],
      ),
    ),
  );

  Widget _movements() => Column(
    children: [
      const StockSectionTitle('آخر حركات المخزون'),
      for (final movement in StockPreviewData.branchMovements.take(3))
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
          onPressed: () => context.push('/inventory/adjust/${item.id}'),
          icon: const Icon(Icons.tune),
          label: const Text('إجراء تسوية مخزنية'),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => context.push('/inventory/movements'),
          icon: const Icon(Icons.list_alt),
          label: const Text('سجل الحركات التفصيلي'),
        ),
      ),
    ],
  );

  String _quantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}
