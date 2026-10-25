import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';

class BranchManagerDashboardScreen extends StatelessWidget {
  const BranchManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'لوحة مدير الفرع',
    destinations: const [
      RmsOpsDestination(
        'الرئيسية',
        Icons.dashboard_outlined,
        '/dashboard/branch',
      ),
      RmsOpsDestination('الفروع', Icons.storefront_outlined, '/branches'),
      RmsOpsDestination('الموظفون', Icons.badge_outlined, '/employees'),
      RmsOpsDestination('التوريد', Icons.inventory_2_outlined, '/supply'),
      RmsOpsDestination('الحساب', Icons.person_outline, '/profile'),
    ],
    children: [
      _shiftSummary(),
      const SizedBox(height: 12),
      _branchSales(context),
      const SizedBox(height: 12),
      _attendance(context),
      const SizedBox(height: 12),
      _stockAlerts(context),
      const SizedBox(height: 12),
      _quickApprovals(context),
      const SizedBox(height: 12),
      _branchActivity(),
    ],
  );

  Widget _shiftSummary() => const RmsOpsSection(
    title: 'فرع وسط البلد • وردية الصباح',
    icon: Icons.storefront,
    child: Text(
      'بث تشغيلي مباشر • المشرف المسؤول: م. ألفاريز • من 08:00 ص إلى 04:00 م',
    ),
  );

  Widget _branchSales(BuildContext context) => RmsOpsSection(
    title: 'مبيعات الفرع اليومية',
    icon: Icons.payments_outlined,
    trailing: TextButton(
      onPressed: () => context.push('/sales'),
      child: const Text('تفاصيل'),
    ),
    child: const Column(
      children: [
        Text(
          '42,300 ج.م',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Expanded(
              child: RmsOpsMetric(label: 'صالة وطاولات', value: '28,400 ج.م'),
            ),
            SizedBox(width: 8),
            Expanded(
              child: RmsOpsMetric(
                label: 'تيك أواي وتوصيل',
                value: '13,900 ج.م',
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _attendance(BuildContext context) => RmsOpsSection(
    title: 'كفاءة الحضور والانضباط',
    icon: Icons.groups_outlined,
    child: Column(
      children: [
        const Row(
          children: [
            Expanded(
              child: RmsOpsMetric(label: 'حاضر بالفرع', value: '14 / 16'),
            ),
            SizedBox(width: 8),
            Expanded(
              child: RmsOpsMetric(
                label: 'حالات التأخير',
                value: '2',
                color: AppColors.error,
              ),
            ),
          ],
        ),
        ListTile(
          title: const Text('خصومات التأخير الآلية'),
          trailing: const Text('100 ج.م'),
          onTap: () => context.push('/attendance'),
        ),
        ListTile(
          title: const Text('مقترح ساعات إضافية'),
          trailing: const Text('3 ساعات'),
          onTap: () => context.push('/overtime'),
        ),
      ],
    ),
  );

  Widget _stockAlerts(BuildContext context) => RmsOpsSection(
    title: 'تنبيهات المخزون والتوريد',
    icon: Icons.notifications_active_outlined,
    child: Column(
      children: [
        RmsOpsRecord(
          title: 'نقص دجاج متبل • حرج',
          subtitle: 'المتبقي 4 كجم فقط في ثلاجة الفرع',
          status: const RmsOpsStatus('عاجل', color: AppColors.error),
        ),
        const SizedBox(height: 8),
        RmsOpsRecord(
          title: 'طلب توريد SUP-104#',
          subtitle: 'قيد التجهيز من المطبخ المركزي',
          status: const RmsOpsStatus('بالطريق', color: AppColors.tertiary),
        ),
        TextButton(
          onPressed: () => context.push('/inventory'),
          child: const Text('فتح المخزون'),
        ),
      ],
    ),
  );

  Widget _quickApprovals(BuildContext context) => RmsOpsSection(
    title: 'إجراءات تشغيلية مطلوبة',
    icon: Icons.bolt,
    child: Column(
      children: [
        _linkRow(
          'مراجعة بصمات الوردية وإغلاق الحضور',
          () => context.push('/attendance'),
        ),
        _linkRow('طلب إضافة صنف للقائمة', () => context.push('/menu/requests')),
        _linkRow(
          'رفع طلب تعديل سعر وجبة',
          () => context.push('/pricing/requests'),
        ),
      ],
    ),
  );

  Widget _branchActivity() => const RmsOpsSection(
    title: 'سجل أحداث الفرع اليوم',
    icon: Icons.history,
    child: Text(
      '12:15 م • تطبيق خصم تأخير تلقائي\n11:30 ص • تأكيد طلب التوريد SUP-104#\n08:00 ص • افتتاح الخزينة ونقاط البيع',
    ),
  );

  Widget _linkRow(String label, VoidCallback onTap) => ListTile(
    title: Text(label),
    trailing: const Icon(Icons.chevron_left),
    onTap: onTap,
  );
}
