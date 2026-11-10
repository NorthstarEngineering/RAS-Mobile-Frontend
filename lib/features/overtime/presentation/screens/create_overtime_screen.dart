import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/di/service_locator.dart';
import '../../../employees/domain/entities/employee.dart';
import '../../../employees/domain/repositories/employee_repository.dart';
import '../../data/repositories/api_overtime_repository.dart';

class CreateOvertimeScreen extends StatefulWidget {
  const CreateOvertimeScreen({super.key});

  @override
  State<CreateOvertimeScreen> createState() => _CreateOvertimeScreenState();
}

class _CreateOvertimeScreenState extends State<CreateOvertimeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _rateController = TextEditingController();
  double _hours = 2.0;
  String _multiplier = '1.5x (عمل إضافي معتاد)';
  List<Employee> _employees = [];
  String? _selectedEmployeeId;
  bool _isSubmitting = false;

  double get _calculatedAmount {
    final rate = double.tryParse(_rateController.text) ?? 0;
    return _hours * rate;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await sl<EmployeeRepository>().getEmployees();
      if (mounted) {
        setState(() {
          _employees = employees
              .where((employee) => employee.status != EmployeeStatus.suspended)
              .toList();
          _selectedEmployeeId = _employees.isEmpty ? null : _employees.first.id;
          if (_employees.isNotEmpty) {
            _rateController.text = _employees.first.baseSalary.toStringAsFixed(
              2,
            );
          }
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تحميل الموظفين: $error')));
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final employeeId = _selectedEmployeeId;
    final rate = double.tryParse(_rateController.text);
    if (employeeId == null || rate == null || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر موظفاً وأدخل سعر الساعة')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await sl<ApiOvertimeRepository>().create(
        employeeId: employeeId,
        workDate: DateTime.now().toIso8601String().substring(0, 10),
        hours: _hours,
        ratePerHour: rate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الساعات الإضافية فعلياً')),
      );
      context.pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تسجيل الساعات الإضافية: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('إضافة ساعات عمل إضافية')),
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
                        const Icon(
                          Icons.badge_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'مصدر التسجيل:',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusFull,
                        ),
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
                            style: AppTypography.labelSm.copyWith(
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
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedEmployeeId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: _employees
                          .map(
                            (employee) => DropdownMenuItem(
                              value: employee.id,
                              child: Text(
                                employee.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedEmployeeId = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.paddingMd),

              TextFormField(
                controller: _rateController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'سعر الساعة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  return amount == null || amount <= 0
                      ? 'أدخل سعر الساعة'
                      : null;
                },
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
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
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
                          child: Text(
                            '1.5x (أيام العمل العادية)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: '2.0x (عطلات ومواسم رسمية)',
                          child: Text(
                            '2.0x (العطلات الرسمية والمواسم)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _multiplier = val ?? _multiplier),
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
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'اذكر سبب طلب العمل الإضافي وموافقة الإشراف',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'مطلوب' : null,
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
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
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
