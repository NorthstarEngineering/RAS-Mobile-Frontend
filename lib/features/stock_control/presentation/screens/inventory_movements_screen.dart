import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/stock_preview_data.dart';
import '../../domain/entities/stock_movement.dart';
import '../widgets/stock_widgets.dart';

class InventoryMovementsScreen extends StatefulWidget {
  const InventoryMovementsScreen({super.key});

  @override
  State<InventoryMovementsScreen> createState() =>
      _InventoryMovementsScreenState();
}

class _InventoryMovementsScreenState extends State<InventoryMovementsScreen> {
  String _filter = 'الكل';
  String _query = '';

  @override
  Widget build(BuildContext context) => StockPageShell(
    title: 'حركات مخزون الفرع',
    tab: 2,
    child: StockScrollBody(
      children: [
        _summary(),
        const SizedBox(height: 12),
        _search(),
        StockFilterChips(
          labels: const ['الكل', 'توريد', 'صرف', 'تسويات', 'تحويل'],
          selected: _filter,
          onSelected: (value) => setState(() => _filter = value),
        ),
        const SizedBox(height: 10),
        const StockSectionTitle(
          'التسلسل الزمني للعمليات',
          icon: Icons.timeline,
        ),
        const SizedBox(height: 10),
        _movementList(),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _exportNotice,
          icon: const Icon(Icons.ios_share),
          label: const Text('تصدير بيان الحركات (Excel / PDF)'),
        ),
        const SizedBox(height: 8),
        const Text(
          'الحركات المخزنية تقيد في سجل المخزون ولا تمثل مبيعات نقدية.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _summary() => const Row(
    children: [
      Expanded(
        child: StockMetricCard(label: 'إجمالي الحركات', value: '24'),
      ),
      SizedBox(width: 6),
      Expanded(
        child: StockMetricCard(
          label: 'توريد وارد',
          value: '+140',
          color: AppColors.success,
        ),
      ),
      SizedBox(width: 6),
      Expanded(
        child: StockMetricCard(
          label: 'صرف تشغيلي',
          value: '-115',
          color: AppColors.error,
        ),
      ),
    ],
  );

  Widget _search() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      onChanged: (value) => setState(() => _query = value.toLowerCase()),
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'ابحث برقم الإذن أو اسم الخامة',
      ),
    ),
  );

  Widget _movementList() {
    final movements = StockPreviewData.branchMovements.where(_matches).toList();
    if (movements.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('لا توجد حركات مطابقة', textAlign: TextAlign.center),
      );
    }
    return Column(
      children: movements
          .map(
            (movement) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: StockMovementCard(movement: movement),
            ),
          )
          .toList(),
    );
  }

  bool _matches(StockMovement movement) {
    final typeMatches =
        _filter == 'الكل' || _typeLabel(movement.type) == _filter;
    final queryMatches =
        _query.isEmpty ||
        '${movement.code} ${movement.itemName} ${movement.sku}'
            .toLowerCase()
            .contains(_query);
    return typeMatches && queryMatches;
  }

  String _typeLabel(StockMovementType type) => switch (type) {
    StockMovementType.issue => 'صرف',
    StockMovementType.receipt => 'توريد',
    StockMovementType.transfer => 'تحويل',
    StockMovementType.adjustment => 'تسويات',
  };

  void _exportNotice() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('واجهة التصدير جاهزة للربط بخدمة الملفات')),
  );
}
