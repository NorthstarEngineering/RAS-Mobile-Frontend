import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';

class SupplyManagerDashboardScreen extends StatelessWidget {
  const SupplyManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'لوحة مدير التوريد',
    selectedIndex: 1,
    destinations: const [
      RmsOpsDestination(
        'الرئيسية',
        Icons.dashboard_outlined,
        '/dashboard/supply',
      ),
      RmsOpsDestination('التوريد', Icons.inventory_2_outlined, '/supply'),
      RmsOpsDestination('الموظفون', Icons.badge_outlined, '/employees'),
      RmsOpsDestination('الفروع', Icons.storefront_outlined, '/branches'),
      RmsOpsDestination('الحساب', Icons.person_outline, '/profile'),
    ],
    children: [
      _depotStatus(),
      const SizedBox(height: 12),
      _depotMetrics(),
      const SizedBox(height: 12),
      _urgentShortages(context),
      const SizedBox(height: 12),
      _fulfillment(),
      const SizedBox(height: 12),
      _incomingOrders(context),
      const SizedBox(height: 12),
      _fleet(),
    ],
  );

  Widget _depotStatus() => const RmsOpsBanner(
    title: 'المطبخ المركزي الرئيسي (Depot-01)',
    message:
        'تشغيل نشط • مخزون وتصنيع فقط • مدير الإمداد والتصنيع: ماركوس ثورن',
  );

  Widget _depotMetrics() => const Row(
    children: [
      Expanded(
        child: RmsOpsMetric(label: 'إجمالي الأصناف', value: '142'),
      ),
      SizedBox(width: 8),
      Expanded(
        child: RmsOpsMetric(
          label: 'حد الطلب الحرج',
          value: '4 مواد',
          color: AppColors.error,
        ),
      ),
      SizedBox(width: 8),
      Expanded(
        child: RmsOpsMetric(
          label: 'قيد التجهيز',
          value: '6 طلبات',
          color: AppColors.warning,
        ),
      ),
    ],
  );

  Widget _urgentShortages(BuildContext context) => RmsOpsSection(
    title: 'نواقص حرجة تتطلب تعميد أمر شراء',
    icon: Icons.warning_amber,
    child: Column(
      children: [
        const RmsOpsRecord(
          title: 'لحم بقري مفروم',
          subtitle: '12 كجم متبقية • حد الأمان 50 كجم',
          status: RmsOpsStatus('حرج', color: AppColors.error),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => context.push('/supply/create'),
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('إنشاء طلب توريد عاجل'),
        ),
      ],
    ),
  );

  Widget _fulfillment() => const RmsOpsSection(
    title: 'إشغال خطوط التجهيز المركزية',
    icon: Icons.precision_manufacturing_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('78% • 5 من 6 خطوط نشطة'),
        SizedBox(height: 8),
        LinearProgressIndicator(value: .78),
        Text('خط اللحوم 88% • خط الصوصات 72% • المخبوزات 55%'),
      ],
    ),
  );

  Widget _incomingOrders(BuildContext context) => RmsOpsSection(
    title: 'طلبات التوريد الواردة من الفروع',
    icon: Icons.move_to_inbox_outlined,
    child: Column(
      children: [
        RmsOpsRecord(
          title: 'طلب فرع وسط البلد (#01)',
          subtitle: 'شحنة خضار مجهزة • 40 كجم لحوم متبلة',
          status: const RmsOpsStatus('مستعجل جداً', color: AppColors.error),
          actions: [
            TextButton(
              onPressed: () => context.push('/supply/1'),
              child: const Text('التفاصيل'),
            ),
            FilledButton(
              onPressed: () => context.push('/supply/1/execute'),
              child: const Text('اعتماد وصرف'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const RmsOpsRecord(
          title: 'طلب فرع التجمع (#02)',
          subtitle: 'صوصات تكفي 500 وجبة • جاهز للتحضير',
        ),
        const SizedBox(height: 8),
        const RmsOpsRecord(
          title: 'طلب فرع الشيخ زايد (#04)',
          subtitle: 'مشروبات وخامات جافة • 12 كرتونة',
        ),
      ],
    ),
  );

  Widget _fleet() => const RmsOpsSection(
    title: 'حركة سيارات التوزيع',
    icon: Icons.local_shipping_outlined,
    child: Text('2 شاحنات تبريد في الطريق • شاحنة تنتظر تأكيد الاستلام'),
  );
}
