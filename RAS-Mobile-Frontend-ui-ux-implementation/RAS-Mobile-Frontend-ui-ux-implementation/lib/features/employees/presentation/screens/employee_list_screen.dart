import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_exception.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final _searchController = TextEditingController();
  List<Employee> _allEmployees = [];
  List<Employee> _filteredEmployees = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'all'; // all, monthly, hourly, active

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await sl<EmployeeRepository>().getEmployees();
      if (!mounted) return;
      setState(() {
        _allEmployees = list;
        _filteredEmployees = list;
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

  void _onSearch(String query) {
    _applyFilters(query, _selectedFilter);
  }

  void _onFilterChange(String filter) {
    setState(() => _selectedFilter = filter);
    _applyFilters(_searchController.text, filter);
  }

  void _applyFilters(String query, String filter) {
    var result = _allEmployees;
    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      result = result.where((e) {
        return e.name.toLowerCase().contains(q) ||
            e.code.toLowerCase().contains(q) ||
            e.role.toLowerCase().contains(q);
      }).toList();
    }

    if (filter == 'monthly') {
      result = result.where((e) => e.wageType == WageType.monthly).toList();
    } else if (filter == 'daily') {
      result = result.where((e) => e.wageType == WageType.daily).toList();
    } else if (filter == 'active') {
      result = result
          .where(
            (e) =>
                e.status == EmployeeStatus.active ||
                e.status == EmployeeStatus.activeOnShift,
          )
          .toList();
    }

    setState(() => _filteredEmployees = result);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          'قائمة الموظفين والرواتب',
          style: AppTypography.headlineSm.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.person_add, color: AppColors.primary),
            tooltip: 'تعيين موظف جديد',
            onPressed: () => context.push('/employees/create'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Symbols.person_add),
        label: const Text('تعيين موظف جديد'),
        onPressed: () => context.push('/employees/create'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.margin,
                vertical: AppSpacing.xs,
              ),
              child: Container(
                height: AppSizes.controlHeight,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: AppRadius.lgAll,
                  boxShadow: AppShadows.sm,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  style: AppTypography.bodyMd,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم، الرقم (#1052)، أو المسمى...',
                    hintStyle: AppTypography.bodySm.copyWith(
                      color: AppColors.secondary,
                    ),
                    prefixIcon: const Icon(Symbols.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Symbols.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: AppRadius.lgAll,
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.margin,
              ),
              child: Row(
                children: [
                  _buildFilterChip('all', 'الكل (${_allEmployees.length})'),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterChip('monthly', 'راتب شهري'),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterChip('daily', 'راتب يومي'),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterChip('active', 'نشط الآن'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Employee List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          TextButton(
                            onPressed: _loadEmployees,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    )
                  : _filteredEmployees.isEmpty
                  ? Center(
                      child: Text(
                        'لا يوجد موظفون مطابقون للبحث',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.margin,
                        0,
                        AppSpacing.margin,
                        AppSpacing.xl,
                      ),
                      itemCount: _filteredEmployees.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final emp = _filteredEmployees[index];
                        return _buildEmployeeCard(emp);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String id, String label) {
    final isSelected = _selectedFilter == id;
    return GestureDetector(
      onTap: () => _onFilterChange(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.fullAll,
          boxShadow: AppShadows.sm,
        ),
        child: Text(
          label,
          style: AppTypography.labelSm.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(Employee emp) {
    final isOnShift = emp.status == EmployeeStatus.activeOnShift;

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: AppRadius.xlAll,
      elevation: 0.5,
      child: InkWell(
        onTap: () => context.push('/employees/${emp.id}', extra: emp),
        borderRadius: AppRadius.xlAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Profile Line
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: AppColors.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emp.initials,
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Name & Role
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                emp.name,
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceContainer,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(4),
                                ),
                              ),
                              child: Text(
                                '#${emp.code}',
                                style: AppTypography.labelSm.copyWith(
                                  fontSize: 11,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${emp.role} | ${emp.branchName} (${emp.branchCode})',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.secondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isOnShift
                          ? const Color(0xFFE8F5E9)
                          : AppColors.surfaceContainerLow,
                      borderRadius: AppRadius.fullAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isOnShift) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2E8B2E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          emp.status.titleArabic,
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOnShift
                                ? const Color(0xFF2E8B2E)
                                : AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Salary Strip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppRadius.lgAll,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Symbols.payments,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          emp.wageType == WageType.monthly
                              ? 'راتب شهري: ${emp.baseSalary.toStringAsFixed(0)} ج.م'
                              : 'أجر يومي: ${emp.baseSalary.toStringAsFixed(0)} ج.م',
                          style: AppTypography.labelSm.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'التفاصيل',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Symbols.chevron_left,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
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
