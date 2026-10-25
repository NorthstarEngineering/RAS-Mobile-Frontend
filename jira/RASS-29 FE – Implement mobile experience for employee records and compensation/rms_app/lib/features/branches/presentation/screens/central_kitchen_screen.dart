import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/routing/navigation_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/repositories/http_branch_repository.dart';
import '../../domain/repositories/branch_repository.dart';

class CentralKitchenDetailsScreen extends StatefulWidget {
  const CentralKitchenDetailsScreen({super.key});

  @override
  State<CentralKitchenDetailsScreen> createState() => _CentralKitchenDetailsScreenState();
}

class _CentralKitchenDetailsScreenState extends State<CentralKitchenDetailsScreen> {
  late final BranchRepository _repository;
  Map<String, dynamic>? _summary;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = HttpBranchRepository();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _repository.getCentralKitchenSummary();
      if (mounted) {
        setState(() {
          _summary = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kitchenBranch = _summary?['kitchenBranch'] as Map<String, dynamic>?;
    final code = kitchenBranch?['code'] as String? ?? 'Depot-01';
    final name = kitchenBranch?['name'] as String? ?? 'المطبخ المركزي الرئيسي';
    final address = kitchenBranch?['address'] as String? ?? 'المنطقة الصناعية، العبور، القليوبية';
    final manager = kitchenBranch?['managerName'] as String? ?? 'شيف مصطفى عبد اللطيف';
    final readiness = _summary?['readinessText'] as String? ?? '99.8% جاهزية';
    final capacity = _summary?['capacityDescription'] as String? ?? '142 طن مبرد';
    final crew = _summary?['crewDescription'] as String? ?? '24 شيف وفني';
    final fleet = _summary?['fleetDescription'] as String? ?? '6 شاحنات مبردة';
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
          leading: IconButton(
            icon: const Icon(Symbols.arrow_forward, color: AppColors.onSurface),
            onPressed: () => context.safePop(fallback: '/home'),
          ),
          title: Text(
            'المستودع والمطبخ المركزي',
            style: AppTypography.headlineSm.copyWith(fontSize: 18),
          ),
        ),
      body: SafeArea(
        child: _isLoading && _summary == null
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null && _summary == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Symbols.error, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          'تعذر جلب مؤشرات المطبخ المركزي: $_errorMessage',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMd.copyWith(color: AppColors.error),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchSummary,
                          icon: const Icon(Symbols.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.margin,
                      vertical: AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
              // Top Notice Banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Symbols.warehouse,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'موقع مخزون وتصنيع مركزي (Stock-Only Hub)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSm.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusFull,
                        ),
                      ),
                      child: Text(
                        'غير مخصص للبيع',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.secondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Hub Overview Card
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryFixed,
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusSm,
                                  ),
                                ),
                                child: Text(
                                  code,
                                  style: AppTypography.labelSm.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: AppColors.onPrimaryFixedVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.headlineSm.copyWith(
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5EA),
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusFull,
                            ),
                          ),
                          child: Text(
                            readiness,
                            style: AppTypography.labelSm.copyWith(
                              color: const Color(0xFF2E8B2E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$address • إشراف: $manager',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الطاقة الاستيعابية',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                              Text(
                                capacity,
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'طاقم التجهيز',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                              Text(
                                crew,
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'شاحنات التوزيع',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                              Text(
                                fleet,
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Critical Stock Alerts
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Symbols.warning,
                                color: AppColors.error,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'تنبيهات المخزون الحرج',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelMd.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer,
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusFull,
                            ),
                          ),
                          child: Text(
                            'صنفان دون الحد الأدنى',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildStockAlertItem(
                      'زيت القلي النباتي النقي',
                      'متبقي 14 وحدة فقط - الحد الأدنى 50 وحدة',
                      'طلب شراء عاجل',
                    ),
                    const Divider(height: 16),
                    _buildStockAlertItem(
                      'لحم بقري مفروم فريش (تحضير برجر)',
                      'متبقي 28 كجم - الحد الأدنى 100 كجم',
                      'توريد مجدول غداً',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Deliveries in Progress
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Symbols.local_shipping,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'توريدات الفروع النشطة اليوم',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryFixed,
                        child: Icon(
                          Symbols.store,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: const Text('فرع وسط البلد (#01)'),
                      subtitle: const Text('شاحنة #02 • 14 صنف مجمد وجاف'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusFull,
                          ),
                        ),
                        child: const Text(
                          'جاري الشحن',
                          style: TextStyle(
                            color: Color(0xFFE65100),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        child: Icon(
                          Symbols.store,
                          color: AppColors.secondary,
                          size: 20,
                        ),
                      ),
                      title: const Text('فرع المعادي (#02)'),
                      subtitle: const Text('شاحنة #05 • تم التسليم 08:30 ص'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF5EA),
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusFull,
                          ),
                        ),
                        child: const Text(
                          'مكتمل',
                          style: TextStyle(
                            color: Color(0xFF2E8B2E),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Action button
              ElevatedButton.icon(
                onPressed: () => _showDispatchReceiptModal(context),
                icon: const Icon(Symbols.receipt_long),
                label: const Text('إصدار إذن صرف أو استلام مخزني'),
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
      ),
    ),
  );
}

  void _showDispatchReceiptModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'عمليات المستودع والمطبخ المركزي',
                style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'اختر العملية المراد تنفيذها وحفظها في قاعدة البيانات',
                style: AppTypography.bodySm.copyWith(color: AppColors.secondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryFixed,
                  child: Icon(Symbols.local_shipping, color: AppColors.primary),
                ),
                title: const Text('إصدار إذن صرف وشحن لفرع (Transfer Dispatch)'),
                subtitle: const Text('تحويل وتوزيع وجبات ومواد للفروع مع اعتماد فوري'),
                trailing: const Icon(Symbols.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/transfers/create');
                },
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEAF5EA),
                  child: Icon(Symbols.inventory_2, color: Color(0xFF2E8B2E)),
                ),
                title: const Text('طلب توريد واستلام مخزني (Supply Order)'),
                subtitle: const Text('إصدار طلب توريد مواد خام ومستلزمات من الموردين'),
                trailing: const Icon(Symbols.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/supply/create');
                },
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.surfaceContainerHigh,
                  child: Icon(Symbols.receipt_long, color: AppColors.secondary),
                ),
                title: const Text('سجل الشحنات والتحويلات النشطة'),
                subtitle: const Text('عرض ومتابعة كافة أذون الصرف والتوصيل اليومية'),
                trailing: const Icon(Symbols.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/transfers');
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockAlertItem(String title, String subtitle, String status) {
    return InkWell(
      onTap: () => context.push('/supply/create'),
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
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
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: status == 'حرج'
                    ? AppColors.errorContainer
                    : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              ),
              child: Text(
                status,
                style: AppTypography.labelSm.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: status == 'حرج' ? AppColors.error : AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
