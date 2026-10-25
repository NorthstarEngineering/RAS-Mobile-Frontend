import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/routing/navigation_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/repositories/http_branch_repository.dart';
import '../../domain/entities/branch.dart';
import '../../domain/repositories/branch_repository.dart';

class BranchListScreen extends StatefulWidget {
  const BranchListScreen({super.key});

  @override
  State<BranchListScreen> createState() => _BranchListScreenState();
}

class _BranchListScreenState extends State<BranchListScreen> {
  late final BranchRepository _repository;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  final List<Branch> _branches = [];

  @override
  void initState() {
    super.initState();
    _repository = sl.isRegistered<BranchRepository>()
        ? sl<BranchRepository>()
        : HttpBranchRepository();
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await _repository.getBranches();
      if (mounted) {
        setState(() {
          _branches.clear();
          _branches.addAll(list);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل قائمة الفروع: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteBranch(Branch branch) async {
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
          'هل أنت متأكد من حذف فرع "${branch.name}"؟\nسيتم حذف الفرع وتوثيق العملية في سجل التدقيق.',
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

    try {
      await _repository.deleteBranch(branch.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف فرع "${branch.name}" بنجاح'),
          backgroundColor: const Color(0xFF2E8B2E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchBranches();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل حذف الفرع: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  List<Branch> get _filteredBranches {
    if (_searchQuery.trim().isEmpty) return _branches;
    return _branches.where((b) {
      return b.name.contains(_searchQuery) ||
          b.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.address.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.safePop(fallback: '/home');
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface.withValues(alpha: 0.9),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Symbols.arrow_forward, color: AppColors.onSurface),
            onPressed: () => context.safePop(fallback: '/home'),
          ),
        title: Text(
          'إدارة شبكة الفروع',
          style: AppTypography.headlineSm.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.add, color: AppColors.primary),
            tooltip: 'إضافة فرع جديد',
            onPressed: () async {
              final created = await context.push('/branches/create');
              if (created == true) {
                _fetchBranches();
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Symbols.add_business),
        label: const Text('إضافة فرع جديد'),
        onPressed: () => context.push('/branches/create'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header stats banner
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.margin,
                vertical: AppSpacing.sm,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'التحكم الميداني المباشر',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                          Text(
                            _isLoading && _branches.isEmpty
                                ? 'جاري التحميل...'
                                : '${_branches.where((b) => b.isActive).length} مواقع تشغيلية نشطة',
                            style: AppTypography.headlineSm.copyWith(
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusFull,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Symbols.hub,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _errorMessage != null ? 'تعذر الاتصال' : 'كافة الفروع متصلة',
                            style: AppTypography.labelSm.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _errorMessage != null ? AppColors.error : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.margin,
                vertical: AppSpacing.xs,
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'بحث باسم الفرع، الكود، أو العنوان...',
                  prefixIcon: const Icon(Symbols.search),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            const SizedBox(height: 8),

            // List of Branches
            Expanded(
              child: _isLoading && _branches.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null && _branches.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Symbols.error, size: 48, color: AppColors.error),
                              const SizedBox(height: 12),
                              Text(
                                'تعذر جلب بيانات الفروع: $_errorMessage',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMd.copyWith(color: AppColors.error),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _fetchBranches,
                                icon: const Icon(Symbols.refresh),
                                label: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        )
                      : _filteredBranches.isEmpty
                          ? Center(
                              child: Text(
                                _searchQuery.isNotEmpty
                                    ? 'لا توجد نتائج مطابقة للبحث'
                                    : 'لا توجد فروع مسجلة',
                                style: AppTypography.bodyMd.copyWith(color: AppColors.secondary),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _fetchBranches,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.margin,
                                  0,
                                  AppSpacing.margin,
                                  80,
                                ),
                                itemCount: _filteredBranches.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final branch = _filteredBranches[index];
                                  return _buildBranchCard(branch);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildBranchCard(Branch branch) {
    final isKitchen = branch.type == BranchType.kitchen;

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      elevation: 0.5,
      child: InkWell(
        onTap: () async {
          if (isKitchen) {
            await context.push('/branches/central-kitchen');
          } else {
            final updated =
                await context.push('/branches/${branch.id}', extra: branch);
            if (updated == true) {
              _fetchBranches();
            }
          }
        },
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isKitchen
                                ? AppColors.surfaceContainerHigh
                                : AppColors.primaryFixed,
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusSm,
                            ),
                          ),
                          child: Text(
                            branch.code,
                            style: AppTypography.labelSm.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: isKitchen
                                  ? AppColors.onSurface
                                  : AppColors.onPrimaryFixedVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            branch.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (branch.isMain)
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
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                branch.address,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.secondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1, color: AppColors.surfaceContainer),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Symbols.badge,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${branch.employeeCount} موظف',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Symbols.point_of_sale,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${branch.posTerminalsCount} نقاط بيع',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'كفاءة ${branch.efficiencyRate}%',
                        style: AppTypography.labelSm.copyWith(
                          color: const Color(0xFF2E8B2E),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Symbols.delete_outline,
                          size: 20,
                          color: AppColors.error,
                        ),
                        tooltip: 'حذف الفرع',
                        onPressed: () => _deleteBranch(branch),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Symbols.chevron_left,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
