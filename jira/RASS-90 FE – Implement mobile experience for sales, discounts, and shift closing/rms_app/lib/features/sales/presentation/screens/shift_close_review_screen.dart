import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../../../core/widgets/rms_primary_button.dart';
import '../../data/repositories/http_sales_repository.dart';
import '../../domain/repositories/sales_repository.dart';

class ShiftCloseReviewScreen extends StatefulWidget {
  const ShiftCloseReviewScreen({super.key});
  @override
  State<ShiftCloseReviewScreen> createState() => _ShiftCloseReviewScreenState();
}

class _ShiftCloseReviewScreenState extends State<ShiftCloseReviewScreen> {
  bool _confirmed = false;
  bool _isClosing = false;
  ShiftCloseReviewData? _reviewData;
  final TextEditingController _actualCashController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReview();
  }

  @override
  void dispose() {
    _actualCashController.dispose();
    super.dispose();
  }

  Future<void> _loadReview() async {
    try {
      final data = await HttpSalesRepository.instance.getShiftReview();
      if (mounted) {
        setState(() => _reviewData = data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحميل بيانات مراجعة الوردية: $e'),
            backgroundColor: AppColors.error,
          ),
        );
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
    title: 'مراجعة إغلاق الوردية',
    showProfile: false,
    children: [
      _shiftHeader(),
      const SizedBox(height: 10),
      const RmsOpsBanner(
        title: 'إشعار التدقيق والقفل النهائي',
        message:
            'إغلاق الوردية إجراء نهائي غير قابل للتراجع، وتنتقل السجلات إلى لوحة الإدارة.',
        color: AppColors.errorContainer,
      ),
      const SizedBox(height: 10),
      _salesSummary(),
      const SizedBox(height: 10),
      _soldItems(),
      const SizedBox(height: 10),
      _actualCashDrawerInput(),
      const SizedBox(height: 10),
      _auditChecks(),
      CheckboxListTile(
        value: _confirmed,
        onChanged: (value) => setState(() => _confirmed = value ?? false),
        title: const Text('أقر بصحة المطابقة وجاهزية الوردية للإغلاق النهائي'),
      ),
      RmsPrimaryButton(
        label: 'اعتماد إغلاق الوردية وترحيل الحسابات',
        icon: Icons.done_all,
        isLoading: _isClosing,
        onPressed: _isClosing ? null : () => _close(context),
      ),
    ],
  );

  Widget _shiftHeader() {
    final branch = _reviewData?.branchName ?? '—';
    final mgr = _reviewData?.managerName ?? '—';
    final range = _reviewData?.timeRange ?? '—';
    final dur = _reviewData?.operatingDuration ?? '—';

    return RmsOpsSection(
      title: 'الوردية • مراجعة نهائية',
      child: Text(
        'الفرع: $branch • المسؤول: $mgr\nالفترة: $range • المدة: $dur',
      ),
    );
  }

  Widget _salesSummary() {
    final net = _reviewData?.netSales ?? 0.0;
    final dine = _reviewData?.dineInSales ?? 0.0;
    final delivery = _reviewData?.deliverySales ?? 0.0;
    final discTotal = _reviewData?.discountsTotal ?? 0.0;
    final discCount = _reviewData?.discountsCount ?? 0;
    final expectedCash = _reviewData?.closingCashSystem ?? 0.0;

    return RmsOpsSection(
      title: 'ملخص القنوات والإيرادات والنقد النظامي',
      child: Column(
        children: [
          RmsOpsMetric(
            label: 'صافي المبيعات (Net Sales)',
            value: '${_formatMoney(net)} ج.م',
            color: AppColors.primary,
          ),
          Row(
            children: [
              Expanded(
                child: RmsOpsMetric(label: 'الصالة والمحلي', value: '${_formatMoney(dine)} ج.م'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RmsOpsMetric(label: 'التوصيل', value: '${_formatMoney(delivery)} ج.م'),
              ),
            ],
          ),
          ListTile(
            title: Text('إجمالي الخصومات ($discCount حركة)'),
            trailing: Text('-${_formatMoney(discTotal)} ج.م'),
          ),
          ListTile(
            title: const Text('النقد النظامي المتوقع بالدرج (System Cash)'),
            trailing: Text(
              '${_formatMoney(expectedCash)} ج.م',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _soldItems() {
    final summary = _reviewData?.soldItemsSummary ??
        'لا توجد أصناف مباعة مسجلة لهذه الوردية';

    return RmsOpsSection(
      title: 'تفصيل مبيعات الأصناف',
      child: Text(summary),
    );
  }

  Widget _actualCashDrawerInput() => RmsOpsSection(
    title: 'مطابقة النقد الفعلي بالدرج (Cash Drawer Physical Count)',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'أدخل القيمة النقدية الفعلية المحصاة في الدرج لمقارنتها بالنقد النظامي واحتساب العجز أو الزيادة بدقة:',
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _actualCashController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'المبلغ النقدي الفعلي بالدرج (ج.م) *',
            hintText: 'مثال: 2000.00',
            prefixIcon: Icon(Icons.point_of_sale_outlined),
          ),
        ),
      ],
    ),
  );

  Widget _auditChecks() => const RmsOpsSection(
    title: 'فحص المطابقة والتدقيق الرقابي',
    child: Column(
      children: [
        RmsOpsRecord(
          title: 'مطابقة الأدراج وشبكات الدفع',
          subtitle: 'فحص مبيعات الكاش وشبكات نقاط البيع المسجلة بقاعدة البيانات',
        ),
        SizedBox(height: 8),
        RmsOpsRecord(
          title: 'تدقيق الخصومات الإدارية والتالف',
          subtitle: 'تمت مطابقة حركات الخصم المعتمدة على الوردية',
        ),
      ],
    ),
  );

  Future<void> _close(BuildContext context) async {
    if (!_confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكد الإقرار قبل الإغلاق النهائي')),
      );
      return;
    }

    final rawCash = _actualCashController.text.trim();
    if (rawCash.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('BLOCKED_UI: لا يمكن إغلاق الوردية دون إدخال النقد الفعلي المحصي في الدرج'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final actualCash = double.tryParse(rawCash);
    if (actualCash == null || actualCash < 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال مبلغ نقدي فعلي صحيح (أرقام فقط)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final targetShiftId = _reviewData?.shiftId;
    if (targetShiftId == null || targetShiftId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديد الوردية المستهدفة للإغلاق'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isClosing = true);
    try {
      await HttpSalesRepository.instance.closeShift(
        shiftId: targetShiftId,
        closingCashActual: actualCash,
        supervisorUserId: 'usr_bm1',
        notes: 'إغلاق معتمد من شاشة مراجعة الوردية',
      );

      if (context.mounted) {
        setState(() => _isClosing = false);
        context.push('/sales/shift/closed');
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _isClosing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إغلاق الوردية: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
