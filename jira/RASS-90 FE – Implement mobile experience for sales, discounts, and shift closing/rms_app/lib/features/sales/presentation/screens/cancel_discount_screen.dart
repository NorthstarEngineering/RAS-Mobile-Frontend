import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../../../core/widgets/rms_primary_button.dart';
import '../../data/repositories/http_sales_repository.dart';

class CancelDiscountScreen extends StatefulWidget {
  const CancelDiscountScreen({super.key, required this.discountId});
  final String discountId;
  @override
  State<CancelDiscountScreen> createState() => _CancelDiscountScreenState();
}

class _CancelDiscountScreenState extends State<CancelDiscountScreen> {
  bool _acknowledged = false;
  bool _isSubmitting = false;
  String _reason = 'سوء استخدام صلاحية';
  final _note = TextEditingController(
    text: 'تم إلغاء الخصم لعدم إرفاق بطاقة صلاحية العميل.',
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'إلغاء الخصم والتدقيق',
    showProfile: false,
    children: [
      RmsOpsSection(
        title: 'مرجع الفاتورة • ${widget.discountId}',
        child: Text(
          'معرف الخصم المستهدف: ${widget.discountId} • يتطلب اعتماد مدير الفرع أو المدير التنفيذي',
        ),
      ),
      const SizedBox(height: 12),
      const RmsOpsBanner(
        title: 'تنبيه رقابي غير قابل للتعديل',
        message:
            'الإلغاء لا يحذف السجل التاريخي، بل يسجل حركة موثقة بهوية المستخدم وتوقيت التنفيذ.',
        color: AppColors.errorContainer,
      ),
      const SizedBox(height: 12),
      _impact(),
      const SizedBox(height: 12),
      _reasonForm(),
      CheckboxListTile(
        value: _acknowledged,
        onChanged: (value) => setState(() => _acknowledged = value ?? false),
        title: const Text('أقر بمسؤوليتي عن صحة الإلغاء وإعادة القيد المالي'),
      ),
      const SizedBox(height: 10),
      RmsPrimaryButton(
        label: _isSubmitting ? 'جاري الإلغاء...' : 'تأكيد إلغاء الخصم وتحديث المبيعات',
        icon: Icons.fact_check_outlined,
        onPressed: _isSubmitting ? null : _cancel,
      ),
      TextButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Text('تراجع دون تعديل'),
      ),
    ],
  );

  Widget _impact() => const RmsOpsMetric(
    label: 'الأثر المالي المباشر',
    value: 'إعادة قيمة الخصم إلى إيرادات الوردية',
    color: AppColors.primary,
  );

  Widget _reasonForm() => RmsOpsSection(
    title: 'سبب الإلغاء الإلزامي',
    child: Column(
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _reason,
          decoration: const InputDecoration(labelText: 'سبب الإلغاء'),
          items:
              const [
                    'سوء استخدام صلاحية',
                    'خطأ في إدخال الكوبون',
                    'عدم مطابقة شروط العرض',
                    'طلب العميل',
                  ]
                  .map(
                    (reason) => DropdownMenuItem(
                      value: reason,
                      child: Text(
                        reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
          onChanged: (value) => setState(() => _reason = value!),
        ),
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'البيان التوضيحي للتدقيق',
          ),
        ),
      ],
    ),
  );

  Future<void> _cancel() async {
    if (!_acknowledged || _note.text.trim().isEmpty) {
      return _notify('أكمل سبب الإلغاء والإقرار قبل الاعتماد');
    }

    setState(() => _isSubmitting = true);
    try {
      await HttpSalesRepository.instance.cancelDiscount(
        discountId: widget.discountId,
        reason: _reason,
        note: _note.text.trim(),
        cancelledByUserId: 'usr_bm1',
      );
      _notify('تم إلغاء الخصم وتحديث المبيعات بنجاح');
      if (mounted) {
        Navigator.of(context).maybePop(true);
      }
    } catch (e) {
      _notify('فشل إلغاء الخصم: $e');
      // Preserve form state on error; do NOT pop screen
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
