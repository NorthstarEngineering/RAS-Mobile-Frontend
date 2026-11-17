import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/report_export_dialog.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../data/repositories/http_cost_repository.dart';
import '../../domain/repositories/cost_repository.dart';

class ContributionReportScreen extends StatefulWidget {
  const ContributionReportScreen({super.key, this.repository});

  final CostRepository? repository;

  @override
  State<ContributionReportScreen> createState() =>
      _ContributionReportScreenState();
}

class _ContributionReportScreenState extends State<ContributionReportScreen> {
  late final CostRepository _repository;
  ContributionReportData? _data;
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedBranch = 'br_01';

  final List<Map<String, String>> _branches = const [
    {'id': 'br_01', 'name': 'الفرع الرئيسي - وسط البلد'},
    {'id': 'br_02', 'name': 'فرع المعادي'},
    {'id': 'br_03', 'name': 'فرع التجمع الخامس'},
  ];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (sl.isRegistered<CostRepository>()
            ? sl<CostRepository>()
            : HttpCostRepository.instance);
    _loadData();
  }

  Future<void> _loadData([String? branchId]) async {
    final targetBranch = branchId ?? _selectedBranch;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final report = await _repository.getContributionReport(branchId: targetBranch);
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
    final absVal = value.abs();
    final parts = absVal.toStringAsFixed(2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    final sign = value < 0 ? '-' : '';
    return '$sign$integerPart.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _data == null) {
      return const RmsOpsScaffold(
        title: 'المساهمة التقديرية',
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
        title: 'المساهمة التقديرية',
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
      title: 'المساهمة التقديرية',
      showProfile: false,
      children: [
        if (_errorMessage != null)
          RmsOpsBanner(
            title: 'تنبيه',
            message: _errorMessage!,
            color: AppColors.errorContainer,
          ),
      _branchSelector(),
      const SizedBox(height: 10),
      const RmsOpsBanner(
        title: 'تنبيه محاسبي وتشغيلي',
        message:
            'المساهمة التقديرية تقيس الربح بعد خصم التكاليف التشغيلية الأساسية، وليست دخلاً نهائياً.',
      ),
      const SizedBox(height: 10),
      _contributionTotal(),
      const SizedBox(height: 10),
      _waterfall(),
      const SizedBox(height: 10),
      _channelContribution(),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: () => _export(context),
        icon: const Icon(Icons.file_download_outlined),
        label: const Text('تصدير تقرير المساهمة التقديرية'),
      ),
    ],
  );
  }

  Widget _branchSelector() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.storefront, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'الفرع:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedBranch,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                  ),
                  items: _branches
                      .map(
                        (b) => DropdownMenuItem(
                          value: b['id'],
                          child: Text(
                            b['name']!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (newBranch) {
                    if (newBranch != null && newBranch != _selectedBranch) {
                      setState(() => _selectedBranch = newBranch);
                      _loadData(newBranch);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      );

  Widget _contributionTotal() => RmsOpsMetric(
    label: 'المساهمة التقديرية للفرع',
    value: '${_formatNumber(_data!.contributionMargin)} ج.م',
    icon: Icons.calculate_outlined,
    color: AppColors.primary,
  );

  Widget _waterfall() {
    final steps = _data!.waterfall;

    return RmsOpsSection(
      title: 'جدول تفكيك وتدفق المساهمة',
      child: Column(
        children: [
          for (final step in steps)
            ListTile(
              title: Text(step.label),
              trailing: Text('${_formatNumber(step.amount)} ج.م'),
            ),
        ],
      ),
    );
  }

  Widget _channelContribution() {
    final channels = _data!.channelBreakdown;

    return RmsOpsSection(
      title: 'المساهمة التقديرية حسب قناة البيع',
      child: Column(
        children: [
          for (final ch in channels)
            RmsOpsRecord(
              title: ch.channelLabel,
              subtitle:
                  '${_formatNumber(ch.contributionAmount)} ج.م • مساهمة ${ch.contributionMarginPercentage.toStringAsFixed(1)}%',
            ),
        ],
      ),
    );
  }

  void _export(BuildContext context) => showReportExportDialog(
        context,
        reportType: 'contribution',
        reportTitle: 'هامش المساهمة التقديري',
        isCostReport: true,
      );
}
