import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/branch.dart';

class BranchDetailsScreen extends StatefulWidget {
  final Branch? branch;

  const BranchDetailsScreen({super.key, this.branch});

  @override
  State<BranchDetailsScreen> createState() => _BranchDetailsScreenState();
}

class _BranchDetailsScreenState extends State<BranchDetailsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _managerController;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.branch ??
        const Branch(
          id: 'br_1',
          code: 'BR-01',
          name: 'فرع وسط البلد (#01)',
          address: '24 شارع طلعت حرب، وسط البلد، القاهرة',
          phone: '0223957810',
          managerName: 'م. حسام السيد',
          employeeCount: 18,
          efficiencyRate: 99.1,
          isMain: true,
          posTerminalsCount: 5,
        );
    _nameController = TextEditingController(text: b.name);
    _phoneController = TextEditingController(text: b.phone);
    _addressController = TextEditingController(text: b.address);
    _managerController = TextEditingController(text: b.managerName);
    _isActive = b.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _managerController.dispose();
    super.dispose();
  }

  void _saveChanges() async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ وتحديث بيانات الفرع بنجاح!'),
        backgroundColor: Color(0xFF2E8B2E),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.branch ??
        const Branch(
          id: 'br_1',
          code: 'BR-01',
          name: 'فرع وسط البلد (#01)',
          address: '24 شارع طلعت حرب، وسط البلد، القاهرة',
          phone: '0223957810',
          managerName: 'م. حسام السيد',
          employeeCount: 18,
          efficiencyRate: 99.1,
          isMain: true,
          posTerminalsCount: 5,
        );

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
          'تفاصيل وتعديل الفرع',
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
              // Branch Profile Overview Card
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryFixed,
                                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                              ),
                              child: Text(
                                b.code,
                                style: AppTypography.labelSm.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: AppColors.onPrimaryFixedVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (b.isMain)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF5EA),
                                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                                ),
                                child: Text(
                                  'المقر الرئيسي',
                                  style: AppTypography.labelSm.copyWith(
                                    color: const Color(0xFF2E8B2E),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isActive ? const Color(0xFFEAF5EA) : AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                          ),
                          child: Text(
                            _isActive ? 'تشغيل نشط' : 'موقف مؤقتاً',
                            style: AppTypography.labelSm.copyWith(
                              color: _isActive ? const Color(0xFF2E8B2E) : AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(b.name, style: AppTypography.headlineSm),
                    Text(b.address, style: AppTypography.bodySm.copyWith(color: AppColors.secondary)),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('الموظفون', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                              Text('${b.employeeCount} موظف', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('نقاط البيع', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                              Text('${b.posTerminalsCount} نقاط', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('الكفاءة التشغيلية', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                              Text('${b.efficiencyRate}%', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF2E8B2E))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Edit Form Card
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تعديل البيانات الميدانية', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.md),

                    // Name
                    Text('اسم الفرع', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Symbols.store)),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Phone
                    Text('رقم الهاتف', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Symbols.phone)),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Address
                    Text('العنوان', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Symbols.location_on)),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Manager
                    Text('مدير الفرع المشرف', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _managerController,
                      decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Symbols.person)),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Active Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('حالة تشغيل الفرع'),
                      subtitle: Text(_isActive ? 'الفرع يستقبل الطلبات ويعمل بانتظام' : 'الفرع موقف مؤقتاً عن استقبال الطلبات'),
                      activeThumbColor: AppColors.primary,
                      value: _isActive,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Buttons
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveChanges,
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Symbols.save),
                label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ تعديلات الفرع'),
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
