import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../data/repositories/http_sales_repository.dart';
import '../../domain/repositories/sales_repository.dart';

class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({super.key, this.repository});

  final SalesRepository? repository;

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  late final SalesRepository _repository;
  SalesDashboardData? _data;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (sl.isRegistered<SalesRepository>()
            ? sl<SalesRepository>()
            : HttpSalesRepository.instance);
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _repository.getSalesDashboard();
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  String _formatMoney(double amount) {
    final parts = amount.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return parts.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'لوحة المبيعات',
    selectedIndex: 2,
    destinations: const [
      RmsOpsDestination('الرئيسية', Icons.home_outlined, '/dashboard/branch'),
      RmsOpsDestination('الفروع', Icons.storefront_outlined, '/branches'),
      RmsOpsDestination('المبيعات', Icons.point_of_sale_outlined, '/sales'),
      RmsOpsDestination('المخزون', Icons.inventory_2_outlined, '/inventory'),
      RmsOpsDestination('الحساب', Icons.person_outline, '/profile'),
    ],
    children: [
      if (_isLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: LinearProgressIndicator(),
        ),
      if (_errorMessage != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RmsOpsBanner(
            title: 'تنبيه اتصال الشبكة',
            message: 'تعذر جلب بيانات المبيعات الحية: $_errorMessage',
            color: AppColors.errorContainer,
          ),
        ),
      _shiftStatus(),
      const SizedBox(height: 10),
      _totalSales(),
      const SizedBox(height: 10),
      _entryActions(context),
      const SizedBox(height: 10),
      _summaryMetrics(),
      const SizedBox(height: 12),
      _channels(),
      const SizedBox(height: 12),
      _auditNote(),
      const SizedBox(height: 8),
      _closingActions(context),
    ],
  );

  Widget _shiftStatus() {
    final status = _data?.shiftStatus;
    final isOpen = status?.isOpen ?? true;
    final title = isOpen ? 'وردية نشطة مفتوحة' : 'وردية مغلقة';
    final desc = status?.description ??
        'فرع وسط البلد (#01) • الوردية الصباحية • بانتظار بدء التشغيل';

    return RmsOpsSection(
      title: title,
      icon: Icons.schedule,
      child: Text(desc),
    );
  }

  Widget _totalSales() {
    final total = _data?.totalSales ?? 0.0;
    final dineRatio = _data?.dineInRatio ?? 0.0;
    final deliveryRatio = _data?.deliveryRatio ?? 0.0;

    return RmsOpsSection(
      title: 'إجمالي مبيعات الوردية (Gross Revenue)',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          Text(
            '${_formatMoney(total)} ج.م',
            style: const TextStyle(fontSize: 29, fontWeight: FontWeight.bold),
          ),
          LinearProgressIndicator(value: dineRatio.clamp(0.0, 1.0)),
          Text(
            'صالة ومطعم ${(dineRatio * 100).toStringAsFixed(1)}% • توصيل ${(deliveryRatio * 100).toStringAsFixed(1)}%',
          ),
        ],
      ),
    );
  }

  Widget _entryActions(BuildContext context) => Column(
    children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => context.push('/sales/shift/entry').then((_) => _loadDashboard()),
          icon: const Icon(Icons.add),
          label: const Text('إدخال مبيعات الوردية (SALES-04)'),
        ),
      ),
      Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => context.push('/sales/restaurant'),
              child: const Text('مبيعات المطعم (SALES-02)'),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: () => context.push('/sales/delivery'),
              child: const Text('مبيعات التوصيل (SALES-03)'),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _summaryMetrics() {
    final orders = _data?.totalOrders ?? 0;
    final discounts = _data?.totalDiscounts ?? 0.0;
    final net = _data?.netSales ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: RmsOpsMetric(
            label: 'الطلبات الكلية',
            value: '$orders طلب',
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: RmsOpsMetric(
            label: 'الخصومات',
            value: '${_formatMoney(discounts)} ج.م',
            color: AppColors.error,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: RmsOpsMetric(
            label: 'صافي المبيعات',
            value: '${_formatMoney(net)} ج.م',
          ),
        ),
      ],
    );
  }

  Widget _channels() {
    final channels = _data?.channels;

    if (channels != null && channels.isNotEmpty) {
      return RmsOpsSection(
        title: 'تفصيل القنوات والوردية',
        icon: Icons.pie_chart_outline,
        child: Column(
          children: [
            for (int i = 0; i < channels.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              RmsOpsRecord(
                title: channels[i].title,
                subtitle: channels[i].subtitle.isNotEmpty
                    ? channels[i].subtitle
                    : '${channels[i].orderCount} طلب • ${_formatMoney(channels[i].totalAmount)} ج.م • ${channels[i].percentage.toStringAsFixed(1)}%',
              ),
            ],
          ],
        ),
      );
    }

    return const RmsOpsSection(
      title: 'تفصيل القنوات والوردية',
      icon: Icons.pie_chart_outline,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('لا توجد مبيعات مسجلة في القنوات لهذه الوردية (0.00 ج.م)'),
      ),
    );
  }

  Widget _auditNote() => const RmsOpsBanner(
    title: 'ضوابط التدقيق المالي والتشغيل',
    message:
        'أرقام المبيعات تعكس إيرادات نقاط البيع الفعلية، ولا ترتبط بحركات صرف الخامات أو تسويات المخزون.',
    color: AppColors.surfaceContainerHigh,
  );

  Widget _closingActions(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => context.push('/sales/discounts').then((_) => _loadDashboard()),
          child: const Text('سجل الخصومات'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: FilledButton(
          onPressed: () => context.push('/sales/shift/review').then((_) => _loadDashboard()),
          child: const Text('مراجعة إغلاق الوردية'),
        ),
      ),
    ],
  );
}
