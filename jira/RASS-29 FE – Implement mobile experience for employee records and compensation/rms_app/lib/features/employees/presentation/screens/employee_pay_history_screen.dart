import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../../../core/di/service_locator.dart';

class EmployeePayHistoryScreen extends StatefulWidget {
  final Employee employee;

  const EmployeePayHistoryScreen({super.key, required this.employee});

  @override
  State<EmployeePayHistoryScreen> createState() => _EmployeePayHistoryScreenState();
}

class _EmployeePayHistoryScreenState extends State<EmployeePayHistoryScreen> {
  List<Map<String, dynamic>> _payRecords = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPayHistory();
  }

  Future<void> _loadPayHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final records = await sl<EmployeeRepository>().getPayHistory(widget.employee.id);
      if (!mounted) return;
      setState(() {
        _payRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'فشل تحميل سجل الرواتب: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;

    // Calculate dynamic header metrics from real pay records
    final totalPaid = _payRecords.fold<double>(
      0.0,
      (sum, r) => sum + (((r['netPayout'] ?? r['net']) as num?)?.toDouble() ?? 0.0),
    );
    final approvedCount = _payRecords.length;
    final lastRec = _payRecords.isNotEmpty ? _payRecords.first : null;
    final lastNet = lastRec != null
        ? (((lastRec['netPayout'] ?? lastRec['net']) as num?)?.toDouble() ?? 0.0)
        : 0.0;
    final lastMonth = lastRec != null
        ? (lastRec['monthLabel'] ?? lastRec['month'] ?? '').toString()
        : '-';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('سجل الرواتب والدفعات')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Employee Quick Identity
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
                    decoration: const BoxDecoration(
                      color: AppColors.primaryFixed,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      employee.name.length >= 2
                          ? employee.name.substring(0, 2)
                          : 'مو',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onPrimaryFixed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.paddingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.name,
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
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
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    ),
                    child: Text(
                      '#${employee.code}',
                      style: AppTypography.labelSm.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Bento Metrics Strip
            Row(
              children: [
                Expanded(
                  child: Container(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'إجمالي المنصرف 2024',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${totalPaid.toStringAsFixed(0)} ج.م',
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$approvedCount مسيرات معتمدة',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.secondary,
                            fontSize: 10,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'آخر دفعة معتمدة',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.receipt_long,
                              size: 18,
                              color: AppColors.tertiary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          lastRec != null ? '${lastNet.toStringAsFixed(0)} ج.م' : '-',
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lastRec != null ? 'عن شهر $lastMonth' : 'لا توجد دفعات',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.secondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.paddingLg),

            // Pay History List
            Text(
              'سجل المسيرات الشهرية المعتمدة',
              style: AppTypography.headlineSm.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimens.paddingSm),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        _errorMessage!,
                        style: AppTypography.bodyMd.copyWith(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _loadPayHistory,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_payRecords.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppDimens.paddingLg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                ),
                child: Center(
                  child: Text(
                    'لا توجد مسيرات رواتب مسجلة لهذا الموظف',
                    style: AppTypography.bodyMd.copyWith(color: AppColors.secondary),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _payRecords.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final rec = _payRecords[index];
                  final monthText = (rec['monthLabel'] ?? rec['month'] ?? '').toString();
                  final dateText = (rec['dateLabel'] ?? rec['date'] ?? '').toString();
                  final statusText = (rec['status'] ?? 'مسدد').toString();
                  final refText = (rec['referenceNo'] ?? rec['reference'] ?? '').toString();
                  final netVal = (((rec['netPayout'] ?? rec['net'] ?? 0) as num?)?.toDouble() ?? 0.0).toStringAsFixed(0);
                  final baseVal = (((rec['baseAmount'] ?? rec['base'] ?? 0) as num?)?.toDouble() ?? 0.0).toStringAsFixed(0);
                  final allowanceVal = (((rec['allowances'] ?? rec['allowance'] ?? 0) as num?)?.toDouble() ?? 0.0).toStringAsFixed(0);
                  final deductionNum = (((rec['deductions'] ?? rec['deduction'] ?? 0) as num?)?.toDouble() ?? 0.0);
                  final deductionVal = deductionNum.toStringAsFixed(0);

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
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      monthText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.labelMd.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 130,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEAF5EA),
                                        borderRadius: BorderRadius.circular(
                                          AppDimens.radiusFull,
                                        ),
                                      ),
                                      child: Text(
                                        statusText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.labelSm.copyWith(
                                          color: const Color(0xFF2E8B2E),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppDimens.paddingSm),
                            Text(
                              '$netVal ج.م',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.headlineSm.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusLg,
                            ),
                          ),
                          child: Wrap(
                            spacing: AppDimens.paddingSm,
                            runSpacing: AppDimens.paddingXs,
                            children: [
                              Text(
                                'الأساسي: $baseVal ج.م',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                'البدلات: +$allowanceVal ج.م',
                                style: AppTypography.labelSm.copyWith(
                                  color: const Color(0xFF2E8B2E),
                                  fontSize: 11,
                                ),
                              ),
                              if (deductionNum > 0)
                                Text(
                                  'الخصومات: -$deductionVal ج.م',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.error,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                refText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSm.copyWith(
                                  fontFamily: 'monospace',
                                  color: AppColors.secondary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            Text(
                              dateText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
