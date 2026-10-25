import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../data/repositories/http_sales_repository.dart';
import '../../domain/repositories/sales_repository.dart';

class DeliverySalesScreen extends StatefulWidget {
  const DeliverySalesScreen({super.key});
  @override
  State<DeliverySalesScreen> createState() => _DeliverySalesScreenState();
}

class _DeliverySalesScreenState extends State<DeliverySalesScreen> {
  String _channel = 'الكل';
  DeliverySalesData? _salesData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDeliverySales();
  }

  Future<void> _fetchDeliverySales() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await HttpSalesRepository.instance.getDeliverySales(channel: _channel);
      if (mounted) {
        setState(() {
          _salesData = data;
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

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'مبيعات التوصيل',
    showProfile: false,
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
            title: 'خطأ في جلب بيانات التوصيل',
            message: _errorMessage!,
            color: AppColors.errorContainer,
          ),
        ),
      _revenue(),
      const SizedBox(height: 10),
      const RmsOpsBanner(
        title: 'تسعير تاريخي معتمد',
        message: 'أسعار التوصيل منفصلة عن مبيعات الصالة والسفري.',
        color: AppColors.surfaceContainerHigh,
      ),
      const SizedBox(height: 8),
      _channels(),
      const SizedBox(height: 8),
      _ordersList(),
      const SizedBox(height: 10),
      _reconciliation(),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: _export,
        icon: const Icon(Icons.file_download_outlined),
        label: const Text('تصدير كشف التوصيل'),
      ),
    ],
  );

  Widget _revenue() {
    final rev = _salesData?.totalRevenue ?? 0.0;
    final orders = _salesData?.totalOrders ?? 0;

    return RmsOpsMetric(
      label: 'إجمالي إيراد التوصيل',
      value: '${_money(rev)} ج.م • $orders طلباً',
      icon: Icons.delivery_dining,
    );
  }

  Widget _channels() {
    final channels = _salesData?.channels.isNotEmpty == true
        ? _salesData!.channels
        : const ['الكل', 'منصات التوصيل', 'توصيل مباشر', 'توصيل مشترك'];

    return Wrap(
      spacing: 5,
      children: channels
          .map(
            (label) => ChoiceChip(
              label: Text(label),
              selected: label == _channel,
              onSelected: (_) {
                setState(() => _channel = label);
                _fetchDeliverySales();
              },
            ),
          )
          .toList(),
    );
  }

  Widget _ordersList() {
    final orders = _salesData?.orders ?? const [];

    final visible = orders
        .where((order) => _channel == 'الكل' || order.channel == _channel)
        .toList();

    if (visible.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'لا توجد طلبات توصيل مسجلة (0.00 ج.م)',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: visible
          .map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RmsOpsRecord(
                title: order.title,
                subtitle: '${order.sku} • ${order.channel}',
                details: [
                  Text(
                    '${order.quantity} طلب × ${order.unitPrice.toStringAsFixed(2)} ج.م • الإجمالي ${_money(order.totalAmount)} ج.م',
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _reconciliation() {
    final reconcil = _salesData?.reconciliation ?? const {};
    final gross = ((reconcil['grossRevenue'] ?? 0.0) as num).toDouble();
    final comm = ((reconcil['platformCommissions'] ?? 0.0) as num).toDouble();
    final net = ((reconcil['netCollected'] ?? reconcil['netDepositExpected'] ?? 0.0) as num).toDouble();

    return RmsOpsSection(
      title: 'ملخص رقابي لوردية التوصيل',
      child: Column(
        children: [
          ListTile(
            title: const Text('إجمالي إيراد القنوات'),
            trailing: Text('${_money(gross)} ج.م'),
          ),
          ListTile(
            title: const Text('عمولات المنصات التقديرية (15%)'),
            trailing: Text('-${_money(comm)} ج.م'),
          ),
          ListTile(
            title: const Text('صافي المحصل للفرع'),
            trailing: Text('${_money(net)} ج.م'),
          ),
        ],
      ),
    );
  }

  void _export() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('واجهة التصدير جاهزة للربط بخدمة الملفات')),
  );
  String _money(double amount) => amount.toStringAsFixed(2);
}
