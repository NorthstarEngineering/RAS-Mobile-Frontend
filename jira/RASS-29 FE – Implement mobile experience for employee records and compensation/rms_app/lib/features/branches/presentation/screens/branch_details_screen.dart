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

class BranchDetailsScreen extends StatefulWidget {
  final Branch? branch;
  final String? branchId;
  final BranchRepository? repository;

  const BranchDetailsScreen({
    super.key,
    this.branch,
    this.branchId,
    this.repository,
  });

  @override
  State<BranchDetailsScreen> createState() => _BranchDetailsScreenState();
}

class _BranchDetailsScreenState extends State<BranchDetailsScreen> {
  late final BranchRepository _repository;
  Branch? _branch;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _managerController;
  late final TextEditingController _workingHoursController;
  late int _posTerminals;
  bool _isActive = true;
  bool _isSaving = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isEditingDirty = false;
  bool _isPopulating = false;
  bool _dependenciesInitialized = false;
  String? _resolvedId;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (sl.isRegistered<BranchRepository>()
            ? sl<BranchRepository>()
            : HttpBranchRepository());

    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _managerController = TextEditingController();
    _workingHoursController = TextEditingController();
    _posTerminals = 0;

    _nameController.addListener(_onFormFieldChanged);
    _phoneController.addListener(_onFormFieldChanged);
    _addressController.addListener(_onFormFieldChanged);
    _managerController.addListener(_onFormFieldChanged);
    _workingHoursController.addListener(_onFormFieldChanged);

    if (widget.branch != null) {
      _populateFromBranch(widget.branch!);
    } else if (widget.branchId != null && widget.branchId!.isNotEmpty) {
      _resolvedId = widget.branchId;
      _isLoading = true;
      _fetchBranch(_resolvedId!);
    } else {
      _isLoading = true;
    }
  }

  void _onFormFieldChanged() {
    if (!_isPopulating && !_isEditingDirty && _branch != null) {
      _isEditingDirty = true;
    }
  }

  void _populateFromBranch(Branch b) {
    _isPopulating = true;
    _branch = b;
    _nameController.text = b.name;
    _phoneController.text = b.phone;
    _addressController.text = b.address;
    _managerController.text = b.managerName;
    _workingHoursController.text = b.workingHours;
    _posTerminals = b.posTerminalsCount;
    _isActive = b.isActive;
    _isEditingDirty = false;
    _isPopulating = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dependenciesInitialized) {
      _dependenciesInitialized = true;
      if (_branch == null && (_resolvedId == null || _resolvedId!.isEmpty)) {
        String? id = widget.branchId ?? widget.branch?.id;
        if (id == null || id.isEmpty) {
          try {
            final state = GoRouterState.of(context);
            id = state.pathParameters['id'] ?? state.uri.queryParameters['id'];
          } catch (_) {
            // Standalone or non-GoRouter test environment
          }
        }
        _resolvedId = id;
        if (id == null || id.trim().isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'معرف الفرع مطلوب';
          });
        } else {
          _fetchBranch(id.trim());
        }
      }
    }
  }

  Future<void> _fetchBranch(String id) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fetched = await _repository.getBranchById(id);
      if (!mounted) return;

      if (fetched == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'الفرع غير موجود (404)';
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
          if (!_isEditingDirty) {
            _populateFromBranch(fetched);
          } else {
            _branch = fetched;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (_branch == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحديث بيانات الفرع: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormFieldChanged);
    _phoneController.removeListener(_onFormFieldChanged);
    _addressController.removeListener(_onFormFieldChanged);
    _managerController.removeListener(_onFormFieldChanged);
    _workingHoursController.removeListener(_onFormFieldChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _managerController.dispose();
    _workingHoursController.dispose();
    super.dispose();
  }

  void _saveChanges() async {
    final b = _branch;
    if (b == null) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اسم الفرع مطلوب'),
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
      final updatedBranch = Branch(
        id: b.id,
        code: b.code,
        name: name,
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        managerName: _managerController.text.trim(),
        employeeCount: b.employeeCount,
        efficiencyRate: b.efficiencyRate,
        type: b.type,
        isMain: b.isMain,
        isActive: _isActive,
        workingHours: workingHours,
        posTerminalsCount: _posTerminals,
      );

      final acknowledged = await _repository.updateBranch(updatedBranch);
      if (!mounted) return;
      setState(() {
        _populateFromBranch(acknowledged);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ وتحديث بيانات الفرع بنجاح!'),
          backgroundColor: Color(0xFF2E8B2E),
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل حفظ بيانات الفرع: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmAndDeleteBranch() async {
    final b = _branch;
    if (b == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Symbols.warning, color: AppColors.error),
            SizedBox(width: 8),
            Text('تأكيد حذف الفرع'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف فرع "${b.name}"؟\nسيتم حذف الفرع وتوثيق العملية في سجل التدقيق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف الفرع'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await _repository.deleteBranch(b.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف فرع "${b.name}" بنجاح'),
          backgroundColor: const Color(0xFF2E8B2E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل حذف الفرع: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface.withValues(alpha: 0.9),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Symbols.arrow_forward, color: AppColors.onSurface),
        onPressed: () => context.safePop(fallback: '/branches'),
      ),
      title: Text(
        'تفاصيل وتعديل الفرع',
        style: AppTypography.headlineSm.copyWith(fontSize: 18),
      ),
      actions: [
        if (_branch != null)
          IconButton(
            icon: const Icon(Symbols.delete_outline, color: AppColors.error),
            tooltip: 'حذف الفرع',
            onPressed: (_isLoading || _isSaving) ? null : _confirmAndDeleteBranch,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _branch == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: _buildAppBar(context),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null && _branch == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: _buildAppBar(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Symbols.error, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd.copyWith(color: AppColors.error),
                ),
                const SizedBox(height: 16),
                if (_resolvedId != null && _resolvedId!.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _fetchBranch(_resolvedId!),
                    icon: const Icon(Symbols.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final b = _branch;
    if (b == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: _buildAppBar(context),
        body: const Center(
          child: Text('معرف الفرع مطلوب'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final id = _resolvedId ?? _branch?.id;
            if (id != null && id.isNotEmpty) {
              await _fetchBranch(id);
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                        Expanded(
                          child: Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryFixed,
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusSm,
                                  ),
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
                              if (b.isMain)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF5EA),
                                    borderRadius: BorderRadius.circular(
                                      AppDimens.radiusFull,
                                    ),
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
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _isActive
                                ? const Color(0xFFEAF5EA)
                                : AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusFull,
                            ),
                          ),
                          child: Text(
                            _isActive ? 'تشغيل نشط' : 'موقف مؤقتاً',
                            style: AppTypography.labelSm.copyWith(
                              color: _isActive
                                  ? const Color(0xFF2E8B2E)
                                  : AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(b.name, style: AppTypography.headlineSm),
                    Text(
                      b.address,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الموظفون',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                              Text(
                                '${b.employeeCount} موظف',
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'نقاط البيع',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                              Text(
                                '${b.posTerminalsCount} نقاط',
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الكفاءة التشغيلية',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                              Text(
                                '${b.efficiencyRate}%',
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2E8B2E),
                                ),
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

              // Edit Form Card
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تعديل البيانات الميدانية',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Name
                    Text(
                      'اسم الفرع',
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

                    // Phone
                    Text(
                      'رقم الهاتف',
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Symbols.phone),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Address
                    Text(
                      'العنوان',
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

                    // Manager
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

                    // POS Terminals Stepper
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
                                  ? () => setState(() {
                                        _posTerminals--;
                                        _isEditingDirty = true;
                                      })
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
                              onPressed: () => setState(() {
                                _posTerminals++;
                                _isEditingDirty = true;
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Active Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('حالة تشغيل الفرع'),
                      subtitle: Text(
                        _isActive
                            ? 'الفرع يستقبل الطلبات ويعمل بانتظام'
                            : 'الفرع موقف مؤقتاً عن استقبال الطلبات',
                      ),
                      activeThumbColor: AppColors.primary,
                      value: _isActive,
                      onChanged: (val) => setState(() {
                        _isActive = val;
                        _isEditingDirty = true;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Buttons
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveChanges,
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
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: (_isLoading || _isSaving) ? null : _confirmAndDeleteBranch,
                icon: const Icon(Symbols.delete_forever, color: AppColors.error),
                label: const Text('حذف الفرع نهائياً من النظام'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
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
    ),
  );
}
}
