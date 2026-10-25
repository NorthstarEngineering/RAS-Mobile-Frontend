import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';
import 'transfer_preview_data.dart';

class TransferListScreen extends StatefulWidget {
  const TransferListScreen({super.key});
  @override
  State<TransferListScreen> createState() => _TransferListScreenState();
}

class _TransferListScreenState extends State<TransferListScreen> {
  String _filter = 'الكل';
  String _query = '';

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
          onPressed: () => context.push('/transfers/create'),
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
        onPressed: () => context.push('/transfers/history'),
        icon: const Icon(Icons.history),
        label: const Text('سجل التحويلات بالكامل (TR-06)'),
      ),
    ],
  );

  Widget _branchBanner() => const RmsOpsBanner(
    title: 'فرع وسط البلد (#01)',
    message: 'نطاق المستودع التشغيلي • متصل لحظياً',
  );

  Widget _metrics() => const Row(
    children: [
      Expanded(
        child: RmsOpsMetric(
          label: 'واردة للمراجعة',
          value: '2',
          color: AppColors.warning,
        ),
      ),
      SizedBox(width: 7),
      Expanded(
        child: RmsOpsMetric(
          label: 'صادرة بالطريق',
          value: '1',
          color: AppColors.tertiary,
        ),
      ),
      SizedBox(width: 7),
      Expanded(
        child: RmsOpsMetric(
          label: 'مكتمل',
          value: '14',
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
    final visible = transferPreviewOrders.where(_matches).toList();
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
        onPressed: () => context.push('/transfers/${order.id}/review'),
        child: const Text('التفاصيل'),
      ),
      FilledButton(
        onPressed: () => context.push(_nextPath(order)),
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
        (_filter == 'الواردة' && order.status == 'طلب وارد') ||
        (_filter == 'الصادرة' && order.source.contains('وسط البلد')) ||
        (_filter == 'قيد الإرسال' && order.status == 'قيد المراجعة');
    return queryMatches && filterMatches;
  }

  String _nextPath(TransferPreviewOrder order) =>
      order.status == 'جاهز للاستلام'
      ? '/transfers/${order.id}/receive'
      : '/transfers/${order.id}/send';
  String _nextLabel(TransferPreviewOrder order) =>
      order.status == 'جاهز للاستلام'
      ? 'تأكيد الاستلام'
      : order.status == 'قيد المراجعة'
      ? 'إرسال الشحنة'
      : 'مراجعة الطلب';
  Color _statusColor(String status) => status == 'مكتمل'
      ? AppColors.success
      : status == 'جاهز للاستلام'
      ? AppColors.tertiary
      : AppColors.warning;
}
