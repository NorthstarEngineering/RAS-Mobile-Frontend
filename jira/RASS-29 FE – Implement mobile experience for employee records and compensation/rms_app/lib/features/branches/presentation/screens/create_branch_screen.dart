import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/routing/navigation_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/repositories/http_branch_repository.dart';
import '../../domain/entities/branch.dart';
import '../../domain/repositories/branch_repository.dart';

class CreateBranchScreen extends StatefulWidget {
  const CreateBranchScreen({super.key});

  @override
  State<CreateBranchScreen> createState() => _CreateBranchScreenState();
}

class _CreateBranchScreenState extends State<CreateBranchScreen> {
  late final BranchRepository _repository;
  final _nameController = TextEditingController(text: 'فرع الرحاب (#06)');
  final _codeController = TextEditingController(text: 'BR-06');
  final _phoneController = TextEditingController(text: '0226954120');
  final _addressController = TextEditingController(
    text: 'السوق الشرقي، مدينة الرحاب، القاهرة الجديدة',
  );
  final _managerController = TextEditingController(text: 'م. شريف حامد');
  final _workingHoursController = TextEditingController(
    text: '09:00 ص - 01:00 ص',
  );
  int _posTerminals = 4;
  bool _isMainBranch = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = sl.isRegistered<BranchRepository>()
        ? sl<BranchRepository>()
        : HttpBranchRepository();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _managerController.dispose();
    _workingHoursController.dispose();
    super.dispose();
  }

  void _saveBranch() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final manager = _managerController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اسم الفرع التشغيلي مطلوب'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كود الفرع مطلوب'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final workingHours = _workingHoursController.text.trim();
    if (workingHours.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ساعات تشغيل الفرع مطلوبة'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final newBranch = Branch(
        id: '',
        code: code,
        name: name,
        address: address,
        phone: phone,
        managerName: manager,
        employeeCount: 0,
        efficiencyRate: 98.4,
        type: BranchType.dining,
        isMain: _isMainBranch,
        isActive: true,
        workingHours: workingHours,
        posTerminalsCount: _posTerminals,
      );

      await _repository.createBranch(newBranch);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء الفرع الجديد بنجاح وإدراجه في شبكة الفروع!'),
          backgroundColor: Color(0xFF2E8B2E),
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل إنشاء الفرع: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
          onPressed: () => context.safePop(fallback: '/branches'),
        ),
        title: Text(
          'إنشاء فرع جديد',
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
              // Executive Clearance Banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Symbols.verified_user,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'صلاحية وصول تنفيذية: المدير التنفيذي (CEO)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusFull,
                        ),
                      ),
                      child: const Text(
                        'تصريح كامل',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Form Card
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Symbols.storefront,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'البيانات الأساسية للفرع',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Branch Name
                    Text(
                      'اسم الفرع التشغيلي *',
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Symbols.store),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Branch Code & Phone
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'كود الفرع *',
                                style: AppTypography.labelSm.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _codeController,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Symbols.qr_code),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'رقم هاتف الفرع *',
                                style: AppTypography.labelSm.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Symbols.phone),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Address
                    Text(
                      'العنوان الجغرافي الكامل *',
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Symbols.location_on),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Manager Name
                    Text(
                      'مدير الفرع المشرف',
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _managerController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Symbols.person),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Operational Configuration Card
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Symbols.settings,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'إعدادات التشغيل ونقاط البيع (POS)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Working Hours Field
                    Text(
                      'ساعات تشغيل الفرع *',
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _workingHoursController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Symbols.schedule),
                        hintText: 'مثال: 09:00 ص - 01:00 ص',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Terminals Stepper
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'عدد أجهزة نقاط البيع المصرح بها',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelMd,
                              ),
                              Text(
                                'تراخيص الكاشير والشاشات (KDS/POS)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Row(
                          children: [
                            IconButton.outlined(
                              icon: const Icon(Symbols.remove, size: 18),
                              onPressed: _posTerminals > 0
                                  ? () => setState(() => _posTerminals--)
                                  : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                '$_posTerminals',
                                style: AppTypography.headlineSm.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton.outlined(
                              icon: const Icon(Symbols.add, size: 18),
                              onPressed: () => setState(() => _posTerminals++),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.sm),

                    // Is Main Branch Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('تعيين كمقر رئيسي للعمليات'),
                      subtitle: const Text(
                        'تمنح صلاحيات التنسيق المركزي مع المستودع',
                      ),
                      activeThumbColor: AppColors.primary,
                      value: _isMainBranch,
                      onChanged: (val) => setState(() => _isMainBranch = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Submit Button
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveBranch,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Symbols.save),
                label: Text(
                  _isSaving ? 'جاري حفظ الفرع...' : 'إتمام تسجيل وإنشاء الفرع',
                ),
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
