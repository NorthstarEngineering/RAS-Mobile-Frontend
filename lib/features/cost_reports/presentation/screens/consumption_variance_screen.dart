import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/report_export_dialog.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../data/repositories/http_cost_repository.dart';
import '../../domain/repositories/cost_repository.dart';

class ConsumptionVarianceScreen extends StatefulWidget {
  const ConsumptionVarianceScreen({super.key, this.repository});

  final CostRepository? repository;

  @override
  State<ConsumptionVarianceScreen> createState() =>
      _ConsumptionVarianceScreenState();
}

class _ConsumptionVarianceScreenState extends State<ConsumptionVarianceScreen> {
  late final CostRepository _repository;
  ConsumptionVarianceData? _data;
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
      final report = await _repository.getConsumptionVarianceReport(branchId: targetBranch);
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

  String _criticalText(int count) {
    if (count == 1) return 'خامة واحدة';
    if (count == 2) return 'خامتان';
    if (count >= 3 && count <= 10) return '$count خامات';
    return '$count خامة';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _data == null) {
      return const RmsOpsScaffold(
        title: 'الاستهلاك الفعلي مقابل النظري',
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
        title: 'الاستهلاك الفعلي مقابل النظري',
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
        title: 'الاستهلاك الفعلي مقابل النظري',
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
          RmsOpsBanner(
            title: _data!.period,
            message:
                'تقرير فروقات الكميات والهدر حسب حركة المبيعات ووصفات القائمة.',
          ),
          const SizedBox(height: 10),
          _varianceMetrics(),
          const SizedBox(height: 10),
          _ingredients(),
          const SizedBox(height: 10),
          _policyNote(),
          const SizedBox(height: 10),
          _actions(context),
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

  Widget _varianceMetrics() {
    final ratePrefix = _data!.overallVarianceRate >= 0 ? '+' : '';
    final formattedCost = _data!.totalVarianceCost == 0
        ? '0.00 ج.م'
        : '-${_formatNumber(_data!.totalVarianceCost.abs())} ج.م';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: RmsOpsMetric(
                label: 'معدل الانحراف الكلي',
                value: '$ratePrefix${_data!.overallVarianceRate.toStringAsFixed(1)}%',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RmsOpsMetric(
                label: 'الخامات المراقبة',
                value: '${_data!.monitoredItemsCount} أصناف',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RmsOpsMetric(
                label: 'حالات حرجة',
                value: _criticalText(_data!.criticalItemsCount),
                color: _data!.criticalItemsCount > 0
                    ? AppColors.error
                    : AppColors.success,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RmsOpsMetric(
                label: 'قيمة الفاقد المالي',
                value: formattedCost,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _ingredients() {
    final items = _data!.items;

    return RmsOpsSection(
      title: 'تفاصيل الخامات والمكونات الأساسية',
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            RmsOpsRecord(
              title: '${items[i].nameAr} • ${items[i].sku}',
              subtitle: _buildItemSubtitle(items[i]),
            ),
            if (i < items.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  String _buildItemSubtitle(VarianceIngredientData item) {
    final varPctPrefix = item.variancePercentage >= 0 ? '+' : '';
    final pctStr = '$varPctPrefix${item.variancePercentage.toStringAsFixed(1)}%';

    final buffer = StringBuffer(
      'نظري ${_formatQty(item.theoreticalQty)} ${item.unit} • فعلي ${_formatQty(item.actualQty)} ${item.unit} • انحراف $pctStr',
    );

    if (item.varianceQty != 0) {
      final diffLabel = item.varianceQty > 0 ? 'عجز' : 'وفر';
      buffer.write(' • $diffLabel ${_formatQty(item.varianceQty.abs())} ${item.unit}');
    }

    return buffer.toString();
  }

  Widget _policyNote() => RmsOpsBanner(
        title: 'توجيه رقابي لمعايير التشغيل (SOP)',
        message: _data!.sopPolicyNote,
        color: AppColors.errorContainer,
      );

  Widget _actions(BuildContext context) => Column(
    children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => showReportExportDialog(
            context,
            reportType: 'variance',
            reportTitle: 'انحراف الاستهلاك الفعلي والنظري',
            isCostReport: true,
          ),
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('تصدير تقرير انحراف الاستهلاك'),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => context.push('/inventory/adjust/raw-meat-102'),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('إجراء تسوية هالك تشغيلي (INV-04)'),
        ),
      ),
      OutlinedButton.icon(
        onPressed: () => context.push('/cost/recipe'),
        icon: const Icon(Icons.tune),
        label: const Text('تعديل الوصفة (COST-01)'),
      ),
    ],
  );
}
