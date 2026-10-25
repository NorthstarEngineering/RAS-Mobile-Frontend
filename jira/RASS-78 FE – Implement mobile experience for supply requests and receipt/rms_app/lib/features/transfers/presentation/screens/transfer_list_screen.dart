import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../data/repositories/http_transfers_repository.dart';
import '../../domain/repositories/transfers_repository.dart';

class TransferListScreen extends StatefulWidget {
  const TransferListScreen({super.key});
  @override
  State<TransferListScreen> createState() => _TransferListScreenState();
}

class _TransferListScreenState extends State<TransferListScreen> {
  String _filter = 'الكل';
  String _query = '';
  List<TransferPreviewOrder> _ordersList = [];
  Map<String, int> _metricsData = {
    'pendingReviewCount': 0,
    'inTransitCount': 0,
    'receivedCount': 0,
  };
  bool _isLoading = true;

  TransfersRepository get _repository {
    if (sl.isRegistered<TransfersRepository>()) {
      return sl<TransfersRepository>();
    }
    return HttpTransfersRepository.instance;
  }

  String get _activeBranchName {
    if (_ordersList.isNotEmpty) {
      for (final o in _ordersList) {
        if (o.source.isNotEmpty) return o.source;
      }
    }
    return 'الفرع التشغيلي';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final orders = await _repository.getTransfers();
      final metrics = await _repository.getTransferMetrics();
      if (mounted) {
        setState(() {
          _ordersList = orders;
          if (metrics.isNotEmpty) _metricsData = metrics;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'التحويلات بين الفروع',
    selectedIndex: 2,
    destinations: const [
      RmsOpsDestination(
        'الرئيسية',
        Icons.dashboard_outlined,
        '/dashboard/branch',
      ),
      RmsOpsDestination('الفروع', Icons.storefront_outlined, '/branches'),
      RmsOpsDestination('التحويلات', Icons.swap_horiz, '/transfers'),
      RmsOpsDestination('المخزون', Icons.inventory_2_outlined, '/inventory'),
      RmsOpsDestination('الحساب', Icons.person_outline, '/profile'),
    ],
    children: [
      _branchBanner(),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () async {
            await context.push('/transfers/create');
            _loadData();
          },
          icon: const Icon(Icons.add),
          label: const Text('إنشاء طلب تحويل جديد'),
        ),
      ),
      const SizedBox(height: 10),
      _metrics(),
      const SizedBox(height: 10),
      _search(),
      _filterChips(),
      const SizedBox(height: 8),
      _orders(context),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () async {
          await context.push('/transfers/history');
          _loadData();
        },
        icon: const Icon(Icons.history),
        label: const Text('سجل التحويلات بالكامل (TR-06)'),
      ),
    ],
  );

  Widget _branchBanner() => RmsOpsBanner(
    title: _activeBranchName,
    message: 'نطاق المستودع التشغيلي • متصل لحظياً',
  );

  Widget _metrics() => Row(
    children: [
      Expanded(
        child: RmsOpsMetric(
          label: 'واردة للمراجعة',
          value: '${_metricsData['pendingReviewCount'] ?? 0}',
          color: AppColors.warning,
        ),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: RmsOpsMetric(
          label: 'صادرة بالطريق',
          value: '${_metricsData['inTransitCount'] ?? 0}',
          color: AppColors.tertiary,
        ),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: RmsOpsMetric(
          label: 'مكتمل',
          value: '${_metricsData['receivedCount'] ?? 0}',
          color: AppColors.success,
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
        hintText: 'ابحث برقم التحويل أو الفرع',
      ),
    ),
  );

  Widget _filterChips() => Wrap(
    spacing: 5,
    children: ['الكل', 'الواردة', 'الصادرة', 'قيد الإرسال']
        .map(
          (label) => ChoiceChip(
            label: Text(label),
            selected: label == _filter,
            onSelected: (_) => setState(() => _filter = label),
          ),
        )
        .toList(),
  );

  Widget _orders(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    final visible = _ordersList.where(_matches).toList();
    if (visible.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('لا توجد تحويلات مطابقة', textAlign: TextAlign.center),
      );
    }
    return Column(
      children: visible
          .map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _orderCard(context, order),
            ),
          )
          .toList(),
    );
  }

  Widget _orderCard(
    BuildContext context,
    TransferPreviewOrder order,
  ) => RmsOpsRecord(
    title: '${order.id} • ${order.item}',
    subtitle: '${order.source}  ←  ${order.destination} • ${order.quantity}',
    status: RmsOpsStatus(order.status, color: _statusColor(order.status)),
    details: [const Text('التحويل يخص أرصدة المخزون، ولا ينشئ حركة بيع نقدي.')],
    actions: [
      TextButton(
        onPressed: () async {
          await context.push('/transfers/${order.id}/review');
          _loadData();
        },
        child: const Text('التفاصيل'),
      ),
      FilledButton(
        onPressed: () async {
          await context.push(_nextPath(order));
          _loadData();
        },
        child: Text(_nextLabel(order)),
      ),
    ],
  );

  bool _matches(TransferPreviewOrder order) {
    final queryMatches =
        '${order.id} ${order.source} ${order.destination} ${order.item}'
            .toLowerCase()
            .contains(_query);
    final filterMatches =
        _filter == 'الكل' ||
        (_filter == 'الواردة' && (order.status == 'طلب وارد' || order.status == 'جاهز للاستلام')) ||
        (_filter == 'الصادرة' && (order.status == 'قيد المراجعة' || order.source.contains(_activeBranchName))) ||
        (_filter == 'قيد الإرسال' && (order.status == 'طلب وارد' || order.status == 'قيد المراجعة'));
    return queryMatches && filterMatches;
  }

  String _nextPath(TransferPreviewOrder order) {
    if (order.status == 'جاهز للاستلام') {
      return '/transfers/${order.id}/receive';
    }
    if (order.status == 'قيد المراجعة') {
      return '/transfers/${order.id}/review';
    }
    if (order.status == 'طلب وارد' || order.status == 'معتمد ومجهز للإرسال' || order.status == 'معتمد') {
      return '/transfers/${order.id}/send';
    }
    return '/transfers/${order.id}/review';
  }

  String _nextLabel(TransferPreviewOrder order) {
    if (order.status == 'جاهز للاستلام') {
      return 'تأكيد الاستلام';
    }
    if (order.status == 'قيد المراجعة') {
      return 'مراجعة الطلب';
    }
    if (order.status == 'طلب وارد' || order.status == 'معتمد ومجهز للإرسال' || order.status == 'معتمد') {
      return 'إرسال الشحنة';
    }
    return 'عرض التفاصيل';
  }

  Color _statusColor(String status) => status == 'مكتمل'
      ? AppColors.success
      : status == 'جاهز للاستلام'
      ? AppColors.tertiary
      : AppColors.warning;
}
