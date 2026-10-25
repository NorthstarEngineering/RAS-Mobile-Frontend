import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../data/repositories/http_inventory_repository.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../widgets/stock_widgets.dart';

class InventoryItemDetailsScreen extends StatefulWidget {
  const InventoryItemDetailsScreen({
    super.key,
    required this.itemId,
    this.branchId,
    this.repository,
  });

  final String itemId;
  final String? branchId;
  final InventoryRepository? repository;

  @override
  State<InventoryItemDetailsScreen> createState() =>
      _InventoryItemDetailsScreenState();
}

class _InventoryItemDetailsScreenState
    extends State<InventoryItemDetailsScreen> {
  late final InventoryRepository _repository;
  StockItem? _loadedItem;
  List<StockMovement> _movements = [];
  bool _isLoading = true;
  String? _effectiveBranchId;

  @override
  void initState() {
    super.initState();
    _effectiveBranchId = widget.branchId;
    _repository = widget.repository ??
        (sl.isRegistered<InventoryRepository>()
            ? sl<InventoryRepository>()
            : HttpInventoryRepository());
    _loadItemAndMovements();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final state = GoRouterState.of(context);
      final qBranch = state.uri.queryParameters['branch_id'];
      if (qBranch != null && qBranch.isNotEmpty && qBranch != _effectiveBranchId) {
        _effectiveBranchId = qBranch;
        _loadItemAndMovements();
      }
      if (state.extra is StockItem && _loadedItem == null) {
        final extraItem = state.extra as StockItem;
        _loadedItem = extraItem;
        _effectiveBranchId = extraItem.branchId;
      }
    } catch (_) {}
  }

  Future<void> _loadItemAndMovements() async {
    setState(() => _isLoading = true);
    try {
      final item = await _repository.getInventoryItemById(
        widget.itemId,
        branchId: _effectiveBranchId,
      );
      if (item != null) {
        _effectiveBranchId = item.branchId;
      }
      final movements = await _repository.getStockMovements(
        branchId: _effectiveBranchId ?? 'br_01',
        stockItemId: widget.itemId,
      );
      if (mounted) {
        setState(() {
          if (item != null) _loadedItem = item;
          _movements = movements;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _loadedItem == null) {
      return const StockPageShell(
        title: 'تفاصيل المخزون',
        showNavigation: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadedItem == null) {
      return StockPageShell(
        title: 'تفاصيل المخزون',
        showNavigation: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('صنف المخزون غير موجود في هذا الفرع أو تعذر جلب البيانات'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadItemAndMovements,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final item = _loadedItem!;
    return StockPageShell(
      title: 'تفاصيل المخزون',
      showNavigation: false,
      child: RefreshIndicator(
        onRefresh: _loadItemAndMovements,
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
            _movementsSection(),
            const SizedBox(height: 14),
            _actions(context, item),
          ],
        ),
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
          Text(item.sku, style: const TextStyle(color: AppColors.secondary)),
          const Divider(),
          Text('الموقع بالفرع: ${item.location}'),
          Text('الفرع: ${item.branchId}'),
        ],
      ),
    ),
  );

  Widget _metrics(StockItem item) => Row(
    children: [
      Expanded(
        child: StockMetricCard(
          label: 'الرصيد الفعلي',
          value: '${_quantity(item.quantity)} ${item.unit}',
          color: item.level == StockLevel.critical
              ? AppColors.error
              : (item.level == StockLevel.low ? AppColors.warning : null),
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
          label: 'القيمة الإجمالية',
          value: '${item.totalValue.toStringAsFixed(0)} ج.م',
        ),
      ),
    ],
  );

  Widget _stockLevel(StockItem item) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StockSectionTitle('حالة الرصيد والحدود التشغيلية'),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (item.quantity / (item.capacity > 0 ? item.capacity : 100.0)).clamp(0, 1),
            minHeight: 9,
          ),
          const SizedBox(height: 8),
          Text(
            'السعة القصوى ${_quantity(item.capacity)} ${item.unit} • حد الأمان ${_quantity(item.safetyStock)} ${item.unit}',
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
          Text('حد الأمان الأدنى: ${_quantity(item.safetyStock)} ${item.unit}'),
          const Divider(height: 18),
          Text('السعة الاستيعابية: ${_quantity(item.capacity)} ${item.unit}'),
          const Divider(height: 18),
          Text('الموقع التخزيني: ${item.location}'),
          const Divider(height: 18),
          Text('آخر تحديث: ${item.updatedAt ?? "مسجل في قاعدة البيانات"}'),
        ],
      ),
    ),
  );

  Widget _movementsSection() => Column(
    children: [
      const StockSectionTitle('آخر حركات المخزون'),
      if (_movements.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'لا توجد حركات مخزنية مسجلة لهذا الصنف بالفرع',
              style: TextStyle(color: AppColors.secondary),
            ),
          ),
        )
      else
        for (final movement in _movements.take(5))
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
          onPressed: () async {
            final res = await context.push(
              '/inventory/adjust/${item.id}?branch_id=${item.branchId}',
              extra: item,
            );
            if (res == true) {
              _loadItemAndMovements();
            }
          },
          icon: const Icon(Icons.tune),
          label: const Text('إجراء تسوية مخزنية'),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => context.push('/inventory/movements?branch_id=${item.branchId}'),
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
