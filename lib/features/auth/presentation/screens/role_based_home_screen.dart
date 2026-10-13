import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
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

  final List<String> _roleTitles = ['المدير التنفيذي (CEO)', 'مدير الفرع', 'المطبخ والمستودع'];
  final List<IconData> _roleIcons = [
    Symbols.admin_panel_settings,
    Symbols.storefront,
    Symbols.conveyor_belt,
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final userName = state.session?.name ?? 'م. ألفاريز';
        final userRole = state.session?.role.titleArabic ?? 'مسؤول وردية';

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
                  _buildBranchContextBar(userName, userRole),
                  const SizedBox(height: AppSpacing.lg),

                  // Role Switcher Segmented Control
                  _buildRoleSwitcher(),
                  const SizedBox(height: AppSpacing.lg),

                  // Dynamic Role Content
                  if (_selectedRoleIndex == 0) _buildCeoDashboard(),
                  if (_selectedRoleIndex == 1) _buildBranchManagerDashboard(),
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
          Text(
            'الرئيسية حسب الدور',
            style: AppTypography.headlineSm.copyWith(fontSize: 16),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Symbols.apps, color: AppColors.primary),
          tooltip: 'دليل شاشات النظام الـ 32',
          onPressed: () => _showAllScreensModal(context),
        ),
        IconButton(
          icon: const Icon(Symbols.notifications, color: AppColors.secondary),
          onPressed: () {},
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

  Widget _buildBranchContextBar(String name, String role) {
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
          Row(
            children: [
              const Icon(Symbols.store, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Column(
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
                    'الفرع الرئيسي - وسط البلد (#01)',
                    style: AppTypography.labelMd.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
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
                Text(
                  '$name • $role',
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSwitcher() {
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
              onTap: () => setState(() => _selectedRoleIndex = index),
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
                      color: isSelected ? AppColors.primary : AppColors.secondary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _roleTitles[index],
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.primary : AppColors.secondary,
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
              Text('184,500 ج.م', style: AppTypography.headlineLg),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'مجموع 8 فروع نشطة • 1,248 طلب حتى الآن',
                style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
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

  Widget _buildBranchManagerDashboard() {
    return Column(
      children: [
        RmsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RmsSectionHeader(
                icon: Symbols.storefront,
                title: 'أداء فرع وسط البلد اليوم',
                trailing: RmsChip(label: 'الوردية الصباحية', tone: RmsChipTone.neutral),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('42,300 ج.م', style: AppTypography.headlineLg),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '312 تذكرة طلب • متوسط الفاتورة 135 ج.م',
                style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
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
                icon: Symbols.badge,
                title: 'حضور وانضباط الوردية (ATT)',
                trailing: RmsChip(label: '98% منضبط', tone: RmsChipTone.success),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildApprovalItem(
                'طاقم الصالة والمطبخ (ATT-01)',
                '12 موظف حاضر • مراجعة السجلات والتأخيرات',
                onTap: () => context.push('/attendance'),
              ),
              const Divider(height: 16),
              _buildApprovalItem('تأخيرات الوردية', 'موظف واحد (15 دقيقة)'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupplyKitchenDashboard() {
    return Column(
      children: [
        RmsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RmsSectionHeader(
                icon: Symbols.inventory_2,
                title: 'تنبيهات المخزون والتوريد المركزي',
                trailing: RmsChip(label: '3 أصناف حرجة', tone: RmsChipTone.error),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildApprovalItem('زيت القلي النباتي', 'متبقي 14 وحدة فقط - دون الحد الأدنى'),
              const Divider(height: 16),
              _buildApprovalItem('لحم بقري مفروم فريش', 'متبقي 28 كجم - يتطلب إعادة طلب'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalItem(String title, String subtitle, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelMd),
                Text(
                  subtitle,
                  style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
                ),
              ],
            ),
            const Icon(Symbols.arrow_forward_ios, size: 14, color: AppColors.secondary),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
          ),
          child: Column(
            children: [
              // Grab handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Symbols.grid_view, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('فهرس شاشات النظام (32 شاشة)', style: AppTypography.headlineSm),
                          Text(
                            'تنقل فوري لجميع شاشات الـ RMS ومراجعتها',
                            style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Symbols.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Screens List
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    _buildScreenGroup(
                      title: 'القصة 1: المصادقة وإدارة الوصول (AUTH)',
                      count: '11 شاشة',
                      color: AppColors.primary,
                      items: [
                        _ScreenItem('AUTH-01: شاشة البداية (Splash)', '/splash', Symbols.bolt),
                        _ScreenItem('AUTH-02: تسجيل الدخول (Login)', '/login', Symbols.login),
                        _ScreenItem('AUTH-03: نسيت كلمة المرور', '/auth/forgot-password', Symbols.lock_reset),
                        _ScreenItem('AUTH-04: التحقق برمز OTP', '/auth/otp', Symbols.password),
                        _ScreenItem('AUTH-05: تعيين كلمة المرور الجديدة', '/auth/reset-password', Symbols.pin),
                        _ScreenItem('AUTH-06: نجاح إعادة التعيين', '/auth/success', Symbols.check_circle),
                        _ScreenItem('AUTH-07: تغيير كلمة المرور للمستخدم', '/auth/change-password', Symbols.key),
                        _ScreenItem('AUTH-08: انتهاء مدة الجلسة', '/auth/session-expired', Symbols.lock_clock),
                        _ScreenItem('AUTH-09: مسار غير مصرح به (403)', '/auth/access-denied', Symbols.gpp_bad),
                        _ScreenItem('AUTH-10: الرئيسية الموجهة بالدور', '/home', Symbols.dashboard),
                        _ScreenItem('AUTH-11: إدارة حسابات المدير التنفيذي', '/auth/ceo/accounts', Symbols.admin_panel_settings),
                        _ScreenItem('PROFILE: الملف الشخصي وإدارة الأمان', '/profile', Symbols.manage_accounts),
                      ],
                    ),
                    _buildScreenGroup(
                      title: 'شبكة الفروع والمستودع المركزي (BRANCHES)',
                      count: '4 شاشات',
                      color: const Color(0xFFC2410C),
                      items: [
                        _ScreenItem('BR-01: قائمة شبكة الفروع', '/branches', Symbols.storefront),
                        _ScreenItem('BR-02: إنشاء وتسجيل فرع جديد', '/branches/create', Symbols.add_business),
                        _ScreenItem('BR-03: تفاصيل وتعديل بيانات الفرع', '/branches/br_1', Symbols.edit_location),
                        _ScreenItem('BR-04: تفاصيل المستودع والمطبخ المركزي', '/branches/central-kitchen', Symbols.warehouse),
                      ],
                    ),
                    _buildScreenGroup(
                      title: 'القصة 3: إدارة شؤون الموظفين والرواتب (EMP)',
                      count: '6 شاشات',
                      color: const Color(0xFF006874),
                      items: [
                        _ScreenItem('EMP-01: قائمة الموظفين النشطين', '/employees', Symbols.group),
                        _ScreenItem('EMP-02: بطاقة وتفاصيل الموظف', '/employees/1', Symbols.badge),
                        _ScreenItem('EMP-03: تعديل بيانات الموظف', '/employees/1/edit', Symbols.edit),
                        _ScreenItem('EMP-05: بيانات وهيكل الراتب والتعويض', '/employees/1/compensation', Symbols.payments),
                        _ScreenItem('EMP-06: سجل الرواتب والدفعات التاريخية', '/employees/1/pay-history', Symbols.receipt_long),
                        _ScreenItem('EMP-07: تعيين موظف جديد', '/employees/create', Symbols.person_add),
                      ],
                    ),
                    _buildScreenGroup(
                      title: 'القصة 4: الحضور والانصراف (ATT)',
                      count: '4 شاشات',
                      color: const Color(0xFF2E7D32),
                      items: [
                        _ScreenItem('ATT-01: كشف حضور طاقم الفرع', '/attendance', Symbols.how_to_reg),
                        _ScreenItem('ATT-02: تفاصيل الحضور والتأخير', '/attendance/details', Symbols.schedule),
                        _ScreenItem('ATT-03: تسوية وإعفاء خصم التأخير', '/attendance/adjust', Symbols.price_change),
                        _ScreenItem('ATT-04: سجل الحضور التاريخي للموظف', '/attendance/history', Symbols.calendar_month),
                      ],
                    ),
                    _buildScreenGroup(
                      title: 'القصة 5: ساعات العمل الإضافي (OT)',
                      count: '4 شاشات',
                      color: const Color(0xFFE65100),
                      items: [
                        _ScreenItem('OT-01: سجل العمل الإضافي بالفرع', '/overtime', Symbols.more_time),
                        _ScreenItem('OT-02: تسجيل ساعات إضافية جديدة', '/overtime/create', Symbols.add_alarm),
                        _ScreenItem('OT-03: مراجعة ساعات العمل الإضافي', '/overtime/review', Symbols.fact_check),
                        _ScreenItem('OT-04: اعتماد وقرار الساعات الإضافية', '/overtime/review', Symbols.approval),
                      ],
                    ),
                    _buildScreenGroup(
                      title: 'القصة 6: إدارة القائمة الموحدة (MENU)',
                      count: '6 شاشات',
                      color: const Color(0xFF6A1B9A),
                      items: [
                        _ScreenItem('MENU-01: القائمة الرئيسية الموحدة', '/menu', Symbols.restaurant_menu),
                        _ScreenItem('MENU-02: فئات وتصنيفات القائمة', '/menu/categories', Symbols.category),
                        _ScreenItem('MENU-03: تفاصيل الصنف والمكونات', '/menu/item_1', Symbols.lunch_dining),
                        _ScreenItem('MENU-04: إنشاء / تعديل صنف', '/menu/create', Symbols.add_circle),
                        _ScreenItem('MENU-05: طلبات تعديل الأصناف', '/menu/requests', Symbols.pending_actions),
                        _ScreenItem('MENU-06: مراجعة طلب تعديل الصنف', '/menu/requests/req_1', Symbols.assignment),
                      ],
                    ),
                    _buildScreenGroup(
                      title: 'القصة 7: تسعير الأصناف والاعتمادات (PRICE)',
                      count: '3 شاشات',
                      color: const Color(0xFF004D40),
                      items: [
                        _ScreenItem('PRICE-01: طلبات تغيير الأسعار', '/pricing/requests', Symbols.price_change),
                        _ScreenItem('PRICE-02: مراجعة واعتماد طلب التسعير', '/pricing/requests/pcr_1', Symbols.approval),
                        _ScreenItem('PRICE-03: سجل تغييرات الأسعار التاريخية', '/pricing/history/item_1', Symbols.history),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreenGroup({
    required String title,
    required String count,
    required Color color,
    required List<_ScreenItem> items,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          title: Text(title, style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
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
          children: items.map((item) {
            return ListTile(
              dense: true,
              leading: Icon(item.icon, size: 20, color: color),
              title: Text(item.title, style: AppTypography.bodySm),
              subtitle: Text(item.route, style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 10)),
              trailing: const Icon(Symbols.chevron_left, size: 18, color: AppColors.secondary),
              onTap: () {
                Navigator.pop(context);
                context.push(item.route);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ScreenItem {
  final String title;
  final String route;
  final IconData icon;

  const _ScreenItem(this.title, this.route, this.icon);
}
