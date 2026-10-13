import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

class CreateEmployeeScreen extends StatefulWidget {
  const CreateEmployeeScreen({super.key});

  @override
  State<CreateEmployeeScreen> createState() => _CreateEmployeeScreenState();
}

class _CreateEmployeeScreenState extends State<CreateEmployeeScreen> {
  final _nameController = TextEditingController(text: 'كريم محمود عبد الله');
  final _phoneController = TextEditingController(text: '01098765432');
  final _nationalIdController = TextEditingController(text: '29408151203456');
  final _salaryController = TextEditingController(text: '4200');
  final _overtimeRateController = TextEditingController(text: '35');
  final _pinController = TextEditingController(text: '1052');

  String _selectedRole = 'كاشير (POS Cashier)';
  String _selectedBranch = 'فرع وسط البلد (#01)';
  bool _isMonthly = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    _salaryController.dispose();
    _overtimeRateController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _submitEmployee() async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تسجيل وتعيين الموظف بنجاح في قاعدة بيانات الفرع!'),
        backgroundColor: Color(0xFF2E8B2E),
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
        leading: IconButton(
          icon: const Icon(Symbols.arrow_forward, color: AppColors.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'تعيين موظف جديد',
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
              // BOH Context banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Symbols.badge, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'بوابة الموارد البشرية التشغيلية (BOH)',
                          style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                      ),
                      child: Text(
                        'وضع مدير الفرع',
                        style: AppTypography.labelSm.copyWith(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Avatar Uploader Card
              RmsCard(
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Symbols.person_add, color: AppColors.secondary, size: 30),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('صورة الهوية المهنية', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                          Text('تُعرض على شاشات نقاط البيع (POS/KDS)', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Symbols.upload, size: 16),
                      label: const Text('رفع صورة'),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Section 1: البيانات الأساسية
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('البيانات الأساسية للموظف *', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.md),

                    // Name
                    Text('الاسم القانوني الكامل *', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Symbols.badge)),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Role
                    Text('المسمى الوظيفي التشغيلي *', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedRole,
                      decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Symbols.work)),
                      items: const [
                        DropdownMenuItem(value: 'كاشير (POS Cashier)', child: Text('كاشير (POS Cashier)')),
                        DropdownMenuItem(value: 'مشرف صالة (Floor Supervisor)', child: Text('مشرف صالة (Floor Supervisor)')),
                        DropdownMenuItem(value: 'طاهي خط ساخن (Hot Line Cook)', child: Text('طاهي خط ساخن (Hot Line Cook)')),
                        DropdownMenuItem(value: 'عامل تحضير (Prep Staff)', child: Text('عامل تحضير (Prep Staff)')),
                        DropdownMenuItem(value: 'سائق توصيل (Delivery Driver)', child: Text('سائق توصيل (Delivery Driver)')),
                      ],
                      onChanged: (val) => setState(() => _selectedRole = val ?? _selectedRole),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Phone & National ID
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('رقم الهاتف *', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Symbols.phone)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('الرقم القومي (14 رقم)', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _nationalIdController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Symbols.pin)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Section 2: تعيين الفرع وبيانات POS
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('بيانات التعيين ونقاط البيع (POS)', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.md),

                    // Branch select
                    Text('الفرع المخصص للعمل *', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedBranch,
                      decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Symbols.store)),
                      items: const [
                        DropdownMenuItem(value: 'فرع وسط البلد (#01)', child: Text('فرع وسط البلد (#01)')),
                        DropdownMenuItem(value: 'فرع المعادي (#02)', child: Text('فرع المعادي (#02)')),
                        DropdownMenuItem(value: 'فرع مصر الجديدة (#03)', child: Text('فرع مصر الجديدة (#03)')),
                        DropdownMenuItem(value: 'فرع التجمع الخامس (#04)', child: Text('فرع التجمع الخامس (#04)')),
                      ],
                      onChanged: (val) => setState(() => _selectedBranch = val ?? _selectedBranch),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // POS PIN
                    Text('رمز المرور السريع للوردية (PIN - 4 أرقام) *', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Symbols.key)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Section 3: هيكل الراتب والتعويض
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('هيكل الراتب والتعويض المعتمد *', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.md),

                    // Wage Type Toggle
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('راتب شهري ثابت')),
                            selected: _isMonthly,
                            onSelected: (val) => setState(() => _isMonthly = true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('حساب بالساعة / يومية')),
                            selected: !_isMonthly,
                            onSelected: (val) => setState(() => _isMonthly = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Base Salary & Overtime Rate
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_isMonthly ? 'الراتب الأساسي (ج.م) *' : 'أجر الساعة (ج.م) *', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _salaryController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Symbols.payments)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('أجر الساعة الإضافية (ج.م) *', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _overtimeRateController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Symbols.more_time)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Submit Button
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _submitEmployee,
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Symbols.person_add),
                label: Text(_isSaving ? 'جاري تعيين الموظف...' : 'إتمام تسجيل وتعيين الموظف'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
