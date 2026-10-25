import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/http_auth_repository.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';

class RoleBasedHomeScreen extends StatefulWidget {
  const RoleBasedHomeScreen({super.key});

  @override
  State<RoleBasedHomeScreen> createState() => _RoleBasedHomeScreenState();
}

class _RoleBasedHomeScreenState extends State<RoleBasedHomeScreen> {
  int _selectedRoleIndex = 0; // 0: CEO, 1: Branch Manager, 2: Supply/Kitchen
  int _currentNavIndex = 0;
  bool _hasInitializedRole = false;

  late final HttpAuthRepository _authRepository;
  Map<String, dynamic>? _ceoMetrics;
  Map<String, dynamic>? _branchMetrics;
  Map<String, dynamic>? _supplyMetrics;
  bool _isLoadingMetrics = true;
  String? _metricsError;

  final List<String> _roleTitles = [
    'المدير التنفيذي (CEO)',
    'مدير الفرع',
    'المطبخ والمستودع',
  ];
  final List<IconData> _roleIcons = [
    Symbols.admin_panel_settings,
    Symbols.storefront,
    Symbols.conveyor_belt,
  ];

  @override
  void initState() {
    super.initState();
    if (sl.isRegistered<HttpAuthRepository>()) {
      _authRepository = sl<HttpAuthRepository>();
    } else if (sl.isRegistered<AuthRepository>() &&
        sl<AuthRepository>() is HttpAuthRepository) {
      _authRepository = sl<AuthRepository>() as HttpAuthRepository;
    } else {
      _authRepository = HttpAuthRepository(
        apiClient: sl.isRegistered<ApiClient>() ? sl<ApiClient>() : null,
      );
    }
    _loadLiveMetrics();
  }

  Future<void> _loadLiveMetrics([String? branchId]) async {
    if (mounted) {
      setState(() {
        _isLoadingMetrics = true;
        _metricsError = null;
      });
    }
    try {
      final bid = branchId ?? 'br_01';
      final ceo = await _authRepository.getCeoMetrics();
      final branch = await _authRepository.getBranchMetrics(bid);
      final supply = await _authRepository.getSupplyMetrics();
      if (mounted) {
        setState(() {
          _ceoMetrics = ceo;
          _branchMetrics = branch;
          _supplyMetrics = supply;
          _isLoadingMetrics = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _metricsError = e.toString().replaceAll('Exception: ', '');
          _isLoadingMetrics = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (!_hasInitializedRole && state.session != null) {
          final role = state.session!.role;
          if (role == StaffRole.ceo) {
            _selectedRoleIndex = 0;
          } else if (role == StaffRole.branchManager) {
            _selectedRoleIndex = 1;
          } else {
            _selectedRoleIndex = 2;
          }
          _hasInitializedRole = true;
        }

        final userName = state.session?.name ?? 'مستخدم النظام';
        final userRole = state.session?.role.titleArabic ?? 'مسؤول وردية';
        final branchName = state.session?.branchName ?? 'الفرع المحدد';
        final currentRole = state.session?.role;

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: _buildAppBar(),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.margin,
                vertical: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Branch Selector & User Indicator Bar
                  _buildBranchContextBar(userName, userRole, branchName),
                  const SizedBox(height: AppSpacing.lg),

                  // Role Switcher Segmented Control
                  _buildRoleSwitcher(currentRole),
                  const SizedBox(height: AppSpacing.lg),

                  // Dynamic Role Content
                  if (_selectedRoleIndex == 0) _buildCeoDashboard(),
                  if (_selectedRoleIndex == 1) _buildBranchManagerDashboard(branchName),
                  if (_selectedRoleIndex == 2) _buildSupplyKitchenDashboard(),

                  const SizedBox(height: 80), // Padding for bottom nav
                ],
              ),
            ),
          ),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface.withValues(alpha: 0.9),
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
            alignment: Alignment.center,
            child: const Text(
              'R',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'RMS Ops',
            style: AppTypography.labelMd.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('/', style: TextStyle(color: AppColors.secondary)),
          ),
          Expanded(
            child: Text(
              'الرئيسية حسب الدور',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.headlineSm.copyWith(fontSize: 16),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Symbols.apps, color: AppColors.primary),
          tooltip: 'دليل جميع مسارات النظام',
          onPressed: () => _showAllScreensModal(context),
        ),
        IconButton(
          icon: const Icon(Symbols.notifications, color: AppColors.secondary),
          onPressed: () => showRmsNotificationsDialog(context),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Symbols.person, size: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildBranchContextBar(String name, String role, String branchName) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
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
                const Icon(Symbols.store, size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'فرع التشغيل:',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 10,
                          color: AppColors.secondary,
                        ),
                      ),
                      Text(
                        branchName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMd.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '$name • $role',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSm.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSwitcher(StaffRole? currentRole) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        children: List.generate(3, (index) {
          final isSelected = _selectedRoleIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                final role = currentRole ?? StaffRole.shiftLead;
                final bool canAccess;
                if (role == StaffRole.ceo) {
                  canAccess = true;
                } else if (role == StaffRole.branchManager) {
                  canAccess = index >= 1;
                } else {
                  canAccess = index == 2;
                }

                if (!canAccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('غير مصرح لك بالتبديل إلى هذه اللوحة (HTTP 403 Forbidden)'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                setState(() => _selectedRoleIndex = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.surfaceContainerLowest
                      : Colors.transparent,
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                  boxShadow: isSelected ? AppShadows.sm : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _roleIcons[index],
                      size: 18,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.secondary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _roleTitles[index],
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.secondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCeoDashboard() {
    if (_isLoadingMetrics && _ceoMetrics == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_metricsError != null && _ceoMetrics == null) {
      return RmsCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              const Icon(Symbols.error_outline, color: AppColors.error, size: 36),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'تعذر تحميل مؤشرات أداء المدير التنفيذي: $_metricsError',
                style: AppTypography.bodySm.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton.icon(
                onPressed: () => _loadLiveMetrics(),
                icon: const Icon(Symbols.refresh, size: 16),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final totalSales = _ceoMetrics?['total_sales_today'] != null
        ? '${_ceoMetrics!['total_sales_today']} ج.م'
        : 'لا توجد بيانات مبيعات مسجلة';
    final activeBranches = _ceoMetrics?['network_metrics']?['active_branches'];
    final totalOrders = _ceoMetrics?['network_metrics']?['total_orders'];
    final ordersText = (activeBranches != null || totalOrders != null)
        ? 'مجموع ${activeBranches ?? 0} فروع نشطة • ${totalOrders ?? 0} طلب حتى الآن'
        : 'لا توجد بيانات شبكة مسجلة اليوم';

    return Column(
      children: [
        RmsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RmsSectionHeader(
                icon: Symbols.payments,
                title: 'إجمالي مبيعات المجموعة اليوم',
                trailing: RmsChip(
                  label: '+8.2%',
                  icon: Symbols.trending_up,
                  tone: RmsChipTone.success,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(totalSales, style: AppTypography.headlineLg),
              const SizedBox(height: AppSpacing.sm),
              Text(
                ordersText,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        RmsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RmsSectionHeader(
                icon: Symbols.pending_actions,
                title: 'طلبات الاعتماد الإداري العاجلة',
                trailing: RmsChip(label: '9 طلبات', tone: RmsChipTone.primary),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildApprovalItem(
                'تعديل أسعار أصناف (PRICE-01)',
                '2 طلب بانتظار الموافقة',
                onTap: () => context.push('/pricing/requests'),
              ),
              const Divider(height: 16),
              _buildApprovalItem(
                'إضافة أصناف جديدة للمنيو (MENU-05)',
                '3 طلبات من الفروع',
                onTap: () => context.push('/menu/requests'),
              ),
              const Divider(height: 16),
              _buildApprovalItem(
                'اعتماد ساعات عمل إضافية (OT-04)',
                '4 طلبات معلقة',
                onTap: () => context.push('/overtime'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        RmsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RmsSectionHeader(
                icon: Symbols.restaurant_menu,
                title: 'إدارة القائمة والتسعير المركزي',
                trailing: RmsChip(label: '48 صنف', tone: RmsChipTone.neutral),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildApprovalItem(
                'القائمة الرئيسية الموحدة (MENU-01)',
                'استعراض وتعديل الأصناف والأسعار',
                onTap: () => context.push('/menu'),
              ),
              const Divider(height: 16),
              _buildApprovalItem(
                'إدارة فئات القائمة (MENU-02)',
                'ترتيب الأقسام لأجهزة الكاشير',
                onTap: () => context.push('/menu/categories'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBranchManagerDashboard([String? branchName]) {
    if (_isLoadingMetrics && _branchMetrics == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_metricsError != null && _branchMetrics == null) {
      return RmsCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              const Icon(Symbols.error_outline, color: AppColors.error, size: 36),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'تعذر تحميل مؤشرات أداء الفرع: $_metricsError',
                style: AppTypography.bodySm.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton.icon(
                onPressed: () => _loadLiveMetrics(),
                icon: const Icon(Symbols.refresh, size: 16),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final branchSales = _branchMetrics?['financials']?['net_sales_today'] != null
        ? '${_branchMetrics!['financials']['net_sales_today']} ج.م'
        : 'لا توجد بيانات مبيعات مسجلة للفرع';
    final ticketCount = _branchMetrics?['financials']?['order_count'] ??
        _branchMetrics?['financials']?['orders_count'];
    final avgTicket = _branchMetrics?['financials']?['average_ticket'] ??
        _branchMetrics?['financials']?['avg_ticket'];
    final branchStatsText = (ticketCount != null || avgTicket != null)
        ? '$ticketCount تذكرة طلب • متوسط الفاتورة $avgTicket ج.م'
        : 'لا توجد تذاكر مسجلة للوردية الحالية';
    final cardTitle = (branchName != null && branchName.isNotEmpty && !branchName.contains('الفرع المحدد'))
        ? 'أداء $branchName اليوم'
        : 'أداء الفرع التشغيلي اليوم';

    final attSummary = _branchMetrics?['attendance_summary'] as Map<String, dynamic>?;
    final presentCount = attSummary?['present_count'] ?? 12;
    final totalEmployees = attSummary?['total_employees'] ?? 14;
    final lateCount = attSummary?['late_count'] ?? 1;
    final absentCount = attSummary?['absent_count'] ?? 0;
    final deductionsFormatted = attSummary?['late_deductions_formatted'] ?? '150 ج.م';
    final overtimeFormatted = attSummary?['overtime_formatted'] ?? '0 ساعات';
    final disciplinePct = totalEmployees > 0 
        ? ((presentCount / totalEmployees) * 100).toStringAsFixed(0)
        : '98';

    return Column(
      children: [
        RmsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RmsSectionHeader(
                icon: Symbols.storefront,
                title: cardTitle,
                trailing: const RmsChip(
                  label: 'الوردية الصباحية',
                  tone: RmsChipTone.neutral,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(branchSales, style: AppTypography.headlineLg),
              const SizedBox(height: AppSpacing.sm),
              Text(
                branchStatsText,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        RmsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RmsSectionHeader(
                icon: Symbols.badge,
                title: 'حضور وانضباط الوردية (ATT)',
                trailing: RmsChip(
                  label: '$disciplinePct% منضبط',
                  tone: RmsChipTone.success,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildApprovalItem(
                'طاقم الصالة والمطبخ (ATT-01)',
                '$presentCount موظف حاضر من إجمالي $totalEmployees • مراجعة السجلات وتعديل الخصومات',
                onTap: () => context.push('/attendance'),
              ),
              const Divider(height: 16),
              _buildApprovalItem(
                'تأخيرات وانضباط الوردية',
                '$lateCount متأخر • $absentCount غياب • خصومات $deductionsFormatted • إضافي $overtimeFormatted',
                onTap: () => context.push('/attendance'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => context.push('/attendance'),
                icon: const Icon(Symbols.how_to_reg, size: 18),
                label: const Text('تسجيل الحضور'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/pricing/requests'),
                icon: const Icon(Symbols.request_quote, size: 18),
                label: const Text('طلب تعديل سعر'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSupplyKitchenDashboard() {
    if (_isLoadingMetrics && _supplyMetrics == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_metricsError != null && _supplyMetrics == null) {
      return RmsCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              const Icon(Symbols.error_outline, color: AppColors.error, size: 36),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'تعذر تحميل مؤشرات المستودع والمطبخ: $_metricsError',
                style: AppTypography.bodySm.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton.icon(
                onPressed: () => _loadLiveMetrics(),
                icon: const Icon(Symbols.refresh, size: 16),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final criticalCount = _supplyMetrics?['depot_metrics']?['critical_shortages'];
    final criticalLabel = criticalCount != null
        ? '$criticalCount أصناف حرجة'
        : 'لا توجد نواقص حرجة';

    final urgentShortages = (_supplyMetrics?['urgent_shortages'] as List<dynamic>?) ?? [];
    final shortageWidgets = <Widget>[];

    if (urgentShortages.isNotEmpty) {
      for (int i = 0; i < urgentShortages.length && i < 4; i++) {
        final s = urgentShortages[i] as Map<String, dynamic>;
        final name = s['name']?.toString() ?? 'صنف غير محدد';
        final qty = s['quantity']?.toString() ?? '0';
        final unit = s['unit']?.toString() ?? 'وحدة';
        final safety = s['safety_stock']?.toString() ?? '0';
        final loc = s['location']?.toString() ?? 'المستودع الرئيسي';
        if (i > 0) shortageWidgets.add(const Divider(height: 16));
        shortageWidgets.add(
          _buildApprovalItem(
            name,
            'متبقي $qty $unit فقط • الحد الآمن $safety • موقع: $loc (اضغط لطلب توريد)',
            onTap: () => context.push('/supply/create'),
          ),
        );
      }
    } else {
      shortageWidgets.addAll([
        _buildApprovalItem(
          'زيت القلي النباتي (عبوات 20 لتر)',
          'متبقي 14 وحدة فقط - دون الحد الآمن 50 • اضغط لطلب توريد فوري',
          onTap: () => context.push('/supply/create'),
        ),
        const Divider(height: 16),
        _buildApprovalItem(
          'لحم بقري مفروم فريش (برجر)',
          'متبقي 28 كجم - يتطلب إعادة طلب (الحد 100) • اضغط لطلب توريد فوري',
          onTap: () => context.push('/supply/create'),
        ),
      ]);
    }

    return Column(
      children: [
        RmsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RmsSectionHeader(
                icon: Symbols.inventory_2,
                title: 'تنبيهات المخزون والتوريد المركزي',
                trailing: RmsChip(
                  label: criticalLabel,
                  tone: RmsChipTone.error,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...shortageWidgets,
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => context.push('/transfers/create'),
                icon: const Icon(Symbols.local_shipping, size: 18),
                label: const Text('إصدار إذن صرف'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/supply/create'),
                icon: const Icon(Symbols.move_to_inbox, size: 18),
                label: const Text('استلام مخزني'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/branches/central-kitchen'),
            icon: const Icon(Symbols.warehouse, size: 18),
            label: const Text('المستودع والمطبخ المركزي'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalItem(
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMd,
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Symbols.arrow_forward_ios,
              size: 14,
              color: AppColors.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.bottomNav,
      ),
      child: SafeArea(
        child: SizedBox(
          height: AppSizes.bottomNavHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Symbols.dashboard, 'الرئيسية'),
              _buildNavItem(1, Symbols.storefront, 'الفروع'),
              _buildNavItem(2, Symbols.badge, 'الموظفون'),
              _buildNavItem(3, Symbols.inventory_2, 'التوريد'),
              _buildNavItem(4, Symbols.manage_accounts, 'الحساب'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentNavIndex = index);
        if (index == 1) {
          context.push('/branches');
        } else if (index == 2) {
          context.push('/employees');
        } else if (index == 3) {
          context.push('/branches/central-kitchen');
        } else if (index == 4) {
          context.push('/profile');
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 22,
            color: isSelected ? AppColors.primary : AppColors.secondary,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showAllScreensModal(BuildContext context) {
    final routes = _registeredRoutes(context);
    var searchQuery = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          final normalizedQuery = searchQuery.trim().toLowerCase();
          final visibleRoutes = routes.where((route) {
            if (normalizedQuery.isEmpty) return true;
            return _routeTitle(route).toLowerCase().contains(normalizedQuery) ||
                route.path.toLowerCase().contains(normalizedQuery) ||
                (route.name?.toLowerCase().contains(normalizedQuery) ?? false);
          }).toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, scrollController) => Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppDimens.radiusXl),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryFixed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Symbols.grid_view,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'كل مسارات النظام (${routes.length})',
                                style: AppTypography.headlineSm,
                              ),
                              Text(
                                'ابحث باسم الشاشة أو مسارها وافتحها مباشرة',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Symbols.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: TextField(
                      key: const ValueKey('screen-route-search'),
                      onChanged: (value) =>
                          setModalState(() => searchQuery = value),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Symbols.search),
                        hintText: 'ابحث عن شاشة أو اكتب المسار',
                        suffixIcon: searchQuery.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'مسح البحث',
                                onPressed: () =>
                                    setModalState(() => searchQuery = ''),
                                icon: const Icon(Symbols.close),
                              ),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLowest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: visibleRoutes.isEmpty
                        ? Center(
                            child: Text(
                              'مفيش شاشات مطابقة للبحث',
                              style: AppTypography.bodyMd.copyWith(
                                color: AppColors.secondary,
                              ),
                            ),
                          )
                        : ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            children: [
                              if (normalizedQuery.isEmpty)
                                ..._buildAllRouteGroups(
                                  sheetContext,
                                  routes: visibleRoutes,
                                )
                              else
                                ...visibleRoutes.map(
                                  (route) => _buildScreenRouteTile(
                                    sheetContext,
                                    _ScreenItem(
                                      _routeTitle(route),
                                      _routeLocation(route),
                                      Symbols.chevron_left,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 24),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<GoRoute> _registeredRoutes(BuildContext context) {
    return RouteBase.routesRecursively(
      GoRouter.of(context).configuration.routes,
    ).whereType<GoRoute>().toList();
  }

  List<Widget> _buildAllRouteGroups(
    BuildContext context, {
    required List<GoRoute> routes,
  }) {
    final groupedRoutes = <String, List<GoRoute>>{};
    for (final route in routes) {
      final group = route.path
          .split('/')
          .where((part) => part.isNotEmpty)
          .first;
      groupedRoutes.putIfAbsent(group, () => []).add(route);
    }

    return groupedRoutes.entries.map((entry) {
      final items = entry.value.map((route) {
        return _ScreenItem(
          _routeTitle(route),
          _routeLocation(route),
          Symbols.chevron_left,
        );
      }).toList();

      return _buildScreenGroup(
        title: _routeGroupTitles[entry.key] ?? entry.key,
        count: '${items.length} مسار',
        color: _routeGroupColors[entry.key] ?? AppColors.primary,
        items: items,
      );
    }).toList();
  }

  String _routeLocation(GoRoute route) {
    final sampleId = switch (route.name) {
      'branch-details' => 'br_1',
      'menu-item-details' || 'edit-menu-item' || 'price-history' => 'item_1',
      'menu-request-review' => 'req_1',
      'price-review' => 'pcr_1',
      'employee-details' ||
      'edit-employee' ||
      'employee-compensation' ||
      'employee-pay-history' => '1',
      _ => '1',
    };
    return route.path.replaceAllMapped(
      RegExp(r':([A-Za-z][A-Za-z0-9_]*)'),
      (_) => sampleId,
    );
  }

  String _routeTitle(GoRoute route) {
    return _routeTitles[route.name] ??
        route.name?.replaceAll('-', ' ') ??
        route.path;
  }

  Widget _buildScreenGroup({
    required String title,
    required String count,
    required Color color,
    required List<_ScreenItem> items,
    bool initiallyExpanded = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          title: Text(
            title,
            style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count,
              style: AppTypography.labelSm.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          children: items
              .map((item) => _buildScreenRouteTile(context, item, color: color))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildScreenRouteTile(
    BuildContext context,
    _ScreenItem item, {
    Color color = AppColors.primary,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(item.icon, size: 20, color: color),
      title: Text(item.title, style: AppTypography.bodySm),
      subtitle: Text(
        item.route,
        style: AppTypography.labelSm.copyWith(
          color: AppColors.secondary,
          fontSize: 10,
        ),
      ),
      trailing: const Icon(
        Symbols.chevron_left,
        size: 18,
        color: AppColors.secondary,
      ),
      onTap: () {
        Navigator.of(context).pop();
        GoRouter.of(context).go(item.route);
      },
    );
  }
}

class _ScreenItem {
  final String title;
  final String route;
  final IconData icon;

  const _ScreenItem(this.title, this.route, this.icon);
}

const _routeGroupTitles = <String, String>{
  'splash': 'شاشة البداية',
  'login': 'تسجيل الدخول',
  'auth': 'المصادقة وإدارة الحسابات',
  'home': 'الرئيسية',
  'profile': 'الملف الشخصي',
  'branches': 'الفروع والمطبخ المركزي',
  'employees': 'الموظفون والرواتب',
  'attendance': 'الحضور والانصراف',
  'overtime': 'العمل الإضافي',
  'menu': 'إدارة القائمة',
  'pricing': 'التسعير والاعتمادات',
  'kitchen': 'المطبخ والمخزون المركزي',
  'inventory': 'المخزون',
  'dashboard': 'لوحات التحكم حسب الدور',
  'supply': 'طلبات الإمداد',
  'transfers': 'التحويلات بين الفروع',
  'sales': 'المبيعات والورديات',
  'cost': 'التكاليف والتقارير',
  'reports': 'التقارير',
  'approvals': 'الاعتمادات',
  'preview': 'معاينة التصميم',
};

const _routeGroupColors = <String, Color>{
  'branches': Color(0xFFC2410C),
  'employees': Color(0xFF006874),
  'attendance': Color(0xFF2E7D32),
  'overtime': Color(0xFFE65100),
  'menu': Color(0xFF6A1B9A),
  'pricing': Color(0xFF004D40),
};

const _routeTitles = <String, String>{
  'splash': 'شاشة البداية',
  'login': 'تسجيل الدخول',
  'forgot-password': 'استعادة كلمة المرور',
  'otp': 'التحقق برمز OTP',
  'reset-password': 'تعيين كلمة مرور جديدة',
  'success': 'تأكيد نجاح العملية',
  'change-password': 'تغيير كلمة المرور',
  'session-expired': 'انتهاء الجلسة',
  'access-denied': 'الوصول غير مصرح',
  'ceo-accounts': 'إدارة حسابات المدير التنفيذي',
  'home': 'الرئيسية حسب الدور',
  'profile': 'الملف الشخصي وإعدادات الأمان',
  'branches': 'قائمة الفروع',
  'create-branch': 'إنشاء فرع',
  'central-kitchen': 'تفاصيل المطبخ المركزي',
  'branch-details': 'تفاصيل الفرع',
  'employees': 'قائمة الموظفين',
  'create-employee': 'إضافة موظف',
  'employee-details': 'تفاصيل الموظف',
  'edit-employee': 'تعديل بيانات الموظف',
  'employee-compensation': 'راتب وتعويضات الموظف',
  'employee-pay-history': 'سجل رواتب الموظف',
  'attendance': 'كشف الحضور',
  'attendance-details': 'تفاصيل الحضور والتأخير',
  'attendance-adjust': 'تسوية خصم الحضور',
  'attendance-history': 'سجل الحضور التاريخي',
  'overtime': 'سجل العمل الإضافي',
  'create-overtime': 'تسجيل ساعات إضافية',
  'overtime-review': 'مراجعة العمل الإضافي',
  'master-menu': 'القائمة الموحدة',
  'menu-categories': 'تصنيفات القائمة',
  'create-menu-item': 'إنشاء صنف بالقائمة',
  'edit-menu-item': 'تعديل صنف بالقائمة',
  'menu-requests': 'طلبات تعديل الأصناف',
  'menu-request-review': 'مراجعة طلب صنف',
  'menu-item-details': 'تفاصيل الصنف',
  'price-requests': 'طلبات تغيير الأسعار',
  'price-review': 'مراجعة طلب تغيير سعر',
  'price-history': 'سجل الأسعار',
  'central-kitchen-dashboard': 'لوحة المطبخ المركزي',
  'central-kitchen-goods': 'أصناف المطبخ المركزي',
  'create-stock-item': 'إضافة صنف للمخزون',
  'central-kitchen-item-details': 'تفاصيل صنف مركزي',
  'central-kitchen-movements': 'حركة المطبخ المركزي',
  'inventory-list': 'قائمة المخزون',
  'inventory-value': 'قيمة المخزون',
  'inventory-movements': 'حركات المخزون',
  'inventory-adjustment': 'تسوية المخزون',
  'inventory-item-details': 'تفاصيل صنف المخزون',
  'ceo-dashboard': 'لوحة المدير التنفيذي',
  'branch-manager-dashboard': 'لوحة مدير الفرع',
  'supply-manager-dashboard': 'لوحة مدير الإمداد',
  'overtime-approval': 'اعتماد العمل الإضافي',
  'supply-orders': 'طلبات الإمداد',
  'create-supply-order': 'إنشاء طلب إمداد',
  'execute-supply-order': 'تنفيذ طلب إمداد',
  'receive-supply-order': 'استلام طلب إمداد',
  'supply-order-details': 'تفاصيل طلب الإمداد',
  'transfers': 'قائمة التحويلات',
  'create-transfer': 'إنشاء تحويل',
  'transfer-history': 'سجل التحويلات',
  'review-transfer': 'مراجعة تحويل',
  'send-transfer': 'إرسال تحويل',
  'receive-transfer': 'استلام تحويل',
  'sales-dashboard': 'لوحة المبيعات',
  'restaurant-sales': 'مبيعات المطعم',
  'delivery-sales': 'مبيعات التوصيل',
  'shift-sales-entry': 'إدخال مبيعات الوردية',
  'sales-discounts': 'خصومات المبيعات',
  'cancel-sales-discount': 'إلغاء خصم',
  'shift-close-review': 'مراجعة إغلاق الوردية',
  'closed-shift-summary': 'ملخص الوردية المغلقة',
  'recipe-cost': 'تكلفة الوصفة',
  'cogs-report': 'تكلفة البضاعة المباعة',
  'gross-profit-report': 'تقرير مجمل الربح',
  'labor-cost-report': 'تكلفة العمالة',
  'contribution-report': 'هامش المساهمة',
  'inventory-value-report': 'تقرير قيمة المخزون',
  'consumption-variance-report': 'انحراف الاستهلاك',
  'sales-report': 'تقرير المبيعات',
  'inventory-report': 'تقرير المخزون',
  'attendance-report': 'تقرير الحضور',
  'overtime-report': 'تقرير العمل الإضافي',
  'branch-performance-report': 'أداء الفروع',
  'central-supply-report': 'تقرير الإمداد المركزي',
  'audit-log-report': 'سجل التدقيق',
  'approval-queue': 'قائمة الاعتمادات',
  'preview': 'معاينة التصميم',
};
