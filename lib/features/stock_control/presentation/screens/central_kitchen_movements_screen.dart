import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/stock_preview_data.dart';
import '../../domain/entities/stock_movement.dart';
import '../widgets/stock_widgets.dart';

class CentralKitchenMovementsScreen extends StatefulWidget {
  const CentralKitchenMovementsScreen({super.key});

  @override
  State<CentralKitchenMovementsScreen> createState() =>
      _CentralKitchenMovementsScreenState();
}

class _CentralKitchenMovementsScreenState
    extends State<CentralKitchenMovementsScreen> {
  String _filter = 'الكل';
  String _query = '';

  @override
  Widget build(BuildContext context) => StockPageShell(
    title: 'حركات مخزون المطبخ',
    tab: 2,
    child: StockScrollBody(
      children: [
        _summary(),
        const SizedBox(height: 12),
        _search(),
        StockFilterChips(
          labels: const ['الكل', 'صرف', 'توريد', 'تحويل', 'تسوية'],
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
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('تصدير كشف الحركات (PDF / Excel)'),
        ),
        const SizedBox(height: 10),
        const Text(
          'جميع الحركات مقيدة في دفتر المخزون، ولا تمثل حركات مبيعات نقدية.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _summary() => const Row(
    children: [
      Expanded(
        child: StockMetricCard(label: 'الإجمالي', value: '38'),
      ),
      SizedBox(width: 6),
      Expanded(
        child: StockMetricCard(
          label: 'صرف OUT',
          value: '18',
          color: AppColors.error,
        ),
      ),
      SizedBox(width: 6),
      Expanded(
        child: StockMetricCard(
          label: 'توريد IN',
          value: '12',
          color: AppColors.success,
        ),
      ),
      SizedBox(width: 6),
      Expanded(
        child: StockMetricCard(
          label: 'نقل TR',
          value: '5',
          color: AppColors.tertiary,
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
        hintText: 'ابحث برقم الإذن أو الصنف',
      ),
    ),
  );

  Widget _movementList() {
    final movements = StockPreviewData.centralMovements
        .where(_matches)
        .toList();
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
    final matchesType =
        _filter == 'الكل' || _movementLabel(movement.type) == _filter;
    final matchesQuery =
        _query.isEmpty ||
        '${movement.code} ${movement.itemName} ${movement.sku}'
            .toLowerCase()
            .contains(_query);
    return matchesType && matchesQuery;
  }

  String _movementLabel(StockMovementType type) => switch (type) {
    StockMovementType.issue => 'صرف',
    StockMovementType.receipt => 'توريد',
    StockMovementType.transfer => 'تحويل',
    StockMovementType.adjustment => 'تسوية',
  };

  void _exportNotice() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('واجهة التصدير جاهزة للربط بخدمة الملفات')),
  );
}
