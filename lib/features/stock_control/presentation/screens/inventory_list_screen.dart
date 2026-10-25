import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/stock_preview_data.dart';
import '../../domain/entities/stock_item.dart';
import '../widgets/stock_widgets.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  String _category = 'الكل';
  String _status = 'الكل';
  String _query = '';

  @override
  Widget build(BuildContext context) => StockPageShell(
    title: 'مخزون الفرع',
    tab: 3,
    child: StockScrollBody(
      children: [
        _branchHeader(),
        const SizedBox(height: 12),
        _summary(context),
        const SizedBox(height: 12),
        _search(),
        StockFilterChips(
          labels: const [
            'الكل',
            'لحوم ودواجن',
            'أجبان وألبان',
            'صلصات وزيوت',
            'مخبوزات',
          ],
          selected: _category,
          onSelected: (value) => setState(() => _category = value),
        ),
        StockFilterChips(
          labels: const ['الكل', 'حرج', 'مخزون منخفض', 'متوفر'],
          selected: _status,
          onSelected: (value) => setState(() => _status = value),
        ),
        const SizedBox(height: 8),
        _items(context),
        const SizedBox(height: 8),
        const Text(
          'معروض 6 أصناف من أصل 38 • البيانات محلية للعرض',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _branchHeader() => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'فرع وسط البلد (#01)',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
      ),
      Text('نطاق المخزون التشغيلي • آخر تحديث اليوم 01:00 م'),
    ],
  );

  Widget _summary(BuildContext context) => Column(
    children: [
      const Row(
        children: [
          Expanded(
            child: StockMetricCard(label: 'إجمالي الأصناف', value: '38 صنف'),
          ),
          SizedBox(width: 8),
          Expanded(
            child: StockMetricCard(
              label: 'أصناف حرجة',
              value: '3',
              color: AppColors.error,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          const Expanded(
            child: StockMetricCard(
              label: 'القيمة الدفترية',
              value: '64,280 ج.م',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.push('/inventory/value'),
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('تقييم المخزون'),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _search() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'ابحث باسم الصنف أو الكود',
      ),
    ),
  );

  Widget _items(BuildContext context) {
    final visibleItems = StockPreviewData.branchItems.where(_matches).toList();
    if (visibleItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('لا توجد أصناف مطابقة', textAlign: TextAlign.center),
      );
    }
    return Column(
      children: visibleItems
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: StockItemCard(
                item: item,
                onTap: () => context.push('/inventory/${item.id}'),
              ),
            ),
          )
          .toList(),
    );
  }

  bool _matches(StockItem item) {
    final categoryMatches = _category == 'الكل' || item.category == _category;
    final statusMatches =
        _status == 'الكل' || _statusFor(item.level) == _status;
    final queryMatches =
        _query.isEmpty ||
        item.name.contains(_query) ||
        item.sku.toLowerCase().contains(_query);
    return categoryMatches && statusMatches && queryMatches;
  }

  String _statusFor(StockLevel level) => switch (level) {
    StockLevel.critical => 'حرج',
    StockLevel.low => 'مخزون منخفض',
    StockLevel.available => 'متوفر',
  };
}
