import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/routing/navigation_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/repositories/http_overtime_repository.dart';
import '../../domain/entities/overtime_record.dart';
import '../../domain/repositories/overtime_repository.dart';

class OvertimeListScreen extends StatefulWidget {
  const OvertimeListScreen({super.key, this.repository});

  final OvertimeRepository? repository;

  @override
  State<OvertimeListScreen> createState() => _OvertimeListScreenState();
}

class _OvertimeListScreenState extends State<OvertimeListScreen> {
  String _selectedFilter = 'pending';
  List<OvertimeRecord> _records = [];
  bool _isLoading = true;
  String? _errorMessage;

  OvertimeRepository get _repo =>
      widget.repository ??
      (sl.isRegistered<OvertimeRepository>()
          ? sl<OvertimeRepository>()
          : HttpOvertimeRepository());

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
      final list = await _repo.getOvertimeRecords();
      if (mounted) {
        setState(() {
          _records = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll("Exception: ", "");
          _isLoading = false;
        });
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
    final pendingCount =
        _records.where((r) => r.status == OvertimeStatus.pendingReview).length;
    final approvedCount =
        _records.where((r) => r.status == OvertimeStatus.approved).length;
    final allCount = _records.length;

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
          'الساعات الإضافية (OT-01)',
          style: AppTypography.headlineSm.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.verified_user, color: AppColors.primary),
            tooltip: 'اعتماد الساعات الإضافية (OT-04)',
            onPressed: () async {
              final res = await context.push('/overtime/approve');
              if (res != null) _loadRecords();
            },
          ),
          IconButton(
            icon: const Icon(Symbols.add, color: AppColors.primary),
            tooltip: 'إضافة ساعات إضافية (OT-02)',
            onPressed: () async {
              final res = await context.push('/overtime/create');
              if (res != null) _loadRecords();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Symbols.add),
        label: const Text('إضافة ساعات (OT-02)'),
        onPressed: () async {
          final res = await context.push('/overtime/create');
          if (res != null) _loadRecords();
        },
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
                  _buildFilterPill('pending', 'بانتظار المراجعة ($pendingCount)'),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterPill('approved', 'معتمد ($approvedCount)'),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterPill('all', 'الكل ($allCount)'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Overtime List / Loading / Error
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppColors.error),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadRecords,
                                child: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        )
                      : _filteredRecords.isEmpty
                          ? RefreshIndicator(
                              onRefresh: _loadRecords,
                              child: ListView(
                                children: const [
                                  SizedBox(height: 80),
                                  Center(
                                    child: Text(
                                      'لا توجد سجلات ساعات إضافية في هذا القسم',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadRecords,
                              child: ListView.separated(
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

  Widget _buildOvertimeCard(OvertimeRecord record) {
    final isPending = record.status == OvertimeStatus.pendingReview;

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: AppRadius.xlAll,
      elevation: 0.5,
      child: InkWell(
        onTap: () async {
          final res = await context.push('/overtime/review', extra: record);
          if (res != null) _loadRecords();
        },
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
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Symbols.calendar_today,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            record.date,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Symbols.timelapse,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${record.hours.toStringAsFixed(0)} ساعات (+${record.overtimePay.toStringAsFixed(0)} ج.م)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
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
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            record.timeRange,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.secondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 145),
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
                        Flexible(
                          child: Text(
                            record.trigger.titleArabic,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSm.copyWith(fontSize: 10),
                          ),
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
