import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/routing/navigation_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';

class AttendanceListScreen extends StatefulWidget {
  const AttendanceListScreen({super.key});

  @override
  State<AttendanceListScreen> createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends State<AttendanceListScreen> {
  String _selectedFilter = 'all';
  List<AttendanceRecord> _records = [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final dateStr = _selectedDate != null
          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
          : null;
      final records = await sl<AttendanceRepository>().getAttendanceRecords(date: dateStr);
      if (!mounted) return;
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'فشل تحميل سجلات الحضور: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadRecords();
    }
  }

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

  Future<void> _onSyncDevices() async {
    try {
      final success = await sl<AttendanceRepository>().syncBiometricDevices();
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تمت مزامنة بيانات البصمة مع أجهزة الدخول البيومترية بنجاح.',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadRecords();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشلت مزامنة أجهزة الدخول البيومترية'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في مزامنة الأجهزة: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Symbols.arrow_forward, color: AppColors.onSurface),
            onPressed: () => context.safePop(fallback: '/home'),
          ),
        title: Text(
          'سجلات الحضور والتأخير (ATT-01)',
          style: AppTypography.headlineSm.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _selectedDate != null ? Symbols.event_available : Symbols.calendar_today,
              color: AppColors.primary,
            ),
            tooltip: 'تحديد التاريخ (ATT-01)',
            onPressed: _selectDate,
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Symbols.close, color: AppColors.secondary, size: 20),
              tooltip: 'إعادة ضبط للتاريخ الحالي',
              onPressed: () {
                setState(() {
                  _selectedDate = null;
                });
                _loadRecords();
              },
            ),
          IconButton(
            icon: const Icon(Symbols.sync, color: AppColors.primary),
            tooltip: 'مزامنة أجهزة البصمة',
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
              child: Builder(
                builder: (context) {
                  final presentCount = _records.where((r) => r.status == AttendanceStatus.present).length;
                  final lateCount = _records.where((r) => r.status == AttendanceStatus.late).length;
                  final absentCount = _records.where((r) => r.status == AttendanceStatus.absent).length;
                  return Row(
                    children: [
                      _buildFilterPill('all', 'الكل (${_records.length})'),
                      const SizedBox(width: AppSpacing.sm),
                      _buildFilterPill('present', 'منضبط ($presentCount)'),
                      const SizedBox(width: AppSpacing.sm),
                      _buildFilterPill('late', 'متأخر ($lateCount)'),
                      const SizedBox(width: AppSpacing.sm),
                      _buildFilterPill('absent', 'غياب ($absentCount)'),
                    ],
                  );
                },
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
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _errorMessage != null
                      ? Center(
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
                                onPressed: _loadRecords,
                                icon: const Icon(Symbols.refresh),
                                label: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        )
                      : _filteredRecords.isEmpty
                          ? Center(
                              child: Text(
                                'لا توجد سجلات حضور مسجلة',
                                style: AppTypography.bodyMd.copyWith(color: AppColors.secondary),
                              ),
                            )
                          : ListView.separated(
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
        onTap: () async {
          final refreshed = await context.push<bool>('/attendance/details', extra: record);
          if (refreshed == true && mounted) {
            _loadRecords();
          }
        },
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
