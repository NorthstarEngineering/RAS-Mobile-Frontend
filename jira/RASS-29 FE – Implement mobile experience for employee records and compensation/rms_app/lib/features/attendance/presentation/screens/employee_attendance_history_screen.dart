import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../../../core/di/service_locator.dart';

class EmployeeAttendanceHistoryScreen extends StatefulWidget {
  final String? employeeName;
  final String? employeeId;

  const EmployeeAttendanceHistoryScreen({
    super.key,
    this.employeeName,
    this.employeeId,
  });

  @override
  State<EmployeeAttendanceHistoryScreen> createState() =>
      _EmployeeAttendanceHistoryScreenState();
}

class _EmployeeAttendanceHistoryScreenState
    extends State<EmployeeAttendanceHistoryScreen> {
  static const _arabicMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  late DateTime _currentMonth;
  List<AttendanceRecord> _records = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _loadHistory();
  }

  String get _currentMonthLabel =>
      '${_arabicMonths[_currentMonth.month - 1]} ${_currentMonth.year}';

  String get _currentMonthRange {
    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    return '(01 - $daysInMonth ${_arabicMonths[_currentMonth.month - 1]})';
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final lookupKey = widget.employeeId ?? widget.employeeName ?? '1';
      final records = await sl<AttendanceRepository>().getEmployeeAttendanceHistory(
        lookupKey,
        month: _currentMonth.month,
        year: _currentMonth.year,
      );
      if (!mounted) return;
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'فشل تحميل سجل الحضور: $e';
        _isLoading = false;
      });
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + offset,
      );
    });
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.employeeName ?? 'موظف';

    final totalShifts = _records.length;
    final presentCount = _records.where((r) => r.status == AttendanceStatus.present).length;
    final lateCount = _records.where((r) => r.status == AttendanceStatus.late).length;
    final completedShifts = presentCount + lateCount;
    final disciplineRate = totalShifts > 0
        ? (presentCount / totalShifts * 100.0).toStringAsFixed(1)
        : '100.0';
    final totalLateMinutes = _records.fold<int>(0, (sum, r) => sum + r.delayMinutes);
    final totalDeductions = _records.fold<double>(0.0, (sum, r) => sum + r.deductionAmount);
    final deductionCount = _records.where((r) => r.deductionAmount > 0).length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('سجل الحضور التاريخي')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Employee Context Bar
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
                    child: const Icon(
                      Icons.badge_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppDimens.paddingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'طاقم التشغيل • الفرع الرئيسي وسط البلد (#01)',
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
                      'سجل شهري',
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Month Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'الشهر السابق',
                    onPressed: () => _changeMonth(-1),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentMonthLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _currentMonthRange,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'الشهر التالي',
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),

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
                        onPressed: _loadHistory,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // 4-Grid Metrics
              if (_records.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        'الورديات المكتملة',
                        '$completedShifts',
                        '/ $totalShifts وردية',
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        'نسبة الانضباط',
                        '$disciplineRate%',
                        'التزام المواعيد',
                        const Color(0xFF2E8B2E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        'دقائق التأخير',
                        '$totalLateMinutes د',
                        'إجمالي الشهر',
                        AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        'صافي الخصومات',
                        '${totalDeductions.toStringAsFixed(0)} ج.م',
                        '$deductionCount خصم مطبق',
                        AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(AppDimens.paddingLg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                  ),
                  child: Text(
                    'لا توجد ملخصات حضور مسجلة لهذا الشهر.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              const SizedBox(height: AppDimens.paddingLg),

              // Daily records
              Text(
                'سجل البصمات اليومي',
                style: AppTypography.headlineSm.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimens.paddingSm),

              if (_records.isNotEmpty)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final day = _records[index];
                    final isLate = day.status == AttendanceStatus.late;
                    final isAbsent = day.status == AttendanceStatus.absent;
                    final dateLabel = day.date.isNotEmpty ? day.date : 'سجل البصمة';
                    final delayText = isLate
                        ? 'تأخير ${day.delayMinutes} دقيقة'
                        : (isAbsent ? 'غياب غير مسجل' : 'حضور منضبط');

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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelMd.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (!isAbsent)
                                  Text(
                                    '${day.checkInTime} - ${day.checkOutTime ?? 'جارية الآن'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodySm.copyWith(
                                      color: AppColors.secondary,
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                    ),
                                  )
                                else
                                  Text(
                                    'لم يتم تسجيل البصمة',
                                    style: AppTypography.bodySm.copyWith(
                                      color: AppColors.secondary,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppDimens.paddingSm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isLate
                                        ? AppColors.errorContainer
                                        : isAbsent
                                            ? AppColors.surfaceContainerHigh
                                            : const Color(0xFFEAF5EA),
                                    borderRadius: BorderRadius.circular(
                                      AppDimens.radiusFull,
                                    ),
                                  ),
                                  child: Text(
                                    delayText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.labelSm.copyWith(
                                      color: isLate
                                          ? AppColors.onErrorContainer
                                          : isAbsent
                                              ? AppColors.secondary
                                              : const Color(0xFF2E8B2E),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                if (isLate || day.deductionAmount > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'خصم: ${day.deductionAmount.toStringAsFixed(0)} ج.م',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.all(AppDimens.paddingLg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                  ),
                  child: Text(
                    'لا توجد سجلات حضور مسجلة لهذا الشهر.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, String sub, Color color) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.secondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTypography.headlineSm.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  sub,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.secondary,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
