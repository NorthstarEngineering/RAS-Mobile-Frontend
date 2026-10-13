import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

class CentralKitchenDetailsScreen extends StatelessWidget {
  const CentralKitchenDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_forward, color: AppColors.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'المستودع والمطبخ المركزي',
          style: AppTypography.headlineSm.copyWith(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.margin,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Notice Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Symbols.warehouse, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'موقع مخزون وتصنيع مركزي (Stock-Only Hub)',
                          style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                      ),
                      child: Text(
                        'غير مخصص للبيع',
                        style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 10),
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryFixed,
                                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                              ),
                              child: Text(
                                'Depot-01',
                                style: AppTypography.labelSm.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: AppColors.onPrimaryFixedVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('المطبخ المركزي الرئيسي', style: AppTypography.headlineSm.copyWith(fontSize: 16)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5EA),
                            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                          ),
                          child: Text(
                            '99.8% جاهزية',
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
                      'المنطقة الصناعية، العبور، القليوبية • إشراف: شيف مصطفى عبد اللطيف',
                      style: AppTypography.bodySm.copyWith(color: AppColors.secondary, fontSize: 12),
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
                              Text('الطاقة الاستيعابية', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                              Text('142 طن مبرد', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('طاقم التجهيز', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                              Text('24 شيف وفني', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('شاحنات التوزيع', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                              Text('6 شاحنات مبردة', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
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
                        Row(
                          children: [
                            const Icon(Symbols.warning, color: AppColors.error, size: 20),
                            const SizedBox(width: 6),
                            Text('تنبيهات المخزون الحرج', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer,
                            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
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
                        const Icon(Symbols.local_shipping, color: AppColors.primary, size: 20),
                        const SizedBox(width: 6),
                        Text('توريدات الفروع النشطة اليوم', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryFixed,
                        child: Icon(Symbols.store, color: AppColors.primary, size: 20),
                      ),
                      title: const Text('فرع وسط البلد (#01)'),
                      subtitle: const Text('شاحنة #02 • 14 صنف مجمد وجاف'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                        ),
                        child: const Text('جاري الشحن', style: TextStyle(color: Color(0xFFE65100), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const Divider(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        child: Icon(Symbols.store, color: AppColors.secondary, size: 20),
                      ),
                      title: const Text('فرع المعادي (#02)'),
                      subtitle: const Text('شاحنة #05 • تم التسليم 08:30 ص'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF5EA),
                          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                        ),
                        child: const Text('مكتمل', style: TextStyle(color: Color(0xFF2E8B2E), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Action button
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم فتح نافذة صرف المستودع المركزي')),
                  );
                },
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
    );
  }

  Widget _buildStockAlertItem(String title, String subtitle, String status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
            Text(subtitle, style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          ),
          child: Text(status, style: AppTypography.labelSm.copyWith(fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
