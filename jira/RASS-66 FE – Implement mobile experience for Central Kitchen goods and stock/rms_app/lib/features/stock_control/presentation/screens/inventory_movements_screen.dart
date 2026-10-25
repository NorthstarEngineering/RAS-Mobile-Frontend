import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/http_inventory_repository.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../widgets/stock_widgets.dart';

class InventoryMovementsScreen extends StatefulWidget {
  const InventoryMovementsScreen({
    super.key,
    this.branchId = 'br_01',
    this.repository,
  });

  final String branchId;
  final InventoryRepository? repository;

  @override
  State<InventoryMovementsScreen> createState() =>
      _InventoryMovementsScreenState();
}

class _InventoryMovementsScreenState extends State<InventoryMovementsScreen> {
  late final InventoryRepository _repository;
  String _filter = 'الكل';
  String _query = '';
  bool _isLoading = true;
  List<StockMovement> _movements = [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (sl.isRegistered<InventoryRepository>()
            ? sl<InventoryRepository>()
            : HttpInventoryRepository());
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repository.getStockMovements(
        branchId: widget.branchId,
        movementType: _filter != 'الكل' ? _filter : null,
      );
      if (mounted) {
        setState(() {
          _movements = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => StockPageShell(
    title: 'حركات مخزون الفرع',
    tab: 2,
    child: RefreshIndicator(
      onRefresh: _loadMovements,
      child: StockScrollBody(
        children: [
          _summary(),
          const SizedBox(height: 12),
          _search(),
          StockFilterChips(
            labels: const ['الكل', 'توريد', 'صرف', 'تسويات', 'تحويل'],
            selected: _filter,
            onSelected: (value) {
              setState(() => _filter = value);
              _loadMovements();
            },
          ),
          const SizedBox(height: 10),
          const StockSectionTitle(
            'التسلسل الزمني للعمليات',
            icon: Icons.timeline,
          ),
          const SizedBox(height: 10),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else
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
    ),
  );

  Widget _summary() {
    final receipts = _movements
        .where((m) => m.type == StockMovementType.receipt)
        .length;
    final issues = _movements
        .where((m) =>
            m.type == StockMovementType.issue ||
            m.type == StockMovementType.adjustment)
        .length;

    return Row(
      children: [
        Expanded(
          child: StockMetricCard(
            label: 'إجمالي الحركات',
            value: _isLoading ? '...' : '${_movements.length}',
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: StockMetricCard(
            label: 'توريد وارد',
            value: _isLoading ? '...' : '+$receipts',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: StockMetricCard(
            label: 'صرف / تسويات',
            value: _isLoading ? '...' : '-$issues',
            color: AppColors.error,
          ),
        ),
      ],
    );
  }

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
    final movements = _movements.where(_matches).toList();
    if (movements.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'لا توجد حركات مخزنية مسجلة لهذا الفرع',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondary),
          ),
        ),
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
    const SnackBar(
      content: Text('خاصية التصدير غير مفعلة حالياً - قيد التطوير (غير مكتملة)'),
      backgroundColor: AppColors.secondary,
    ),
  );
}
