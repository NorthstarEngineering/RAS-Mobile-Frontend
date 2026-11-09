import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/di/service_locator.dart';
import '../../data/repositories/api_overtime_repository.dart';
import '../../domain/entities/overtime_record.dart';

class OvertimeListScreen extends StatefulWidget {
  const OvertimeListScreen({super.key});

  @override
  State<OvertimeListScreen> createState() => _OvertimeListScreenState();
}

class _OvertimeListScreenState extends State<OvertimeListScreen> {
  String _selectedFilter = 'pending';

  List<OvertimeRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final records = await sl<ApiOvertimeRepository>().list();
      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل الساعات الإضافية: $error')),
        );
      }
    }
  }

  List<OvertimeRecord> get _filteredRecords {
    if (_selectedFilter == 'pending') {
      return _records
          .where((r) => r.status == OvertimeStatus.pendingReview)
          .toList();
    }
    if (_selectedFilter == 'approved') {
      return _records
          .where((r) => r.status == OvertimeStatus.approved)
          .toList();
    }
    return _records;
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
          'الساعات الإضافية (OT-01)',
          style: AppTypography.headlineSm.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.add, color: AppColors.primary),
            tooltip: 'إضافة ساعات إضافية (OT-02)',
            onPressed: () => context.push('/overtime/create').then((_) {
              if (mounted) _loadRecords();
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Symbols.add),
        label: const Text('إضافة ساعات (OT-02)'),
        onPressed: () => context.push('/overtime/create').then((_) {
          if (mounted) _loadRecords();
        }),
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
                  _buildFilterPill(
                    'pending',
                    'بانتظار المراجعة (${_records.where((r) => r.status == OvertimeStatus.pendingReview).length})',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterPill(
                    'approved',
                    'معتمد (${_records.where((r) => r.status == OvertimeStatus.approved).length})',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterPill('all', 'الكل (${_records.length})'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Overtime List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.margin,
                        0,
                        AppSpacing.margin,
                        AppSpacing.xl,
                      ),
                      itemCount: _filteredRecords.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final record = _filteredRecords[index];
                        return _buildOvertimeCard(record);
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

  Widget _buildOvertimeCard(OvertimeRecord record) {
    final isPending = record.status == OvertimeStatus.pendingReview;

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: AppRadius.xlAll,
      elevation: 0.5,
      child: InkWell(
        onTap: () => context.push('/overtime/review', extra: record).then((_) {
          if (mounted) _loadRecords();
        }),
        borderRadius: AppRadius.xlAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Meta Line
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryFixed,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      record.initials,
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.onPrimaryFixedVariant,
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
                            Text(
                              record.employeeName,
                              style: AppTypography.labelMd.copyWith(
                                fontWeight: FontWeight.w700,
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
                      color: isPending
                          ? AppColors.primaryFixed
                          : const Color(0xFFE8F5E9),
                      borderRadius: AppRadius.fullAll,
                    ),
                    child: Text(
                      record.status.titleArabic,
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isPending
                            ? AppColors.onPrimaryFixedVariant
                            : const Color(0xFF2E8B2E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.surfaceContainer),
              const SizedBox(height: AppSpacing.sm),

              // Breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Symbols.calendar_today,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        record.date,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Symbols.timelapse,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${record.hours.toStringAsFixed(0)} ساعات (+${record.overtimePay.toStringAsFixed(0)} ج.م)',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Symbols.schedule,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        record.timeRange,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.secondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Symbols.fingerprint,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          record.trigger.titleArabic,
                          style: AppTypography.labelSm.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Action Prompt Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      record.reason,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.secondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'مراجعة واعتماد (OT-03)',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Icon(
                        Symbols.chevron_left,
                        size: 16,
                        color: AppColors.primary,
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
