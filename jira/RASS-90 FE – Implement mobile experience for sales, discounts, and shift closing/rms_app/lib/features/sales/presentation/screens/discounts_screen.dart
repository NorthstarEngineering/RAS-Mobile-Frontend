import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../data/repositories/http_sales_repository.dart';
import '../../domain/repositories/sales_repository.dart';

class DiscountsScreen extends StatefulWidget {
  const DiscountsScreen({super.key, this.repository});

  final SalesRepository? repository;

  @override
  State<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends State<DiscountsScreen> {
  late final SalesRepository _repository;
  String _filter = 'الكل';
  bool _isLoading = false;
  String? _errorMessage;
  List<DiscountItemData> _items = [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (sl.isRegistered<SalesRepository>()
            ? sl<SalesRepository>()
            : HttpSalesRepository.instance);
    _fetchDiscounts();
  }

  Future<void> _fetchDiscounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await _repository.getDiscounts(status: _filter);
      if (mounted) {
        setState(() {
          _items = list;
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

  double get _totalDiscountsAmount {
    if (_items.isEmpty) return 0.0;
    return _items
        .where((d) => d.status == 'applied')
        .fold(0.0, (sum, d) => sum + d.amount);
  }

  int get _cancelledCount => _items.where((d) => d.status == 'cancelled').length;

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'الخصومات',
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
            title: 'خطأ في جلب الخصومات',
            message: _errorMessage!,
            color: AppColors.errorContainer,
          ),
        ),
      _summary(),
      const SizedBox(height: 10),
      const RmsOpsBanner(
        title: 'تنبيه الحوكمة والتدقيق الداخلي',
        message: 'يُحفظ كل خصم في السجل مع الفاتورة وسبب الخصم المعتمد.',
        color: AppColors.errorContainer,
      ),
      const SizedBox(height: 8),
      _filters(),
      const SizedBox(height: 8),
      _discountList(context),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: _export,
        icon: const Icon(Icons.file_download_outlined),
        label: const Text('تصدير كشف الخصومات المعتمد'),
      ),
    ],
  );

  Widget _summary() => RmsOpsSection(
    title: 'إجمالي الخصومات المسجلة',
    icon: Icons.percent,
    child: Column(
      children: [
        Text(
          '${_totalDiscountsAmount.toStringAsFixed(2)} ج.م',
          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Expanded(
              child: RmsOpsMetric(
                label: 'عدد الحركات',
                value: '${_items.length}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RmsOpsMetric(
                label: 'حالات إلغاء',
                value: '$_cancelledCount',
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _filters() => Wrap(
    spacing: 6,
    children: ['الكل', 'خصم تسويقي', 'خصم موظفين', 'ملغاة']
        .map(
          (label) => ChoiceChip(
            label: Text(label),
            selected: _filter == label,
            onSelected: (_) {
              setState(() => _filter = label);
              _fetchDiscounts();
            },
          ),
        )
        .toList(),
  );

  Widget _discountList(BuildContext context) {
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'لا توجد خصومات مسجلة لهذه الوردية (0.00 ج.م)',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: _items
          .map(
            (discount) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RmsOpsRecord(
                title: '${discount.invoiceRef} • ${discount.title}',
                subtitle: discount.status == 'cancelled'
                    ? 'تم الإلغاء بواسطة ${discount.cancelledByName ?? "المدير"} • ${discount.cancelReason ?? ""}'
                    : discount.authorizedByName,
                status: discount.status == 'cancelled'
                    ? const RmsOpsStatus(
                        'ملغى',
                        color: AppColors.error,
                      )
                    : const RmsOpsStatus(
                        'معتمد ونشط',
                        color: AppColors.success,
                      ),
                details: [
                  Text(
                    '${discount.grossAmount.toStringAsFixed(2)} ج.م قبل الخصم → ${discount.netAmount.toStringAsFixed(2)} ج.م صافي التحصيل (قيمة الخصم: ${discount.amount.toStringAsFixed(2)} ج.م)',
                  ),
                ],
                actions: [
                  if (discount.status != 'cancelled')
                    TextButton(
                      onPressed: () => context
                          .push('/sales/discounts/${discount.id}/cancel')
                          .then((_) => _fetchDiscounts()),
                      child: const Text('إلغاء الخصم (SALES-06)'),
                    ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  void _export() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('تم تجهيز معاينة كشف الخصومات')));
}
