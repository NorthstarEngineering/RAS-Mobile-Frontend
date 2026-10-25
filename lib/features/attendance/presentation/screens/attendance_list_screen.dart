import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/attendance_record.dart';

class AttendanceListScreen extends StatefulWidget {
  const AttendanceListScreen({super.key});

  @override
  State<AttendanceListScreen> createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends State<AttendanceListScreen> {
  String _selectedFilter = 'all';

  final List<AttendanceRecord> _records = [
    const AttendanceRecord(
      id: '1',
      employeeName: 'أحمد محمود سالم',
      employeeCode: '1084',
      role: 'مشرف صالة • محطة الخدمة 1',
      checkInTime: '08:52 ص',
      status: AttendanceStatus.present,
    ),
    const AttendanceRecord(
      id: '2',
      employeeName: 'مصطفى خالد عثمان',
      employeeCode: '1052',
      role: 'طاهي خط ساخن • المطبخ الساخن',
      checkInTime: '09:28 ص',
      status: AttendanceStatus.late,
      delayMinutes: 28,
      deductionAmount: 45.0,
    ),
    const AttendanceRecord(
      id: '3',
      employeeName: 'سارة محمود إبراهيم',
      employeeCode: '1060',
      role: 'مساعد بار ومشروبات • محطة المشروبات',
      checkInTime: '08:58 ص',
      status: AttendanceStatus.present,
    ),
    const AttendanceRecord(
      id: '4',
      employeeName: 'طارق زياد النجار',
      employeeCode: '1099',
      role: 'مساعد شيف • التجهيز والإعداد',
      checkInTime: 'لم يسجل حضور',
      status: AttendanceStatus.absent,
      deductionAmount: 180.0,
    ),
  ];

  List<AttendanceRecord> get _filteredRecords {
    if (_selectedFilter == 'present') {
      return _records
          .where((r) => r.status == AttendanceStatus.present)
          .toList();
    }
    if (_selectedFilter == 'late') {
      return _records.where((r) => r.status == AttendanceStatus.late).toList();
    }
    if (_selectedFilter == 'absent') {
      return _records
          .where((r) => r.status == AttendanceStatus.absent)
          .toList();
    }
    return _records;
  }

  void _onSyncDevices() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تمت مزامنة بيانات البصمة مع أجهزة الدخول البيومترية بنجاح.',
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          'سجلات الحضور والتأخير (ATT-01)',
          style: AppTypography.headlineSm.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.sync, color: AppColors.primary),
            onPressed: _onSyncDevices,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.margin,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  _buildFilterPill('all', 'الكل (${_records.length})'),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterPill('present', 'منضبط (2)'),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterPill('late', 'متأخر (1)'),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterPill('absent', 'غياب (1)'),
                ],
              ),
            ),

            // Live Ledger Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.margin,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'سجلات البصمة اليوم',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 124),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: AppRadius.fullAll,
                          ),
                          child: Text(
                            'الوردية الصباحية',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 11,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  TextButton.icon(
                    onPressed: _onSyncDevices,
                    icon: const Icon(Symbols.sync, size: 16),
                    label: const Text('مزامنة الأجهزة'),
                  ),
                ],
              ),
            ),

            // Attendance Records List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.margin,
                  0,
                  AppSpacing.margin,
                  AppSpacing.xl,
                ),
                itemCount: _filteredRecords.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final record = _filteredRecords[index];
                  return _buildAttendanceCard(record);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String id, String label) {
    final isSelected = _selectedFilter == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

  Widget _buildAttendanceCard(AttendanceRecord record) {
    final isLate = record.status == AttendanceStatus.late;
    final isAbsent = record.status == AttendanceStatus.absent;

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: AppRadius.xlAll,
      elevation: 0.5,
      child: InkWell(
        onTap: () => context.push('/attendance/details', extra: record),
        borderRadius: AppRadius.xlAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      record.initials,
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                record.employeeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '#${record.employeeCode}',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          record.role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.secondary,
                            fontSize: 12,
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
                      color: isLate
                          ? AppColors.warningContainer
                          : isAbsent
                          ? AppColors.errorContainer
                          : const Color(0xFFE8F5E9),
                      borderRadius: AppRadius.fullAll,
                    ),
                    child: Text(
                      record.status.titleArabic,
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isLate
                            ? AppColors.warning
                            : isAbsent
                            ? AppColors.error
                            : const Color(0xFF2E8B2E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Check-in & Deduction Strip
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
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Symbols.schedule,
                            size: 16,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'تسجيل الحضور: ${record.checkInTime}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSm.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isLate || isAbsent)
                      const SizedBox(width: AppSpacing.xs),
                    if (isLate || isAbsent)
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                record.isDeductionAdjusted
                                    ? 'تم تعديل الخصم'
                                    : 'خصم: ${record.deductionAmount.toStringAsFixed(0)} ج.م (تعديل)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
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
