import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../data/repositories/http_transfers_repository.dart';
import '../../domain/repositories/transfers_repository.dart';

class TransferHistoryScreen extends StatefulWidget {
  const TransferHistoryScreen({super.key});
  @override
  State<TransferHistoryScreen> createState() => _TransferHistoryScreenState();
}

class _TransferHistoryScreenState extends State<TransferHistoryScreen> {
  String _filter = 'الكل';
  String _query = '';
  List<TransferPreviewOrder> _historyList = [];
  bool _isLoading = true;

  TransfersRepository get _repository {
    if (sl.isRegistered<TransfersRepository>()) {
      return sl<TransfersRepository>();
    }
    return HttpTransfersRepository.instance;
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final records = await _repository.getTransferHistory();
      if (mounted) {
        setState(() {
          _historyList = records;
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

  Widget _summary() {
    final completedCount = _historyList.where((e) => e.status == 'مكتمل').length;
    final rate = _historyList.isNotEmpty
        ? ((completedCount / _historyList.length) * 100).toStringAsFixed(1)
        : '100.0';
    return Row(
      children: [
        Expanded(
          child: RmsOpsMetric(
            label: 'إجمالي التحويلات',
            value: '${_historyList.length}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RmsOpsMetric(
            label: 'مطابقة الإنجاز',
            value: '$rate%',
            color: AppColors.success,
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
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    final records = _historyList
        .where(
          (order) =>
              '${order.id} ${order.item} ${order.source} ${order.destination}'.toLowerCase().contains(_query) &&
              (_filter == 'الكل' ||
                  (_filter == 'مكتمل' && order.status == 'مكتمل') ||
                  (_filter == 'مع محضر عجز' && (order.status.contains('عجز') || (order is TransferOrder && (order.notes?.contains('تلف') == true || order.notes?.contains('عجز') == true))))),
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
            (record) {
              final stamp = record is TransferOrder
                  ? (record.updatedAt ?? record.createdAt ?? 'مسجل بالنظام')
                  : 'مسجل بالنظام';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RmsOpsRecord(
                  title: '${record.id} • ${record.status}',
                  subtitle: '${record.source} → ${record.destination}',
                  status: RmsOpsStatus(record.quantity),
                  details: [Text('${record.item} • $stamp')],
                ),
              );
            },
          )
          .toList(),
    );
  }

  void _export() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('واجهة التصدير جاهزة للربط بخدمة الملفات')),
  );
}
