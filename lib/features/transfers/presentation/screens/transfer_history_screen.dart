import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';
import 'transfer_preview_data.dart';

class TransferHistoryScreen extends StatefulWidget {
  const TransferHistoryScreen({super.key});
  @override
  State<TransferHistoryScreen> createState() => _TransferHistoryScreenState();
}

class _TransferHistoryScreenState extends State<TransferHistoryScreen> {
  String _filter = 'الكل';
  String _query = '';

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'سجل التحويلات',
    selectedIndex: 2,
    destinations: const [
      RmsOpsDestination(
        'الرئيسية',
        Icons.dashboard_outlined,
        '/dashboard/branch',
      ),
      RmsOpsDestination('المخزون', Icons.inventory_2_outlined, '/inventory'),
      RmsOpsDestination('التحويلات', Icons.swap_horiz, '/transfers'),
      RmsOpsDestination('الفروع', Icons.storefront_outlined, '/branches'),
    ],
    children: [
      _summary(),
      const SizedBox(height: 10),
      _search(),
      _filters(),
      const SizedBox(height: 8),
      _history(),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: _export,
        icon: const Icon(Icons.file_download_outlined),
        label: const Text('تصدير كشف التحويلات المعتمد'),
      ),
    ],
  );

  Widget _summary() => const Row(
    children: [
      Expanded(
        child: RmsOpsMetric(label: 'إجمالي التحويلات', value: '48'),
      ),
      SizedBox(width: 8),
      Expanded(
        child: RmsOpsMetric(
          label: 'مطابقة الإنجاز',
          value: '98.2%',
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
        hintText: 'ابحث برقم الإذن أو الفرع',
      ),
    ),
  );
  Widget _filters() => Wrap(
    spacing: 6,
    children: ['الكل', 'مكتمل', 'مع محضر عجز']
        .map(
          (label) => ChoiceChip(
            label: Text(label),
            selected: _filter == label,
            onSelected: (_) => setState(() => _filter = label),
          ),
        )
        .toList(),
  );

  Widget _history() {
    final records = transferPreviewOrders
        .where(
          (order) =>
              '${order.id} ${order.item}'.toLowerCase().contains(_query) &&
              (_filter == 'الكل' ||
                  (_filter == 'مكتمل' && order.status == 'مكتمل') ||
                  (_filter == 'مع محضر عجز' && order.id == 'TR-5540')),
        )
        .toList();
    if (records.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('لا توجد سجلات مطابقة'),
        ),
      );
    }
    return Column(
      children: records
          .map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RmsOpsRecord(
                title: '${record.id} • ${record.status}',
                subtitle: '${record.source} → ${record.destination}',
                status: RmsOpsStatus(record.quantity),
                details: [Text('${record.item} • آخر تحديث اليوم 01:15 م')],
              ),
            ),
          )
          .toList(),
    );
  }

  void _export() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('واجهة التصدير جاهزة للربط بخدمة الملفات')),
  );
}
