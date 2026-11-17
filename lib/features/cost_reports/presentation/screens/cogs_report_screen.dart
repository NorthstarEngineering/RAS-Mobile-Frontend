import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/report_export_dialog.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../data/repositories/http_cost_repository.dart';
import '../../domain/repositories/cost_repository.dart';

class CogsReportScreen extends StatefulWidget {
  const CogsReportScreen({super.key, this.repository});

  final CostRepository? repository;

  @override
  State<CogsReportScreen> createState() => _CogsReportScreenState();
}

class _CogsReportScreenState extends State<CogsReportScreen> {
  late final CostRepository _repository;
  CogsReportData? _data;
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
      final report = await _repository.getCogsReport(branchId: targetBranch);
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
    final parts = value.toStringAsFixed(value % 1 == 0 ? 0 : 2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return parts.length > 1 ? '$integerPart.${parts[1]}' : integerPart;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _data == null) {
      return const RmsOpsScaffold(
        title: 'تقرير تكلفة المبيعات (COGS)',
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
        title: 'تقرير تكلفة المبيعات (COGS)',
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
      title: 'تقرير تكلفة المبيعات (COGS)',
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
        _periodBar(),
        const SizedBox(height: 10),
        _metrics(),
        const SizedBox(height: 10),
        _targetBar(),
        const SizedBox(height: 10),
        _categories(),
        const SizedBox(height: 10),
        _topItems(),
        const SizedBox(height: 10),
        _nextReport(context),
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

  Widget _periodBar() => RmsOpsBanner(
        title: _data!.period,
        message:
            '${_data!.branchName} • حد تكلفة الطعام المستهدف ${_data!.targetCogsPercentage.toStringAsFixed(1)}%',
      );

  Widget _metrics() => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: RmsOpsMetric(
                  label: 'تكلفة المبيعات',
                  value: '${_formatNumber(_data!.totalCogs)} ج.م',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RmsOpsMetric(
                  label: 'صافي المبيعات',
                  value: '${_formatNumber(_data!.netSales)} ج.م',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: RmsOpsMetric(
                  label: 'نسبة التكلفة الإجمالية',
                  value: '${_data!.cogsPercentage.toStringAsFixed(1)}%',
                  color: _data!.isWithinBudget
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RmsOpsMetric(
                  label: 'الحالة التشغيلية',
                  value: _data!.operationalStatus,
                ),
              ),
            ],
          ),
        ],
      );

  Widget _targetBar() {
    final progress = (_data!.cogsPercentage / 100).clamp(0.0, 1.0);
    return RmsOpsSection(
      title: 'توزيع سقف المبيعات',
      child: Column(
        children: [
          LinearProgressIndicator(value: progress, minHeight: 10),
          ListTile(
            title: Text('الفعلي ${_data!.cogsPercentage.toStringAsFixed(1)}%'),
            trailing: Text(
              'الحد الأقصى ${_data!.targetCogsPercentage.toStringAsFixed(1)}%',
            ),
          ),
        ],
      ),
    );
  }

  Widget _categories() {
    final categories = _data!.categoryBreakdown;

    return RmsOpsSection(
      title: 'تفصيل التكلفة حسب التصنيف',
      icon: Icons.pie_chart_outline,
      child: Column(
        children: [
          for (int i = 0; i < categories.length; i++) ...[
            RmsOpsRecord(
              title: categories[i].categoryName,
              subtitle:
                  '${_formatNumber(categories[i].costAmount)} ج.م • ${categories[i].percentageOfTotalCost.toStringAsFixed(1)}% من التكلفة',
            ),
            if (i < categories.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _topItems() {
    final items = _data!.topContributingItems;

    return RmsOpsSection(
      title: 'أعلى أصناف القائمة مساهمة في التكلفة',
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            RmsOpsRecord(
              title: items[i].itemName,
              subtitle:
                  '${items[i].quantitySold.toInt()} وجبة × ${_formatNumber(items[i].unitCost)} ج.م • ${_formatNumber(items[i].totalCost)} ج.م',
            ),
            if (i < items.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _nextReport(BuildContext context) => Column(
    children: [
      const RmsOpsBanner(
        title: 'معادلة محاسبية',
        message: 'تكلفة المبيعات محسوبة من الوصفات المعتمدة والكميات المسجلة.',
        color: AppColors.surfaceContainerHigh,
      ),
      TextButton.icon(
        onPressed: () => context.push('/cost/gross-profit'),
        icon: const Icon(Icons.trending_up),
        label: const Text('عرض تقرير إجمالي الربح (COST-03)'),
      ),
      FilledButton.icon(
        onPressed: () => _export(context),
        icon: const Icon(Icons.file_download_outlined),
        label: const Text('تصدير التقرير'),
      ),
    ],
  );

  void _export(BuildContext context) => showReportExportDialog(
        context,
        reportType: 'cogs',
        reportTitle: 'تكلفة المبيعات (COGS)',
        isCostReport: true,
      );
}
