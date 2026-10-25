import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/routing/navigation_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/employee.dart';

import '../../domain/repositories/employee_repository.dart';
import '../../../../core/di/service_locator.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  const EmployeeDetailsScreen({super.key, required this.employee});

  final Employee employee;

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  late Employee _employee;

  @override
  void initState() {
    super.initState();
    _employee = widget.employee;
    _refreshEmployee();
  }

  Future<void> _refreshEmployee() async {
    try {
      final updated = await sl<EmployeeRepository>().getEmployeeById(widget.employee.id);
      if (updated != null && mounted) {
        setState(() => _employee = updated);
      }
    } catch (_) {}
  }

  Future<void> _confirmAndDeleteEmployee() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Symbols.warning, color: AppColors.error),
            SizedBox(width: 8),
            Text('تأكيد حذف الموظف'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف الموظف "${_employee.name}" (#${_employee.code})؟\nسيتم حذف الموظف نهائياً وتوثيق الإجراء في سجل التدقيق.',
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
            child: const Text('حذف الموظف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await sl<EmployeeRepository>().deleteEmployee(_employee.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف الموظف "${_employee.name}" بنجاح'),
          backgroundColor: const Color(0xFF2E8B2E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل حذف الموظف: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = _employee;
    final isOnShift = employee.status == EmployeeStatus.activeOnShift;
    final estimatedPay = employee.wageType == WageType.hourly
        ? (employee.baseSalary * employee.totalHoursThisMonth)
        : employee.baseSalary;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_forward, color: AppColors.onSurface),
          onPressed: () => context.safePop(fallback: '/employees'),
        ),
        title: Text(
          'ملف الموظف #${employee.code}',
          style: AppTypography.headlineSm.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.edit, color: AppColors.primary),
            onPressed: () async {
              final res = await context.push<bool>(
                '/employees/${employee.id}/edit',
                extra: employee,
              );
              if (res == true && mounted) {
                await _refreshEmployee();
                if (context.mounted) context.pop(true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Symbols.delete_outline, color: AppColors.error),
            tooltip: 'حذف الموظف',
            onPressed: _confirmAndDeleteEmployee,
          ),
        ],
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
              // Profile Summary Header Card
              RmsCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryFixed,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            employee.initials,
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.onPrimaryFixed,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employee.name,
                                style: AppTypography.headlineSm.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                employee.role,
                                style: AppTypography.labelMd.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1, color: AppColors.surfaceContainer),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildMetaItem(
                            'الفرع',
                            '${employee.branchName} (${employee.branchCode})',
                          ),
                        ),
                        Expanded(
                          child: _buildMetaItem(
                            'الحالة',
                            employee.status.titleArabic,
                            color: isOnShift
                                ? AppColors.success
                                : AppColors.secondary,
                          ),
                        ),
                        Expanded(
                          child: _buildMetaItem('القسم', employee.department),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Manager Contact Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: AppRadius.xlAll,
                  boxShadow: AppShadows.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Symbols.supervisor_account,
                              size: 20,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'المدير المباشر',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.secondary,
                                  ),
                                ),
                                Text(
                                  employee.managerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelMd.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Symbols.call, color: AppColors.primary),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'الاتصال بـ ${employee.managerName}...',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Financial & Compensation Structure Card
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RmsSectionHeader(
                      icon: Symbols.payments,
                      title: 'هيكل التعويض والراتب المالي',
                      trailing: RmsChip(
                        label: employee.wageType.titleArabic,
                        tone: RmsChipTone.neutral,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricBox(
                            'الراتب الأساسي',
                            employee.wageType == WageType.monthly
                                ? '${employee.baseSalary.toStringAsFixed(0)} ج.م'
                                : '${employee.baseSalary.toStringAsFixed(0)} ج.م / ساعة',
                            Symbols.account_balance_wallet,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _buildMetricBox(
                            'الساعة الإضافية',
                            '${employee.overtimeRate.toStringAsFixed(0)} ج.م',
                            Symbols.more_time,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricBox(
                            'ساعات الشهر الحالية',
                            '${employee.totalHoursThisMonth} س',
                            Symbols.schedule,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _buildMetricBox(
                            'الاستحقاق التقديري',
                            '~ ${estimatedPay.toStringAsFixed(0)} ج.م',
                            Symbols.trending_up,
                            valueColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Action Buttons
              RmsPrimaryButton(
                label: 'تعديل بيانات الموظف والراتب',
                icon: Symbols.edit,
                onPressed: () async {
                  final res = await context.push<bool>(
                    '/employees/${employee.id}/edit',
                    extra: employee,
                  );
                  if (res == true && mounted) {
                    await _refreshEmployee();
                    if (context.mounted) context.pop(true);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.controlHeight),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.lgAll,
                  ),
                  side: const BorderSide(color: AppColors.surfaceContainerHigh),
                ),
                icon: const Icon(
                  Symbols.payments,
                  size: 20,
                  color: AppColors.onSurface,
                ),
                label: Text(
                  'بيانات الراتب والتعويض المعتمد (EMP-05)',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                onPressed: () => context.push(
                  '/employees/${employee.id}/compensation',
                  extra: employee,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.controlHeight),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.lgAll,
                  ),
                  side: const BorderSide(color: AppColors.surfaceContainerHigh),
                ),
                icon: const Icon(
                  Symbols.receipt_long,
                  size: 20,
                  color: AppColors.onSurface,
                ),
                label: Text(
                  'سجل الرواتب والدفعات التاريخي (EMP-06)',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                onPressed: () => context.push(
                  '/employees/${employee.id}/pay-history',
                  extra: employee,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.controlHeight),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.lgAll,
                  ),
                  side: const BorderSide(color: AppColors.error),
                  foregroundColor: AppColors.error,
                ),
                icon: const Icon(
                  Symbols.delete_forever,
                  size: 20,
                  color: AppColors.error,
                ),
                label: Text(
                  'حذف الموظف نهائياً من النظام',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _confirmAndDeleteEmployee,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.secondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelMd.copyWith(
            fontWeight: FontWeight.w700,
            color: color ?? AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.secondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.secondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.labelMd.copyWith(
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
