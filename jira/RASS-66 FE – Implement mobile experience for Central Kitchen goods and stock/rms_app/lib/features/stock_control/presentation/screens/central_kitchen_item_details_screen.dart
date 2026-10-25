import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../data/repositories/http_central_kitchen_repository.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/central_kitchen_repository.dart';
import '../widgets/stock_widgets.dart';

class CentralKitchenItemDetailsScreen extends StatefulWidget {
  const CentralKitchenItemDetailsScreen({
    super.key,
    required this.itemId,
    this.repository,
  });

  final String itemId;
  final CentralKitchenRepository? repository;

  @override
  State<CentralKitchenItemDetailsScreen> createState() =>
      _CentralKitchenItemDetailsScreenState();
}

class _CentralKitchenItemDetailsScreenState
    extends State<CentralKitchenItemDetailsScreen> {
  late final CentralKitchenRepository _repository;
  StockItem? _item;
  List<StockMovement> _itemMovements = [];
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
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final item = await _repository.getItemById(widget.itemId);
      if (item != null && mounted) {
        setState(() => _item = item);
        final movs = await _repository.getMovements(
          query: item.sku,
          limit: 5,
        );
        if (mounted) {
          setState(() {
            _itemMovements = movs;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _item == null) {
      return const StockPageShell(
        title: 'تفاصيل الصنف',
        showNavigation: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_item == null) {
      return StockPageShell(
        title: 'تفاصيل الصنف',
        showNavigation: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('الصنف غير موجود أو تعذر تحميل البيانات من الخادم'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadDetails,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final item = _item!;
    return StockPageShell(
      title: 'تفاصيل الصنف',
      showNavigation: false,
      child: RefreshIndicator(
        onRefresh: _loadDetails,
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
          const StockSectionTitle('مستوى الامتلاء وسعة المستودع'),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (item.quantity / (item.capacity > 0 ? item.capacity : 100.0)).clamp(0, 1),
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
          Text('وحدة القياس المعتمدة: ${item.unit}'),
          const Divider(height: 16),
          Text('الحد الأدنى للأمان: ${_quantity(item.safetyStock)} ${item.unit}'),
          const Divider(height: 16),
          Text('السعة الاستيعابية: ${_quantity(item.capacity)} ${item.unit}'),
          const Divider(height: 16),
          Text('موقع التخزين: ${item.location}'),
          const Divider(height: 16),
          Text('آخر تحديث مسجل: ${item.updatedAt ?? "مسجل في قاعدة البيانات"}'),
        ],
      ),
    ),
  );

  Widget _recent(BuildContext context) {
    return Column(
      children: [
        StockSectionTitle(
          'سجل حركات المخزون',
          trailing: TextButton(
            onPressed: () => context.push('/kitchen/movements'),
            child: const Text('عرض الكل'),
          ),
        ),
        if (_itemMovements.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'لا توجد حركات مخزنية مسجلة لهذا الصنف',
                style: TextStyle(color: AppColors.secondary),
              ),
            ),
          )
        else
          for (final movement in _itemMovements)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: StockMovementCard(movement: movement),
            ),
      ],
    );
  }

  Widget _actions(BuildContext context, StockItem item) => Column(
    children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () async {
            await context.push('/kitchen/items/create?id=${item.id}', extra: item);
            _loadDetails();
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('تعديل بيانات الصنف'),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () async {
            final targetBranch = item.branchId.isNotEmpty ? item.branchId : 'br_04';
            await context.push('/inventory/adjust/${item.id}?branch_id=$targetBranch', extra: item);
            _loadDetails();
          },
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
