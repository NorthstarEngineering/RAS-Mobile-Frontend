import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/http_central_kitchen_repository.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/central_kitchen_repository.dart';
import '../widgets/stock_widgets.dart';

class CentralKitchenMovementsScreen extends StatefulWidget {
  const CentralKitchenMovementsScreen({
    super.key,
    this.repository,
  });

  final CentralKitchenRepository? repository;

  @override
  State<CentralKitchenMovementsScreen> createState() =>
      _CentralKitchenMovementsScreenState();
}

class _CentralKitchenMovementsScreenState
    extends State<CentralKitchenMovementsScreen> {
  late final CentralKitchenRepository _repository;
  String _filter = 'الكل';
  String _query = '';
  List<StockMovement> _movements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (sl.isRegistered<CentralKitchenRepository>()
            ? sl<CentralKitchenRepository>()
            : HttpCentralKitchenRepository(
                apiClient:
                    sl.isRegistered<ApiClient>() ? sl<ApiClient>() : null,
              ));
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repository.getMovements(
        filter: _filter != 'الكل' ? _filter : null,
        query: _query.isNotEmpty ? _query : null,
      );
      if (!mounted) return;
      setState(() {
        _movements = list;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => StockPageShell(
    title: 'حركات مخزون المطبخ',
    tab: 2,
    child: RefreshIndicator(
      onRefresh: _loadMovements,
      child: StockScrollBody(
        children: [
          _summary(),
          const SizedBox(height: 12),
          _search(),
          StockFilterChips(
            labels: const ['الكل', 'صرف', 'توريد', 'تحويل', 'تسوية'],
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
    ),
  );

  Widget _summary() {
    final total = _movements.length;
    final issue =
        _movements.where((m) => m.type == StockMovementType.issue).length;
    final receipt =
        _movements.where((m) => m.type == StockMovementType.receipt).length;
    final transfer =
        _movements.where((m) => m.type == StockMovementType.transfer).length;

    return Row(
      children: [
        Expanded(
          child: StockMetricCard(
            label: 'الإجمالي',
            value: _isLoading ? '...' : '$total',
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: StockMetricCard(
            label: 'صرف OUT',
            value: _isLoading ? '...' : '$issue',
            color: AppColors.error,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: StockMetricCard(
            label: 'توريد IN',
            value: _isLoading ? '...' : '$receipt',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: StockMetricCard(
            label: 'تحويل TR',
            value: _isLoading ? '...' : '$transfer',
            color: AppColors.tertiary,
          ),
        ),
      ],
    );
  }

  Widget _search() => TextField(
    onChanged: (value) {
      setState(() => _query = value.trim().toLowerCase());
      _loadMovements();
    },
    decoration: const InputDecoration(
      prefixIcon: Icon(Icons.search),
      hintText: 'ابحث برقم الإذن أو اسم الصنف',
    ),
  );

  Widget _movementList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final movements = _movements.where(_matches).toList();
    if (movements.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Center(
          child: Text(
            'لا توجد حركات مخزنية مسجلة بالمطبخ المركزي',
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
        '\${movement.code} \${movement.itemName} \${movement.sku}'
            .toLowerCase()
            .contains(_query);
    return typeMatches && queryMatches;
  }

  String _typeLabel(StockMovementType type) => switch (type) {
    StockMovementType.issue => 'صرف',
    StockMovementType.receipt => 'توريد',
    StockMovementType.transfer => 'تحويل',
    StockMovementType.adjustment => 'تسوية',
  };

  void _exportNotice() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('خاصية التصدير غير مفعلة حالياً - قيد التطوير (غير مكتملة)'),
      backgroundColor: AppColors.secondary,
    ),
  );
}
