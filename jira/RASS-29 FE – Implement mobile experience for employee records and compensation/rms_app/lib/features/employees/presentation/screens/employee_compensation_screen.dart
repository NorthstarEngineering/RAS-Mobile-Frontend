import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../../../core/di/service_locator.dart';

class EmployeeCompensationScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeCompensationScreen({super.key, required this.employee});

  @override
  State<EmployeeCompensationScreen> createState() => _EmployeeCompensationScreenState();
}

class _EmployeeCompensationScreenState extends State<EmployeeCompensationScreen> {
  Map<String, dynamic>? _compensationData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCompensation();
  }

  Future<void> _loadCompensation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final comp = await sl<EmployeeRepository>().getCompensation(widget.employee.id);
      if (!mounted) return;
      setState(() {
        _compensationData = comp;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'فشل تحميل بيانات الراتب: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    final comp = _compensationData;

    final isMonthly = employee.wageType == WageType.monthly;
    final baseSalaryVal = (comp?['baseSalary'] as num?)?.toDouble() ?? employee.baseSalary;
    final hourlyRateVal = (comp?['hourlyRate'] as num?)?.toDouble() ?? 
        (employee.wageType == WageType.hourly ? employee.baseSalary : 0.0);
    final effectiveSalary = isMonthly 
        ? baseSalaryVal 
        : (hourlyRateVal > 0 ? hourlyRateVal : baseSalaryVal);
    final wageUnit = isMonthly ? 'ج.م / شهر' : 'ج.م / ساعة';

    final housingAllowance = (comp?['housingAllowance'] as num?)?.toDouble() ?? 0.0;
    final transportAllowance = (comp?['transportAllowance'] as num?)?.toDouble() ?? 0.0;
    final totalAllowances = (comp?['totalAllowances'] as num?)?.toDouble() ?? (housingAllowance + transportAllowance);
    final totalDeductions = (comp?['totalDeductions'] as num?)?.toDouble() ?? 
        ((comp?['insuranceDeduction'] as num?)?.toDouble() ?? 0.0);
    final overtimeRate = (comp?['overtimeRate'] as num?)?.toDouble() ?? employee.overtimeRate;
    final grossPay = (comp?['grossPay'] as num?)?.toDouble() ?? (effectiveSalary + totalAllowances);
    final netPay = (comp?['netEstimatedPay'] as num?)?.toDouble() ?? (grossPay - totalDeductions);

    final effectiveDate = (comp?['effectiveDate'] ?? '01 نوفمبر 2023').toString();
    final reviewDate = (comp?['reviewDate'] ?? '01 مايو 2024').toString();
    final statusText = (comp?['status'] ?? 'نشط بالخدمة').toString();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('بيانات الراتب والتعويض'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'سجل الدفعات',
            onPressed: () => context.push(
              '/employees/${employee.id}/pay-history',
              extra: employee,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          style: AppTypography.bodyMd.copyWith(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _loadCompensation,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimens.paddingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Micro-banner alert
                      Container(
                        padding: const EdgeInsets.all(AppDimens.paddingMd),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                              ),
                              child: const Icon(
                                Icons.policy,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppDimens.paddingSm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'معيار نظام الأجور الصارم',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.labelMd.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceContainerHigh,
                                          borderRadius: BorderRadius.circular(
                                            AppDimens.radiusSm,
                                          ),
                                        ),
                                        child: Text(
                                          'RMS v2.4',
                                          style: AppTypography.labelSm.copyWith(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'يُمنع دمج أو خلط الأجر اليومي مع الراتب الشهري في قيود الحسابات.',
                                    style: AppTypography.bodySm.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimens.paddingMd),

                      // Employee Summary Snapshot
                      Container(
                        padding: const EdgeInsets.all(AppDimens.paddingMd),
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
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                employee.name.length >= 2
                                    ? employee.name.substring(0, 2)
                                    : 'مو',
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimens.paddingMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          employee.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.labelMd.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceContainer,
                                          borderRadius: BorderRadius.circular(
                                            AppDimens.radiusSm,
                                          ),
                                        ),
                                        child: Text(
                                          '#${employee.code}',
                                          style: AppTypography.labelSm.copyWith(
                                            fontSize: 10,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${employee.role} • ${employee.branchName}',
                                    style: AppTypography.bodySm.copyWith(
                                      color: AppColors.secondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF5EA),
                                borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                              ),
                              child: Text(
                                statusText,
                                style: AppTypography.labelSm.copyWith(
                                  color: const Color(0xFF2E8B2E),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimens.paddingLg),

                      // Active Structure Card
                      Container(
                        padding: const EdgeInsets.all(AppDimens.paddingLg),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(
                                        AppDimens.radiusFull,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_month,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            isMonthly
                                                ? 'نظام الراتب الشهري الثابت'
                                                : 'نظام اليومية والأجر بالساعة',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.labelSm.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Text(
                                  'حساب BOH معتمد',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.secondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimens.paddingMd),

                            // Wage Display
                            Container(
                              padding: const EdgeInsets.all(AppDimens.paddingLg),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'الراتب الأساسي الصافي المعتمد',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.labelSm.copyWith(
                                            color: AppColors.secondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              effectiveSalary.toStringAsFixed(0),
                                              style: AppTypography.headlineLg.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                wageUnit,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.labelMd.copyWith(
                                                  color: AppColors.secondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppDimens.paddingMd),
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerLowest,
                                      borderRadius: BorderRadius.circular(
                                        AppDimens.radiusLg,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.payments,
                                      color: AppColors.primary,
                                      size: 28,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppDimens.paddingMd),

                            // Dates Grid
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(AppDimens.paddingMd),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(
                                        AppDimens.radiusLg,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'تاريخ بدء السريان',
                                          style: AppTypography.labelSm.copyWith(
                                            color: AppColors.secondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          effectiveDate,
                                          style: AppTypography.labelMd.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(AppDimens.paddingMd),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(
                                        AppDimens.radiusLg,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'المراجعة الدورية',
                                          style: AppTypography.labelSm.copyWith(
                                            color: AppColors.secondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          reviewDate,
                                          style: AppTypography.labelMd.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimens.paddingLg),

                      // Programmed Rules & Deductions
                      Text(
                        'البنود والخصومات المبرمجة',
                        style: AppTypography.headlineSm.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'المعادلات الحسابية التلقائية لساعة الإغلاق ودفتر الحضور',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.secondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: AppDimens.paddingSm),

                      // Allowances
                      _buildRuleCard(
                        icon: Icons.restaurant,
                        title: 'إجمالي البدلات المعتمدة',
                        subtitle: 'بدل السكن (${housingAllowance.toStringAsFixed(0)} ج.م) + الانتقال (${transportAllowance.toStringAsFixed(0)} ج.م)',
                        amount: '+ ${totalAllowances.toStringAsFixed(0)} ج.م',
                        unit: 'شهرياً',
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 8),

                      // Deductions
                      _buildRuleCard(
                        icon: Icons.shield_outlined,
                        title: 'استقطاعات التأمينات والضرائب',
                        subtitle: 'خصم شهري معتمد من مسير الرواتب الرسمي',
                        amount: '- ${totalDeductions.toStringAsFixed(0)} ج.م',
                        unit: 'شهرياً',
                        color: AppColors.error,
                        isError: true,
                      ),
                      const SizedBox(height: 8),

                      // Overtime
                      _buildRuleCard(
                        icon: Icons.more_time,
                        title: 'استحقاق الساعات الإضافية',
                        subtitle: 'مُعتمد (يتطلب اعتماد كتابي مسبق من مدير الفرع)',
                        amount: '${overtimeRate.toStringAsFixed(0)} ج.م',
                        unit: 'لكل ساعة إضافية',
                        color: AppColors.tertiary,
                      ),
                      const SizedBox(height: 8),

                      // Net Pay
                      _buildRuleCard(
                        icon: Icons.account_balance_wallet,
                        title: 'صافي الراتب التقديري',
                        subtitle: 'الأساسي (${effectiveSalary.toStringAsFixed(0)}) + البدلات (${totalAllowances.toStringAsFixed(0)}) - الخصومات (${totalDeductions.toStringAsFixed(0)})',
                        amount: '${netPay.toStringAsFixed(0)} ج.م',
                        unit: 'الصافي المتوقع',
                        color: const Color(0xFF2E8B2E),
                      ),
                      const SizedBox(height: AppDimens.paddingLg),

                      // CTA Pay History
                      ElevatedButton.icon(
                        onPressed: () => context.push(
                          '/employees/${employee.id}/pay-history',
                          extra: employee,
                        ),
                        icon: const Icon(Icons.history_outlined),
                        label: const Text('عرض سجل الدفعات والرواتب السابقة'),
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
    );
  }

  Widget _buildRuleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String amount,
    required String unit,
    required Color color,
    bool isError = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
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
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isError
                  ? AppColors.errorContainer
                  : AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
            child: Icon(
              icon,
              color: isError ? AppColors.onErrorContainer : AppColors.onSurface,
              size: 20,
            ),
          ),
          const SizedBox(width: AppDimens.paddingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.secondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: AppTypography.labelMd.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                unit,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.secondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
