import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/stock_preview_data.dart';
import '../../domain/entities/stock_item.dart';
import '../widgets/stock_widgets.dart';

class InventoryValueScreen extends StatelessWidget {
  const InventoryValueScreen({super.key});

  static const _groups = [
    ('اللحوم والدواجن', 32840.0, 51, '8 أصناف • 180 كجم'),
    ('الأجبان ومنتجات الألبان', 14200.0, 22, '6 أصناف • 65 كجم'),
    ('الصوصات والزيوت', 9850.0, 15, '12 صنف • 110 لتر'),
    ('المخبوزات والجاف', 7390.0, 12, '12 صنف • 520 قطعة'),
  ];

  @override
  Widget build(BuildContext context) => StockPageShell(
    title: 'تقييم قيمة المخزون',
    tab: 4,
    child: StockScrollBody(
      children: [
        _evaluationNote(),
        const SizedBox(height: 12),
        _totalValue(),
        const SizedBox(height: 12),
        _summaryMetrics(),
        const SizedBox(height: 16),
        _categoryValues(),
        const SizedBox(height: 16),
        _highestValueItems(context),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _exportNotice(context),
          icon: const Icon(Icons.ios_share),
          label: const Text('تصدير كشف تقييم المخزون (PDF / Excel)'),
        ),
        TextButton.icon(
          onPressed: () => context.go('/inventory'),
          icon: const Icon(Icons.arrow_back),
          label: const Text('العودة لقائمة المخزون'),
        ),
      ],
    ),
  );

  Widget _evaluationNote() => Container(
    padding: const EdgeInsets.all(AppDimens.paddingMd),
    decoration: BoxDecoration(
      color: AppColors.errorContainer,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
    ),
    child: const Text(
      'قيمة المخزون تمثل رأس المال المقيد في خامات الفرع، ولا تمثل إيرادات أو مبيعات نقدية.',
    ),
  );

  Widget _totalValue() => Container(
    padding: const EdgeInsets.all(AppDimens.paddingLg),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إجمالي القيمة التكلفية للمخزون',
          style: TextStyle(color: Colors.white),
        ),
        SizedBox(height: 6),
        Text(
          '64,280 ج.م',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '+4.2% مقارنة بالجرد السابق • +2,600 ج.م توريدات جديدة',
          style: TextStyle(color: Colors.white),
        ),
      ],
    ),
  );

  Widget _summaryMetrics() => const Row(
    children: [
      Expanded(
        child: StockMetricCard(
          label: 'كميات الخامات',
          value: '1,420 وحدة',
          icon: Icons.scale_outlined,
        ),
      ),
      SizedBox(width: 8),
      Expanded(
        child: StockMetricCard(
          label: 'بنود مسجلة',
          value: '38 صنف',
          icon: Icons.category_outlined,
        ),
      ),
    ],
  );

  Widget _categoryValues() => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StockSectionTitle(
            'توزيع القيمة حسب الأقسام',
            icon: Icons.pie_chart_outline,
          ),
          for (final group in _groups) _categoryRow(group),
        ],
      ),
    ),
  );

  Widget _categoryRow((String, double, int, String) group) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(group.$1, style: AppTypography.labelMd)),
            Text('${_money(group.$2)} ج.م • ${group.$3}%'),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: group.$3 / 100, minHeight: 8),
        ),
        Text(
          group.$4,
          style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
        ),
      ],
    ),
  );

  Widget _highestValueItems(BuildContext context) {
    final items = [...StockPreviewData.branchItems]
      ..sort((left, right) => right.totalValue.compareTo(left.totalValue));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StockSectionTitle(
          'أعلى بنود المخزون قيمة',
          icon: Icons.format_list_numbered,
        ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _valueItem(context, item),
          ),
      ],
    );
  }

  Widget _valueItem(BuildContext context, StockItem item) => InkWell(
    onTap: () => context.push('/inventory/${item.id}'),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: AppTypography.labelMd),
                  Text(
                    item.sku,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${_money(item.totalValue)} ج.م',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _exportNotice(BuildContext context) =>
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('واجهة التصدير جاهزة للربط بخدمة الملفات'),
        ),
      );

  String _money(double amount) => amount.toStringAsFixed(0);
}
