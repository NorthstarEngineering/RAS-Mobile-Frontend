import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/report_export_dialog.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../data/repositories/http_cost_repository.dart';
import '../../domain/repositories/cost_repository.dart';

class GrossProfitReportScreen extends StatefulWidget {
  const GrossProfitReportScreen({super.key, this.repository});

  final CostRepository? repository;

  @override
  State<GrossProfitReportScreen> createState() =>
      _GrossProfitReportScreenState();
}

class _GrossProfitReportScreenState extends State<GrossProfitReportScreen> {
  late final CostRepository _repository;
  GrossProfitReportData? _data;
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
      final report = await _repository.getGrossProfitReport(branchId: targetBranch);
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
        title: 'تقرير إجمالي الربح',
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
        title: 'تقرير إجمالي الربح',
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
      title: 'تقرير إجمالي الربح',
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
      _dateNotice(),
      const SizedBox(height: 10),
      _grossProfit(),
      const SizedBox(height: 10),
      _equation(),
      const SizedBox(height: 10),
      _channelProfit(),
      const SizedBox(height: 10),
      _profitCategories(),
      const SizedBox(height: 10),
      _contributionLink(context),
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

  Widget _dateNotice() => RmsOpsBanner(
    title: _data!.period,
    message: 'نطاق التقرير: الوردية الحالية ومبيعات اليوم',
  );

  Widget _grossProfit() {
    final progress = (_data!.grossProfitMargin / 100).clamp(0.0, 1.0);
    return RmsOpsSection(
      title: 'إجمالي الربح (Gross Profit)',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(
        children: [
          Text(
            '${_formatNumber(_data!.grossProfit)} ج.م',
            style: const TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          LinearProgressIndicator(value: progress),
          ListTile(
            title: const Text('هامش الربح الإجمالي'),
            trailing: Text('${_data!.grossProfitMargin.toStringAsFixed(1)}%'),
          ),
        ],
      ),
    );
  }

  Widget _equation() => RmsOpsSection(
    title: 'معادلة حساب إجمالي الربح',
    child: Text(_data!.equation),
  );

  Widget _channelProfit() {
    final channels = _data!.channelBreakdown;

    return RmsOpsSection(
      title: 'إجمالي الربح حسب قناة البيع',
      child: Column(
        children: [
          for (int i = 0; i < channels.length; i++) ...[
            RmsOpsRecord(
              title: channels[i].channelLabel,
              subtitle:
                  'إيراد ${_formatNumber(channels[i].revenue)} • تكلفة ${_formatNumber(channels[i].cost)} • ربح ${_formatNumber(channels[i].grossProfit)} ج.م • هامش ${channels[i].marginPercentage.toStringAsFixed(0)}%',
            ),
            if (i < channels.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _profitCategories() {
    final categories = _data!.categoryRanking;

    return RmsOpsSection(
      title: 'ترتيب الفئات حسب إجمالي الربح',
      child: Column(
        children: [
          for (int i = 0; i < categories.length; i++) ...[
            RmsOpsRecord(
              title: categories[i].categoryName,
              subtitle:
                  '${_formatNumber(categories[i].grossProfit)} ج.م • هامش ${categories[i].marginPercentage.toStringAsFixed(0)}%',
            ),
            if (i < categories.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _contributionLink(BuildContext context) => Column(
    children: [
      const RmsOpsBanner(
        title: 'ملاحظة المدير المالي والتشغيلي',
        message: 'يعرض التقرير إجمالي الربح قبل خصم مصروفات التشغيل الأخرى.',
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => context.push('/cost/contribution'),
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('حساب المساهمة التقديرية (COST-05)'),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => showReportExportDialog(
            context,
            reportType: 'gross-profit',
            reportTitle: 'إجمالي الربح (Gross Profit)',
            isCostReport: true,
          ),
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('تصدير تقرير إجمالي الربح'),
        ),
      ),
    ],
  );
}
