import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/report_export_dialog.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../data/repositories/http_cost_repository.dart';
import '../../domain/repositories/cost_repository.dart';

class InventoryValueReportScreen extends StatefulWidget {
  const InventoryValueReportScreen({super.key, this.repository});

  final CostRepository? repository;

  @override
  State<InventoryValueReportScreen> createState() =>
      _InventoryValueReportScreenState();
}

class _InventoryValueReportScreenState
    extends State<InventoryValueReportScreen> {
  late final CostRepository _repository;
  InventoryValuationData? _data;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (sl.isRegistered<CostRepository>()
            ? sl<CostRepository>()
            : HttpCostRepository.instance);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final report = await _repository.getInventoryValuationReport();
      if (!mounted) return;
      setState(() {
        _data = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatNumber(num value) {
    final parts = value.toStringAsFixed(2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$integerPart.${parts[1]}';
  }

  String _formatQty(num value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _data == null) {
      return const RmsOpsScaffold(
        title: 'تقرير قيمة المخزون',
        showProfile: false,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    if (_errorMessage != null && _data == null) {
      return RmsOpsScaffold(
        title: 'تقرير قيمة المخزون',
        showProfile: false,
        children: [
          RmsOpsBanner(
            title: 'خطأ في الاتصال',
            message: _errorMessage!,
            color: AppColors.errorContainer,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }
    return RmsOpsScaffold(
      title: 'تقرير قيمة المخزون',
      showProfile: false,
      children: [
        if (_errorMessage != null)
          RmsOpsBanner(
            title: 'تنبيه',
            message: _errorMessage!,
            color: AppColors.errorContainer,
          ),
      const RmsOpsBanner(
        title: 'تنبيه رقابي مالي',
        message:
            'قيمة المخزون تمثل رأس المال المقيد في الخامات، وليست إيرادات أو أرباحاً.',
        color: AppColors.errorContainer,
      ),
      const SizedBox(height: 10),
      _total(),
      const SizedBox(height: 10),
      _groups(),
      const SizedBox(height: 10),
      _stockItems(),
      const SizedBox(height: 10),
      _actions(context),
    ],
  );
  }

  Widget _total() => RmsOpsMetric(
    label: 'إجمالي رأس المال المخزني',
    value: '${_formatNumber(_data!.totalInventoryValue)} ج.م',
    icon: Icons.account_balance_wallet_outlined,
  );

  Widget _groups() {
    final groups = _data!.categoryBreakdown;

    return RmsOpsSection(
      title: 'توزيع رأس المال حسب الأقسام',
      child: Column(
        children: [
          for (int i = 0; i < groups.length; i++) ...[
            RmsOpsRecord(
              title: groups[i].category,
              subtitle:
                  '${_formatNumber(groups[i].totalValue)} ج.م • ${groups[i].percentageOfTotal.toStringAsFixed(1)}% • ${groups[i].itemsCount} أصناف',
            ),
            if (i < groups.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _stockItems() {
    final items = _data!.stockItems;

    return RmsOpsSection(
      title: 'كشف الأصناف التفصيلي',
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            RmsOpsRecord(
              title: items[i].name,
              subtitle:
                  '${_formatQty(items[i].quantity)} ${items[i].unit} × ${_formatNumber(items[i].unitCost)} ج.م • ${_formatNumber(items[i].totalValue)} ج.م',
            ),
            if (i < items.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) => Column(
    children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => context.push('/inventory'),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('تفاصيل مخزون الفرع (INV-01)'),
        ),
      ),
      OutlinedButton.icon(
        onPressed: () => _export(context),
        icon: const Icon(Icons.ios_share),
        label: const Text('تصدير كشف تقييم المخزون'),
      ),
    ],
  );

  void _export(BuildContext context) => showReportExportDialog(
        context,
        reportType: 'inventory',
        reportTitle: 'القيمة الرأسمالية لمخزون الخامات',
        isCostReport: true,
      );
}
