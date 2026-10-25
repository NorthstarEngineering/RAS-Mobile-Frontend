import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../data/repositories/http_sales_repository.dart';
import '../../domain/repositories/sales_repository.dart';

class RestaurantSalesScreen extends StatefulWidget {
  const RestaurantSalesScreen({super.key});
  @override
  State<RestaurantSalesScreen> createState() => _RestaurantSalesScreenState();
}

class _RestaurantSalesScreenState extends State<RestaurantSalesScreen> {
  String _category = 'الكل';
  String _query = '';
  RestaurantSalesData? _salesData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRestaurantSales();
  }

  Future<void> _fetchRestaurantSales() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await HttpSalesRepository.instance.getRestaurantSales(
        category: _category,
        query: _query.isNotEmpty ? _query : null,
      );
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
    title: 'مبيعات المطعم',
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
            title: 'خطأ في جلب المبيعات',
            message: _errorMessage!,
            color: AppColors.errorContainer,
          ),
        ),
      _revenue(),
      const SizedBox(height: 10),
      const RmsOpsBanner(
        title: 'إشعار تثبيت السعر التاريخي',
        message: 'تحسب الإيرادات حسب سعر البيع المعتمد وقت تسجيل الطلب.',
        color: AppColors.surfaceContainerHigh,
      ),
      const SizedBox(height: 10),
      _search(),
      _categories(),
      const SizedBox(height: 8),
      _itemList(),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: _export,
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: const Text('تصدير تقرير مبيعات المطعم'),
      ),
    ],
  );

  Widget _revenue() {
    final sales = _salesData?.totalSales ?? 0.0;
    final orders = _salesData?.totalOrders ?? 0;

    return RmsOpsMetric(
      label: 'مبيعات الصالة والسفري',
      value: '${_money(sales)} ج.م • $orders طلب',
      icon: Icons.restaurant_outlined,
    );
  }

  Widget _search() => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: TextField(
      onChanged: (value) {
        setState(() => _query = value.toLowerCase());
        _fetchRestaurantSales();
      },
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'ابحث باسم الصنف أو الكود',
      ),
    ),
  );

  Widget _categories() {
    final cats = _salesData?.categories.isNotEmpty == true
        ? _salesData!.categories
        : const ['الكل'];

    return Wrap(
      spacing: 5,
      children: cats
          .map(
            (category) => ChoiceChip(
              label: Text(category),
              selected: _category == category,
              onSelected: (_) {
                setState(() => _category = category);
                _fetchRestaurantSales();
              },
            ),
          )
          .toList(),
    );
  }

  Widget _itemList() {
    final items = _salesData?.items ?? const [];

    final visible = items
        .where(
          (item) =>
              (_category == 'الكل' || item.category == _category) &&
              '${item.name} ${item.sku}'.toLowerCase().contains(_query),
        )
        .toList();

    if (visible.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'لا توجد أصناف مباعة مسجلة لهذا التصنيف أو البحث (0.00 ج.م)',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: visible
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RmsOpsRecord(
                title: item.name,
                subtitle: '${item.sku} • ${item.category}',
                status: RmsOpsStatus('${item.quantity} وجبة'),
                details: [
                  Text(
                    'سعر الوحدة ${item.unitPrice.toStringAsFixed(2)} ج.م • إجمالي ${_money(item.totalAmount)} ج.م',
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  void _export() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('تم تجهيز معاينة التقرير بنجاح')),
  );
  String _money(double amount) => amount.toStringAsFixed(2);
}
