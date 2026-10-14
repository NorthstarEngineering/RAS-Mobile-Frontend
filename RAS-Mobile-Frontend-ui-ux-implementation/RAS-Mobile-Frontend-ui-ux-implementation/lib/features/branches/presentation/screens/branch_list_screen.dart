import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/branch.dart';
import '../../data/repositories/api_branch_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_exception.dart';

class BranchListScreen extends StatefulWidget {
  const BranchListScreen({super.key});

  @override
  State<BranchListScreen> createState() => _BranchListScreenState();
}

class _BranchListScreenState extends State<BranchListScreen> {
  String _searchQuery = '';
  List<Branch> _branches = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await sl<ApiBranchRepository>().getBranches();
      if (!mounted) return;
      setState(() {
        _branches = result;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = arabicApiMessage(error);
        _isLoading = false;
      });
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
          'إدارة شبكة الفروع',
          style: AppTypography.headlineSm.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.add, color: AppColors.primary),
            tooltip: 'إضافة فرع جديد',
            onPressed: () => context.push('/branches/create'),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'التحكم الميداني المباشر',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.secondary,
                          ),
                        ),
                        Text(
                          '${_branches.length} مواقع تشغيلية',
                          style: AppTypography.headlineSm.copyWith(
                            fontSize: 16,
                          ),
                        ),
                      ],
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
                        children: [
                          const Icon(
                            Symbols.hub,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'كافة الفروع متصلة',
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          TextButton(
                            onPressed: _loadBranches,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    )
                  : _filteredBranches.isEmpty
                  ? const Center(child: Text('لا توجد فروع متاحة'))
                  : ListView.separated(
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
          ],
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
        onTap: () {
          if (isKitchen) {
            context.push('/branches/central-kitchen');
          } else {
            context.push('/branches/${branch.id}', extra: branch);
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
                  Row(
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
                      Text(
                        branch.name,
                        style: AppTypography.labelMd.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
                  Row(
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
                      Text(
                        '${branch.posTerminalsCount} نقاط بيع',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
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
