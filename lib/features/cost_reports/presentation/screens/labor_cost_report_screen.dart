import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/report_export_dialog.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../data/repositories/http_cost_repository.dart';
import '../../domain/repositories/cost_repository.dart';

class LaborCostReportScreen extends StatefulWidget {
  const LaborCostReportScreen({super.key, this.repository});

  final CostRepository? repository;

  @override
  State<LaborCostReportScreen> createState() => _LaborCostReportScreenState();
}

class _LaborCostReportScreenState extends State<LaborCostReportScreen> {
  late final CostRepository _repository;
  LaborCostReportData? _data;
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
      final report = await _repository.getLaborCostReport();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _data == null) {
      return const RmsOpsScaffold(
        title: 'تكلفة العمالة',
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
        title: 'تكلفة العمالة',
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
      title: 'تكلفة العمالة',
      showProfile: false,
      children: [
        if (_errorMessage != null)
          RmsOpsBanner(
            title: 'تنبيه',
            message: _errorMessage!,
            color: AppColors.errorContainer,
          ),
        RmsOpsBanner(
          title: _data!.period,
        message:
            'تجمع تكلفة العمالة اليومية والشهرية والساعات الإضافية المعتمدة.',
      ),
      const SizedBox(height: 10),
      _laborTotal(),
      const SizedBox(height: 10),
      _hoursAndRatio(),
      const SizedBox(height: 10),
      _wageMix(),
      const SizedBox(height: 10),
      _departmentBreakdown(),
      const SizedBox(height: 10),
      _actions(context),
    ],
  );
  }

  Widget _laborTotal() => RmsOpsMetric(
    label: 'إجمالي تكلفة العمالة للوردية',
    value: '${_formatNumber(_data!.totalLaborCost)} ج.م',
    icon: Icons.payments_outlined,
  );

  Widget _hoursAndRatio() => Row(
    children: [
      Expanded(
        child: RmsOpsMetric(
          label: 'ساعات العمل الفعلية',
          value: '${_data!.actualWorkingHours.toInt()} ساعة',
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: RmsOpsMetric(
          label: 'نسبة العمالة للربح',
          value: '${_data!.laborToSalesRatio.toStringAsFixed(1)}%',
          color: AppColors.success,
        ),
      ),
    ],
  );

  Widget _wageMix() {
    final wageMix = _data!.wageMix;

    return RmsOpsSection(
      title: 'توزيع الأجور والتعويضات للوردية',
      child: Column(
        children: [
          for (int i = 0; i < wageMix.length; i++) ...[
            RmsOpsRecord(
              title: wageMix[i].label,
              subtitle:
                  '${_formatNumber(wageMix[i].amount)} ج.م • ${wageMix[i].percentageOfTotal.toStringAsFixed(1)}%',
            ),
            if (i < wageMix.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _departmentBreakdown() {
    final depts = _data!.departmentBreakdown;

    return RmsOpsSection(
      title: 'تكلفة العمالة حسب القسم التشغيلي',
      child: Column(
        children: [
          for (int i = 0; i < depts.length; i++) ...[
            RmsOpsRecord(
              title: depts[i].departmentLabel,
              subtitle:
                  '${_formatNumber(depts[i].amount)} ج.م • ${depts[i].percentageOfTotal.toStringAsFixed(1)}%',
            ),
            if (i < depts.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => context.push('/cost/contribution'),
              icon: const Icon(Icons.trending_up),
              label: const Text('المساهمة التقديرية (COST-05)'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => showReportExportDialog(
                context,
                reportType: 'labor',
                reportTitle: 'تكلفة العمالة المباشرة والإنتاجية',
                isCostReport: true,
              ),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('تصدير التقرير'),
            ),
          ),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => context.push('/overtime/approve'),
              child: const Text('مراجعة الساعات الإضافية'),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: () => context.push('/attendance'),
              child: const Text('سجل الحضور'),
            ),
          ),
        ],
      ),
    ],
  );
}
