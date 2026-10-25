import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../widgets/stock_widgets.dart';
import '../../data/stock_preview_data.dart';
import '../../domain/entities/stock_item.dart';

class CentralKitchenDashboardScreen extends StatelessWidget {
  const CentralKitchenDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => StockPageShell(
    title: 'المطبخ المركزي',
    tab: 0,
    child: StockScrollBody(
      children: [
        _depotHeader(),
        const SizedBox(height: 16),
        _quickActions(context),
        const SizedBox(height: 20),
        _stockOverview(),
        const SizedBox(height: 20),
        _criticalStock(context),
        const SizedBox(height: 20),
        _recentMovements(context),
      ],
    ),
  );

  Widget _depotHeader() => Container(
    padding: const EdgeInsets.all(AppDimens.paddingMd),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Depot-01 • تشغيل نشط', style: TextStyle(color: Colors.white70)),
        SizedBox(height: 7),
        Text(
          'موقع التصنيع والتوريد المركزي',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'مخزون وتشغيل فقط • لا توجد مبيعات مباشرة',
          style: TextStyle(color: Colors.white),
        ),
      ],
    ),
  );

  Widget _quickActions(BuildContext context) => Column(
    children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => context.push('/kitchen/items/create'),
          icon: const Icon(Icons.add),
          label: const Text('إضافة صنف جديد'),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.push('/kitchen/movements'),
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('إذن صرف / شحن'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.push('/kitchen/movements'),
              icon: const Icon(Icons.move_to_inbox_outlined),
              label: const Text('استلام توريد'),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _stockOverview() => const Row(
    children: [
      Expanded(
        child: StockMetricCard(
          label: 'قيمة المخزون',
          value: '842,500 ج.م',
          icon: Icons.account_balance_wallet_outlined,
        ),
      ),
      SizedBox(width: 10),
      Expanded(
        child: StockMetricCard(
          label: 'إجمالي الأصناف',
          value: '142 صنف',
          icon: Icons.inventory_2_outlined,
        ),
      ),
    ],
  );

  Widget _criticalStock(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      StockSectionTitle(
        'نواقص تتطلب شراء عاجل',
        icon: Icons.warning_amber_rounded,
        trailing: TextButton(
          onPressed: () => context.push('/kitchen/items'),
          child: const Text('عرض الكل'),
        ),
      ),
      const SizedBox(height: 10),
      for (final item in StockPreviewData.centralKitchenItems.where(
        (item) => item.level == StockLevel.critical,
      )) ...[
        StockItemCard(
          item: item,
          onTap: () => context.push('/kitchen/items/${item.id}'),
        ),
        const SizedBox(height: 8),
      ],
    ],
  );

  Widget _recentMovements(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      StockSectionTitle(
        'آخر حركات المخزون',
        icon: Icons.swap_horiz,
        trailing: TextButton(
          onPressed: () => context.push('/kitchen/movements'),
          child: const Text('عرض الكل'),
        ),
      ),
      const SizedBox(height: 10),
      for (final movement in StockPreviewData.centralMovements.take(3)) ...[
        StockMovementCard(movement: movement),
        const SizedBox(height: 8),
      ],
      const Text(
        'آخر جرد معتمد اليوم • 06:00 ص',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.secondary),
      ),
    ],
  );
}
