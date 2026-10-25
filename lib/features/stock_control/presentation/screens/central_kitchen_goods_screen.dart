import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/stock_preview_data.dart';
import '../../domain/entities/stock_item.dart';
import '../widgets/stock_widgets.dart';

class CentralKitchenGoodsScreen extends StatefulWidget {
  const CentralKitchenGoodsScreen({super.key});

  @override
  State<CentralKitchenGoodsScreen> createState() =>
      _CentralKitchenGoodsScreenState();
}

class _CentralKitchenGoodsScreenState extends State<CentralKitchenGoodsScreen> {
  String _category = 'الكل';
  String _status = 'الكل';
  String _query = '';

  @override
  Widget build(BuildContext context) => StockPageShell(
    title: 'أصناف المطبخ المركزي',
    tab: 1,
    child: StockScrollBody(
      children: [
        _heading(context),
        const SizedBox(height: 12),
        _summary(),
        const SizedBox(height: 12),
        _search(),
        const SizedBox(height: 8),
        _categoryFilters(),
        _statusFilters(),
        const SizedBox(height: 8),
        _itemList(context),
      ],
    ),
  );

  Widget _heading(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'خامات المستودع الرئيسي',
          style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      IconButton.filled(
        onPressed: () => context.push('/kitchen/items/create'),
        icon: const Icon(Icons.add),
      ),
    ],
  );

  Widget _summary() => const Row(
    children: [
      Expanded(
        child: StockMetricCard(label: 'إجمالي الأصناف', value: '142'),
      ),
      SizedBox(width: 8),
      Expanded(
        child: StockMetricCard(
          label: 'حرج ونفاد',
          value: '6',
          color: AppColors.error,
        ),
      ),
      SizedBox(width: 8),
      Expanded(
        child: StockMetricCard(
          label: 'تحت الطلب',
          value: '14',
          color: AppColors.warning,
        ),
      ),
    ],
  );

  Widget _search() => TextField(
    onChanged: (query) => setState(() => _query = query.trim().toLowerCase()),
    decoration: const InputDecoration(
      prefixIcon: Icon(Icons.search),
      hintText: 'ابحث باسم الصنف أو الكود',
    ),
  );

  Widget _categoryFilters() => StockFilterChips(
    labels: const [
      'الكل',
      'لحوم ودواجن',
      'زيوت ودهون',
      'صوصات مركزية',
      'مخبوزات',
    ],
    selected: _category,
    onSelected: (category) => setState(() => _category = category),
  );

  Widget _statusFilters() => StockFilterChips(
    labels: const ['الكل', 'متوفر', 'مخزون منخفض', 'حرج'],
    selected: _status,
    onSelected: (status) => setState(() => _status = status),
  );

  Widget _itemList(BuildContext context) {
    final items = StockPreviewData.centralKitchenItems
        .where(_matchesFilters)
        .toList();
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Text('لا توجد أصناف مطابقة', textAlign: TextAlign.center),
      );
    }
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: StockItemCard(
                item: item,
                onTap: () => context.push('/kitchen/items/${item.id}'),
              ),
            ),
          )
          .toList(),
    );
  }

  bool _matchesFilters(StockItem item) {
    final matchesCategory = _category == 'الكل' || item.category == _category;
    final matchesStatus =
        _status == 'الكل' || _statusFor(item.level) == _status;
    final matchesQuery =
        _query.isEmpty ||
        item.name.contains(_query) ||
        item.sku.toLowerCase().contains(_query);
    return matchesCategory && matchesStatus && matchesQuery;
  }

  String _statusFor(StockLevel level) => switch (level) {
    StockLevel.critical => 'حرج',
    StockLevel.low => 'مخزون منخفض',
    StockLevel.available => 'متوفر',
  };
}
