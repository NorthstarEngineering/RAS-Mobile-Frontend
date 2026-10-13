import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../../../core/di/service_locator.dart';

class EditEmployeeScreen extends StatefulWidget {
  const EditEmployeeScreen({
    super.key,
    required this.employee,
  });

  final Employee employee;

  @override
  State<EditEmployeeScreen> createState() => _EditEmployeeScreenState();
}

class _EditEmployeeScreenState extends State<EditEmployeeScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _roleController;
  late final TextEditingController _phoneController;
  late final TextEditingController _salaryController;
  late final TextEditingController _overtimeController;

  late WageType _wageType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.employee.name);
    _roleController = TextEditingController(text: widget.employee.role);
    _phoneController = TextEditingController(text: widget.employee.phone);
    _salaryController =
        TextEditingController(text: widget.employee.baseSalary.toStringAsFixed(0));
    _overtimeController =
        TextEditingController(text: widget.employee.overtimeRate.toStringAsFixed(0));
    _wageType = widget.employee.wageType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _phoneController.dispose();
    _salaryController.dispose();
    _overtimeController.dispose();
    super.dispose();
  }

  void _onSave() async {
    setState(() => _isLoading = true);

    final updated = Employee(
      id: widget.employee.id,
      code: widget.employee.code,
      name: _nameController.text.trim(),
      role: _roleController.text.trim(),
      branchName: widget.employee.branchName,
      branchCode: widget.employee.branchCode,
      status: widget.employee.status,
      wageType: _wageType,
      baseSalary: double.tryParse(_salaryController.text) ?? widget.employee.baseSalary,
      overtimeRate: double.tryParse(_overtimeController.text) ?? widget.employee.overtimeRate,
      phone: _phoneController.text.trim(),
      managerName: widget.employee.managerName,
      totalHoursThisMonth: widget.employee.totalHoursThisMonth,
      department: widget.employee.department,
    );

    await sl<EmployeeRepository>().updateEmployee(updated);

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ بيانات الموظف والراتب بنجاح'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_forward, color: AppColors.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'تعديل الموظف #${widget.employee.code}',
          style: AppTypography.headlineSm.copyWith(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.margin,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RmsTextField(
                      label: 'اسم الموظف الثلاثي',
                      controller: _nameController,
                      prefixIcon: Symbols.badge,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    RmsTextField(
                      label: 'المسمى الوظيفي',
                      controller: _roleController,
                      prefixIcon: Symbols.work,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    RmsTextField(
                      label: 'رقم الهاتف المعتمد',
                      controller: _phoneController,
                      prefixIcon: Symbols.call,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Wage Type Selector
                    Text('نوع الراتب والتعويض', style: AppTypography.labelMd),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('راتب شهري'),
                            selected: _wageType == WageType.monthly,
                            onSelected: (val) =>
                                setState(() => _wageType = WageType.monthly),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('بالساعة (Hourly)'),
                            selected: _wageType == WageType.hourly,
                            onSelected: (val) =>
                                setState(() => _wageType = WageType.hourly),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    RmsTextField(
                      label: _wageType == WageType.monthly
                          ? 'الراتب الأساسي (ج.م / شهر)'
                          : 'سعر الساعة الأساسية (ج.م)',
                      controller: _salaryController,
                      prefixIcon: Symbols.payments,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    RmsTextField(
                      label: 'سعر الساعة الإضافية Overtime (ج.م)',
                      controller: _overtimeController,
                      prefixIcon: Symbols.more_time,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    RmsPrimaryButton(
                      label: 'حفظ التعديلات (EMP-03)',
                      loadingLabel: 'جاري الحفظ...',
                      icon: Symbols.save,
                      isLoading: _isLoading,
                      onPressed: _onSave,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
