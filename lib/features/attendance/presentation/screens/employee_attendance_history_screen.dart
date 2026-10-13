import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

class EmployeeAttendanceHistoryScreen extends StatefulWidget {
  final String? employeeName;

  const EmployeeAttendanceHistoryScreen({super.key, this.employeeName});

  @override
  State<EmployeeAttendanceHistoryScreen> createState() => _EmployeeAttendanceHistoryScreenState();
}

class _EmployeeAttendanceHistoryScreenState extends State<EmployeeAttendanceHistoryScreen> {
  final String _currentMonth = 'أبريل 2024';

  final List<Map<String, dynamic>> _mockDays = [
    {
      'date': 'الثلاثاء، 16 أبريل',
      'checkIn': '09:42 ص',
      'checkOut': '05:05 م',
      'delay': 'تأخير 42 دقيقة',
      'deduction': '50 ج.م',
      'isLate': true,
      'isOff': false,
    },
    {
      'date': 'الإثنين، 15 أبريل',
      'checkIn': '08:55 ص',
      'checkOut': '05:10 م',
      'delay': 'حضور منضبط',
      'deduction': '0 ج.م',
      'isLate': false,
      'isOff': false,
    },
    {
      'date': 'الأحد، 14 أبريل',
      'checkIn': '08:58 ص',
      'checkOut': '05:02 م',
      'delay': 'حضور منضبط',
      'deduction': '0 ج.م',
      'isLate': false,
      'isOff': false,
    },
    {
      'date': 'السبت، 13 أبريل',
      'checkIn': '09:10 ص',
      'checkOut': '05:00 م',
      'delay': 'تأخير 10 د (ضمن السماح)',
      'deduction': '0 ج.م',
      'isLate': false,
      'isOff': false,
    },
    {
      'date': 'الجمعة، 12 أبريل',
      'checkIn': '-',
      'checkOut': '-',
      'delay': 'راحة أسبوعية',
      'deduction': '0 ج.م',
      'isLate': false,
      'isOff': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final name = widget.employeeName ?? 'مصطفى خالد عثمان';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('سجل الحضور التاريخي'),
      ),
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
                    child: const Icon(Icons.badge_outlined, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppDimens.paddingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'طاهي خط ساخن • الفرع الرئيسي وسط البلد',
                          style: AppTypography.bodySm.copyWith(color: AppColors.secondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    ),
                    child: Text(
                      'دوام كامل',
                      style: AppTypography.labelSm.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
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
                    onPressed: () {},
                  ),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _currentMonth,
                        style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(01 - 30 أبريل)',
                        style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // 4-Grid Metrics
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile('الورديات المكتملة', '22', '/ 24 وردية', AppColors.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile('نسبة الانضباط', '91.6%', 'التزام المواعيد', const Color(0xFF2E8B2E)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile('دقائق التأخير', '52 د', 'إجمالي الشهر', AppColors.error),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile('صافي الخصومات', '100 ج.م', '2 خصم مطبق', AppColors.onSurface),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.paddingLg),

            // Daily records
            Text(
              'سجل البصمات اليومي',
              style: AppTypography.headlineSm.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppDimens.paddingSm),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _mockDays.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final day = _mockDays[index];
                final isLate = day['isLate'] as bool;
                final isOff = day['isOff'] as bool;

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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            day['date'] as String,
                            style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          if (!isOff)
                            Text(
                              '${day['checkIn']} - ${day['checkOut']}',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.secondary,
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            )
                          else
                            Text(
                              'عطلة مجدولة',
                              style: AppTypography.bodySm.copyWith(color: AppColors.secondary, fontSize: 11),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isLate
                                  ? AppColors.errorContainer
                                  : isOff
                                      ? AppColors.surfaceContainerHigh
                                      : const Color(0xFFEAF5EA),
                              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                            ),
                            child: Text(
                              day['delay'] as String,
                              style: AppTypography.labelSm.copyWith(
                                color: isLate
                                    ? AppColors.onErrorContainer
                                    : isOff
                                        ? AppColors.secondary
                                        : const Color(0xFF2E8B2E),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          if (isLate) ...[
                            const SizedBox(height: 2),
                            Text(
                              'خصم: ${day['deduction']}',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
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
          Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 11)),
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
                  style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 10),
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
