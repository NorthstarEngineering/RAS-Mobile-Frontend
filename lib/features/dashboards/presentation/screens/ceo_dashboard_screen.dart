import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';

const _ceoNavigation = [
  RmsOpsDestination('الرئيسية', Icons.dashboard_outlined, '/dashboard/ceo'),
  RmsOpsDestination('الفروع', Icons.storefront_outlined, '/branches'),
  RmsOpsDestination('الموظفون', Icons.badge_outlined, '/employees'),
  RmsOpsDestination('التوريد', Icons.inventory_2_outlined, '/supply'),
  RmsOpsDestination('الحساب', Icons.person_outline, '/profile'),
];

class CeoDashboardScreen extends StatelessWidget {
  const CeoDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'لوحة الرئيس التنفيذي',
    destinations: _ceoNavigation,
    children: [
      _dateBar(),
      const SizedBox(height: 12),
      _revenueSummary(),
      const SizedBox(height: 12),
      _profitSummary(),
      const SizedBox(height: 12),
      _networkMetrics(),
      const SizedBox(height: 12),
      _pendingApprovals(context),
      const SizedBox(height: 12),
      _branchPerformance(),
      const SizedBox(height: 12),
      _activity(),
    ],
  );

  Widget _dateBar() => const ListTile(
    leading: Icon(Icons.calendar_today, color: AppColors.primary),
    title: Text('اليوم — 16 أبريل 2024'),
    subtitle: Text('مجموعة مطاعم الضيافة الموحدة • مباشر'),
  );

  Widget _revenueSummary() => const RmsOpsSection(
    title: 'إجمالي المبيعات الشاملة',
    icon: Icons.payments_outlined,
    child: Column(
      children: [
        Text(
          '184,500 ج.م',
          style: TextStyle(fontSize: 29, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Expanded(
              child: RmsOpsMetric(
                label: 'الصالات والمطاعم',
                value: '122,000 ج.م',
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: RmsOpsMetric(label: 'خدمات التوصيل', value: '62,500 ج.م'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _profitSummary() => const RmsOpsSection(
    title: 'مؤشرات الربحية والعمالة',
    icon: Icons.analytics_outlined,
    child: Row(
      children: [
        Expanded(
          child: RmsOpsMetric(
            label: 'مجمل الربح',
            value: '118,000 ج.م',
            color: AppColors.success,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: RmsOpsMetric(label: 'تكلفة العمالة', value: '28,500 ج.م'),
        ),
      ],
    ),
  );

  Widget _networkMetrics() => const Row(
    children: [
      Expanded(
        child: RmsOpsMetric(
          label: 'الفروع النشطة',
          value: '8 من 8',
          icon: Icons.wifi,
          color: AppColors.success,
        ),
      ),
      SizedBox(width: 8),
      Expanded(
        child: RmsOpsMetric(
          label: 'المخزون المركزي',
          value: '3 أصناف حرجة',
          icon: Icons.inventory_2_outlined,
          color: AppColors.error,
        ),
      ),
    ],
  );

  Widget _pendingApprovals(BuildContext context) => RmsOpsSection(
    title: 'إجراءات تتطلب موافقة عاجلة',
    icon: Icons.pending_actions,
    trailing: const RmsOpsStatus('9'),
    child: Column(
      children: [
        _approvalRow(
          '2 طلب تعديل أسعار',
          'مراجعة الأسعار',
          () => context.push('/pricing/requests'),
        ),
        _approvalRow(
          '3 طلبات أصناف جديدة',
          'طلبات القائمة',
          () => context.push('/menu/requests'),
        ),
        _approvalRow(
          '4 اعتمادات ساعات إضافية',
          'مراجعة الساعات',
          () => context.push('/overtime/approve'),
        ),
      ],
    ),
  );

  Widget _approvalRow(String title, String action, VoidCallback onTap) =>
      ListTile(
        title: Text(title),
        trailing: TextButton(onPressed: onTap, child: Text(action)),
      );

  Widget _branchPerformance() => const RmsOpsSection(
    title: 'أداء الفروع اليوم',
    icon: Icons.storefront_outlined,
    child: Column(
      children: [
        RmsOpsRecord(
          title: 'فرع وسط البلد (#01)',
          subtitle: '42,300 ج.م • 312 تذكرة • حضور 98%',
        ),
        SizedBox(height: 8),
        RmsOpsRecord(
          title: 'فرع التجمع الخامس (#02)',
          subtitle: '38,100 ج.م • 248 تذكرة • تأخير وردية 1',
        ),
        SizedBox(height: 8),
        RmsOpsRecord(
          title: 'فرع الشيخ زايد (#04)',
          subtitle: '31,400 ج.م • أداء ممتاز',
        ),
      ],
    ),
  );

  Widget _activity() => const RmsOpsSection(
    title: 'النشاطات التشغيلية الحديثة',
    icon: Icons.history,
    child: Text(
      'إغلاق الصندوق المالي للوردية الصباحية • تنبيه نفاد زيت القلي • تحديث أسعار منصات التوصيل',
    ),
  );
}
