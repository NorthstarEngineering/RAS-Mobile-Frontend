import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../data/repositories/http_supply_repository.dart';
import '../../domain/repositories/supply_repository.dart';

class SupplyOrdersScreen extends StatefulWidget {
  const SupplyOrdersScreen({super.key, this.repository});

  final SupplyRepository? repository;

  @override
  State<SupplyOrdersScreen> createState() => _SupplyOrdersScreenState();
}

class _SupplyOrdersScreenState extends State<SupplyOrdersScreen> {
  late final SupplyRepository _repository;
  List<SupplyOrder> _orders = [];
  String _filter = 'الكل';
  String _query = '';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (sl.isRegistered<SupplyRepository>()
            ? sl<SupplyRepository>()
            : HttpSupplyRepository(
                apiClient:
                    sl.isRegistered<ApiClient>() ? sl<ApiClient>() : null,
              ));
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await _repository.getSupplyOrders();
      if (mounted) {
        setState(() {
          _orders = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'فشل جلب طلبات التوريد: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'قائمة طلبات التوريد',
    selectedIndex: 1,
    destinations: const [
      RmsOpsDestination('التوريد', Icons.inventory_2_outlined, '/supply'),
      RmsOpsDestination('المطبخ', Icons.restaurant_outlined, '/kitchen'),
      RmsOpsDestination('الفروع', Icons.storefront_outlined, '/branches'),
      RmsOpsDestination('الإعدادات', Icons.settings_outlined, '/profile'),
    ],
    children: [
      _branchLine(),
      const SizedBox(height: 10),
      _createButton(context),
      const SizedBox(height: 10),
      _metrics(),
      const SizedBox(height: 10),
      _search(),
      _filters(),
      const SizedBox(height: 8),
      if (_errorMessage != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      _orderList(context),
      const SizedBox(height: 10),
      const RmsOpsBanner(
        title: 'حركة مخزون مقيدة',
        message:
            'إذن التوريد يؤثر على أرصدة المخزون والدفتر التشغيلي بعد الاستلام.',
      ),
    ],
  );

  Widget _branchLine() => const ListTile(
    leading: Icon(Icons.storefront_outlined, color: AppColors.primary),
    title: Text('المطبخ المركزي ومستودع الإمداد (#04)'),
    subtitle: Text('بيانات التشغيل والربط المباشر مع قاعدة البيانات'),
  );

  Widget _createButton(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: () async {
        await context.push('/supply/create');
        _loadOrders();
      },
      icon: const Icon(Icons.add),
      label: const Text('إنشاء طلب توريد جديد'),
    ),
  );

  Widget _metrics() {
    final pendingCount = _orders
        .where((o) => o.status == 'قيد المراجعة' || o.status == 'قيد التجهيز')
        .length;
    final inTransitCount =
        _orders.where((o) => o.status == 'قيد الشحن').length;
    final receivedCount =
        _orders.where((o) => o.status == 'تم الاستلام').length;

    return Row(
      children: [
        Expanded(
          child: RmsOpsMetric(
            label: 'قيد المراجعة',
            value: '$pendingCount',
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: RmsOpsMetric(
            label: 'قيد الشحن',
            value: '$inTransitCount',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: RmsOpsMetric(
            label: 'تم الاستلام',
            value: '$receivedCount',
            color: AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _search() => TextField(
    onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
    decoration: const InputDecoration(
      prefixIcon: Icon(Icons.search),
      hintText: 'ابحث برقم الإذن أو الفرع المستلم...',
    ),
  );

  Widget _filters() {
    const filters = [
      'الكل',
      'قيد المراجعة',
      'قيد التجهيز',
      'قيد الشحن',
      'تم الاستلام',
      'مرفوض',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters
            .map(
              (f) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(
                  label: Text(f),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _orderList(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final filtered = _orders.where((order) {
      final matchesFilter =
          _filter == 'الكل' || order.status == _filter;
      final matchesQuery = _query.isEmpty ||
          order.orderNumber.toLowerCase().contains(_query) ||
          order.branch.toLowerCase().contains(_query) ||
          order.summary.toLowerCase().contains(_query);
      return matchesFilter && matchesQuery;
    }).toList();

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'لا توجد طلبات توريد مطابقة',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: filtered
          .map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () async {
                  await context.push('/supply/${order.id}');
                  _loadOrders();
                },
                borderRadius: BorderRadius.circular(12),
                child: RmsOpsRecord(
                  title: '${order.orderNumber.isNotEmpty ? order.orderNumber : order.id} • ${order.branch}',
                  subtitle: '${order.summary}\n${order.time}',
                  status: Text(
                    order.status,
                    style: TextStyle(
                      color: _statusColor(order.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'قيد الشحن':
        return AppColors.primary;
      case 'تم الاستلام':
        return AppColors.success;
      case 'مرفوض':
        return AppColors.error;
      case 'قيد التجهيز':
      case 'قيد المراجعة':
      default:
        return AppColors.warning;
    }
  }
}
