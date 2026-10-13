import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

class CreateOvertimeScreen extends StatefulWidget {
  const CreateOvertimeScreen({super.key});

  @override
  State<CreateOvertimeScreen> createState() => _CreateOvertimeScreenState();
}

class _CreateOvertimeScreenState extends State<CreateOvertimeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController(text: 'ضغط تشغيلي في تجهيز وجبات الغداء وتغطية عجز الوردية');
  double _hours = 2.0;
  String _multiplier = '1.5x (عمل إضافي معتاد)';
  String _selectedEmployee = 'مصطفى خالد عثمان (#1052)';
  bool _isSubmitting = false;

  final double _baseHourlyRate = 42.0;

  double get _calculatedAmount {
    final rate = _multiplier.startsWith('2') ? 2.0 : 1.5;
    return _hours * _baseHourlyRate * rate;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل وإرسال طلب الساعات الإضافية للاعتماد الإداري'),
            backgroundColor: Color(0xFF2E8B2E),
          ),
        );
        context.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('إضافة ساعات عمل إضافية'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Operational Source Banner
              Container(
                padding: const EdgeInsets.all(AppDimens.paddingMd),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'مصدر التسجيل:',
                          style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'إدخال يدوي بإشراف المشرف',
                            style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.paddingMd),

              // Employee Selection Card
              Container(
                padding: const EdgeInsets.all(AppDimens.paddingLg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الموظف المستحق *',
                      style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedEmployee,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'مصطفى خالد عثمان (#1052)',
                          child: Text('مصطفى خالد (#1052) - طاهي ساخن', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'أحمد محمود سالم (#1084)',
                          child: Text('أحمد سالم (#1084) - مشرف صالة', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'سارة مراد كمال (#1090)',
                          child: Text('سارة كمال (#1090) - كاشير رئيسي', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (val) => setState(() => _selectedEmployee = val ?? _selectedEmployee),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.paddingMd),

              // Overtime Hours & Multiplier
              Container(
                padding: const EdgeInsets.all(AppDimens.paddingLg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'عدد الساعات الإضافية',
                          style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$_hours ساعة',
                          style: AppTypography.headlineSm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _hours,
                      min: 0.5,
                      max: 8.0,
                      divisions: 15,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _hours = val),
                    ),
                    const SizedBox(height: AppDimens.paddingSm),

                    // Multiplier
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _multiplier,
                      decoration: const InputDecoration(
                        labelText: 'معامل احتساب الأجر الإضافي',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calculate_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '1.5x (عمل إضافي معتاد)',
                          child: Text('1.5x (أيام العمل العادية)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: '2.0x (عطلات ومواسم رسمية)',
                          child: Text('2.0x (العطلات الرسمية والمواسم)', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (val) => setState(() => _multiplier = val ?? _multiplier),
                    ),
                    const SizedBox(height: AppDimens.paddingMd),

                    // Amount Preview Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF5EA),
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المبلغ المستحق التقديري للموظف',
                            style: AppTypography.labelSm.copyWith(
                              color: const Color(0xFF2E8B2E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_calculatedAmount.toStringAsFixed(2)} ج.م',
                            style: AppTypography.labelMd.copyWith(
                              color: const Color(0xFF2E8B2E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.paddingMd),

              // Operational Justification
              Container(
                padding: const EdgeInsets.all(AppDimens.paddingLg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المبرر التشغيلي *',
                      style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'اذكر سبب طلب العمل الإضافي وموافقة الإشراف',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'مطلوب' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.paddingLg),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('إرسال طلب الساعات الإضافية للاعتماد'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
