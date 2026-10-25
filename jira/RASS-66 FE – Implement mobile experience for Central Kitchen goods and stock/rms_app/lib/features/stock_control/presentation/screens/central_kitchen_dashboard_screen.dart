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

class CentralKitchenDashboardScreen extends StatefulWidget {
  const CentralKitchenDashboardScreen({
    super.key,
    this.repository,
  });

  final CentralKitchenRepository? repository;

  @override
  State<CentralKitchenDashboardScreen> createState() =>
      _CentralKitchenDashboardScreenState();
}

class _CentralKitchenDashboardScreenState
    extends State<CentralKitchenDashboardScreen> {
  late final CentralKitchenRepository _repository;

  String _depotCodeAndStatus = 'CK-01 • تشغيل نشط';
  String _depotName = 'موقع التصنيع والتوريد المركزي';
  String _depotSubtitle = 'مخزون وتشغيل فقط • لا توجد مبيعات مباشرة';
  String _stockValue = '0 ج.م';
  String _itemsCount = '0 صنف';
  String _lastAudit = 'آخر جرد معتمد اليوم • 06:00 ص';

  List<StockItem> _criticalItems = [];
  List<StockMovement> _recentMovementsList = [];
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
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repository.getDashboardData();
      if (!mounted) return;
      setState(() {
        _depotCodeAndStatus = '\${data.depotCode} • \${data.depotStatus}';
        _depotName = data.depotName;
        _depotSubtitle = data.depotSubtitle;
        _stockValue = _formatCurrency(data.totalStockValue);
        _itemsCount = '\${data.totalItemsCount} صنف';
        _criticalItems = data.criticalItems;
        _recentMovementsList = data.recentMovements;
        if (data.lastAuditTime.isNotEmpty) {
          _lastAudit = data.lastAuditTime.startsWith('آخر جرد')
              ? data.lastAuditTime
              : 'آخر جرد معتمد \${data.lastAuditTime}';
        }
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static String _formatCurrency(double value) {
    if (value <= 0) return '0 ج.م';
    final intVal = value.round();
    final str = intVal.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write(',');
      }
    }
    return '\${buffer.toString().split('').reversed.join()} ج.م';
  }

  @override
  Widget build(BuildContext context) => StockPageShell(
        title: 'المطبخ المركزي',
        tab: 0,
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: StockScrollBody(
            children: [
              _depotHeader(),
              const SizedBox(height: 16),
              _quickActions(context),
              const SizedBox(height: 20),
              _stockOverview(),
              const SizedBox(height: 20),
              _criticalStock(context),
              const SizedBox(height: 20),
              _recentMovements(context),
            ],
          ),
        ),
      );

  Widget _depotHeader() => Container(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_depotCodeAndStatus,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 7),
            Text(
              _depotName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _depotSubtitle,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      );

  Widget _quickActions(BuildContext context) => Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                await context.push('/kitchen/items/create');
                _loadDashboardData();
              },
              icon: const Icon(Icons.add),
              label: const Text('إضافة صنف جديد'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/kitchen/movements'),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('إذن صرف / شحن'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/kitchen/movements'),
                  icon: const Icon(Icons.move_to_inbox_outlined),
                  label: const Text('استلام توريد'),
                ),
              ),
            ],
          ),
        ],
      );

  Widget _stockOverview() => Row(
        children: [
          Expanded(
            child: StockMetricCard(
              label: 'قيمة المخزون',
              value: _isLoading ? '...' : _stockValue,
              icon: Icons.account_balance_wallet_outlined,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StockMetricCard(
              label: 'إجمالي الأصناف',
              value: _isLoading ? '...' : _itemsCount,
              icon: Icons.inventory_2_outlined,
            ),
          ),
        ],
      );

  Widget _criticalStock(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StockSectionTitle(
            'نواقص تتطلب شراء عاجل',
            icon: Icons.warning_amber_rounded,
            trailing: TextButton(
              onPressed: () => context.push('/kitchen/items'),
              child: const Text('عرض الكل'),
            ),
          ),
          const SizedBox(height: 10),
          if (_criticalItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  _isLoading
                      ? 'جاري فحص النواقص...'
                      : 'لا توجد نواقص حرجة بالمستودع المركزي حالياً',
                  style: const TextStyle(color: AppColors.secondary),
                ),
              ),
            )
          else
            for (final item in _criticalItems) ...[
              StockItemCard(
                item: item,
                onTap: () => context.push('/kitchen/items/\${item.id}'),
              ),
              const SizedBox(height: 8),
            ],
        ],
      );

  Widget _recentMovements(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StockSectionTitle(
            'آخر حركات المخزون',
            icon: Icons.swap_horiz,
            trailing: TextButton(
              onPressed: () => context.push('/kitchen/movements'),
              child: const Text('عرض الكل'),
            ),
          ),
          const SizedBox(height: 10),
          if (_recentMovementsList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  _isLoading
                      ? 'جاري تحميل الحركات...'
                      : 'لا توجد حركات مخزنية مسجلة حديثاً',
                  style: const TextStyle(color: AppColors.secondary),
                ),
              ),
            )
          else
            for (final movement in _recentMovementsList) ...[
              StockMovementCard(movement: movement),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 8),
          Text(
            _lastAudit,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.secondary),
          ),
        ],
      );
}
