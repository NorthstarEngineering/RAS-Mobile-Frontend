import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../data/repositories/http_sales_repository.dart';
import '../../domain/repositories/sales_repository.dart';

class ClosedShiftSummaryScreen extends StatefulWidget {
  const ClosedShiftSummaryScreen({super.key});

  @override
  State<ClosedShiftSummaryScreen> createState() => _ClosedShiftSummaryScreenState();
}

class _ClosedShiftSummaryScreenState extends State<ClosedShiftSummaryScreen> {
  ShiftCloseReviewData? _summaryData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await HttpSalesRepository.instance.getClosedShiftSummary();
      if (mounted) {
        setState(() {
          _summaryData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  String _formatMoney(double amount) {
    final parts = amount.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return parts.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'ملخص الوردية المغلقة',
    showProfile: false,
    children: [
      if (_isLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: LinearProgressIndicator(),
        ),
      if (_errorMessage != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RmsOpsBanner(
            title: 'خطأ في جلب بيانات الإغلاق',
            message: _errorMessage!,
            color: AppColors.errorContainer,
          ),
        ),
      _closedReference(),
      const SizedBox(height: 10),
      _shiftDetails(),
      const SizedBox(height: 10),
      _financialSummary(),
      const SizedBox(height: 10),
      _soldItems(),
      const SizedBox(height: 10),
      _ledgerNotice(),
      const SizedBox(height: 10),
      _actions(context),
    ],
  );

  Widget _closedReference() {
    final ref = _summaryData?.shiftId.isNotEmpty == true
        ? _summaryData!.shiftId
        : 'SFT-CLS-LATEST';

    return RmsOpsBanner(
      title: 'مغلق • للقراءة فقط',
      message: 'المرجع المالي للوردية: $ref',
      color: AppColors.successContainer,
    );
  }

  Widget _shiftDetails() {
    final branch = _summaryData?.branchName ?? '—';
    final mgr = _summaryData?.managerName ?? '—';
    final timeRange = _summaryData?.timeRange ?? '—';
    final duration = _summaryData?.operatingDuration ?? '—';

    return RmsOpsSection(
      title: 'بيانات التدقيق والتشغيل',
      child: Text(
        'الفرع: $branch • المسؤول: $mgr\nالفترة التشغيلية: $timeRange\nالمدة: $duration',
      ),
    );
  }

  Widget _financialSummary() {
    final net = _summaryData?.netSales ?? 0.0;
    final gross = _summaryData?.grossSales ?? 0.0;
    final discounts = _summaryData?.discountsTotal ?? 0.0;
    final orders = _summaryData?.totalOrders ?? 0;
    final avg = _summaryData?.averageOrder ?? (orders > 0 ? (net / orders) : 0.0);

    return RmsOpsSection(
      title: 'الأداء المالي المغلق',
      child: Column(
        children: [
          RmsOpsMetric(
            label: 'صافي المبيعات النهائي',
            value: '${_formatMoney(net)} ج.م',
            color: AppColors.primary,
          ),
          ListTile(
            title: const Text('إجمالي المبيعات الشاملة'),
            trailing: Text('${_formatMoney(gross)} ج.م'),
          ),
          ListTile(
            title: const Text('الخصومات المسجلة'),
            trailing: Text('-${_formatMoney(discounts)} ج.م'),
          ),
          ListTile(
            title: Text('الطلبات المغلقة • متوسط الطلب ${avg.toStringAsFixed(2)} ج.م'),
            trailing: Text('$orders'),
          ),
        ],
      ),
    );
  }

  Widget _soldItems() {
    final summary = _summaryData?.soldItemsSummary ??
        'لا توجد بنود مبيعات مسجلة لهذه الوردية';

    return RmsOpsSection(
      title: 'تفصيل بنود المبيعات المثبتة تاريخياً',
      child: Text(summary),
    );
  }

  Widget _ledgerNotice() => const RmsOpsBanner(
    title: 'التوثيق والمزامنة السحابية',
    message: 'تم ترحيل قيود المبيعات تلقائياً إلى السجل المالي للإدارة العامة.',
    color: AppColors.tertiaryFixed,
  );

  Widget _actions(BuildContext context) => Column(
    children: [
      FilledButton.icon(
        onPressed: () => _export(context),
        icon: const Icon(Icons.print_outlined),
        label: const Text('طباعة تقرير إغلاق الوردية'),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _export(context),
              icon: const Icon(Icons.table_view_outlined),
              label: const Text('تصدير Excel'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _export(context),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('تصدير PDF'),
            ),
          ),
        ],
      ),
      TextButton.icon(
        onPressed: () => context.go('/sales'),
        icon: const Icon(Icons.storefront_outlined),
        label: const Text('العودة للوحة المبيعات'),
      ),
    ],
  );

  void _export(BuildContext context) =>
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('واجهة التصدير جاهزة للربط بخدمة الملفات'),
        ),
      );
}
