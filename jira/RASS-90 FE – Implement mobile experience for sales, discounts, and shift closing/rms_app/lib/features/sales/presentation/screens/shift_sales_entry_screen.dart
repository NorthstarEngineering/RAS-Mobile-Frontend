import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../../../core/widgets/rms_primary_button.dart';
import '../../data/repositories/http_sales_repository.dart';
import '../../domain/repositories/sales_repository.dart';

class ShiftSalesEntryScreen extends StatefulWidget {
  const ShiftSalesEntryScreen({super.key, this.repository});

  final SalesRepository? repository;

  @override
  State<ShiftSalesEntryScreen> createState() => _ShiftSalesEntryScreenState();
}

class _ShiftSalesEntryScreenState extends State<ShiftSalesEntryScreen> {
  late final SalesRepository _repository;
  bool _isSubmitting = false;

  static const _menuItems = [
    'برجر كلاسيك سينجل',
    'برجر سموكي تشيز دبل',
    'ستربس دجاج مقرمش',
  ];

  int _burgerCount = 60;
  int _sandwichCount = 50;
  int _chickenCount = 45;
  int _draftQuantity = 1;
  String _selectedProduct = _menuItems.first;
  int get _total =>
      _burgerCount * 180 + _sandwichCount * 240 + _chickenCount * 110;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (sl.isRegistered<SalesRepository>()
            ? sl<SalesRepository>()
            : HttpSalesRepository.instance);
  }

  Future<void> _saveAndReview() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final entry = ShiftSalesEntryInput(
        shiftId: 'shift_01',
        channel: 'dine_in',
        grossAmount: _total.toDouble(),
        discountAmount: 0.0,
        netAmount: _total.toDouble(),
        paymentMethod: 'cash',
        orderCount: _burgerCount + _sandwichCount + _chickenCount,
        branchId: 'br_01',
        items: [
          if (_burgerCount > 0)
            {
              'name': 'وجبة برجر كلاسيك سينجل',
              'sku': 'MENU-BRG-01',
              'category': 'البرجر',
              'quantity': _burgerCount,
              'unitPrice': 180.0,
            },
          if (_sandwichCount > 0)
            {
              'name': 'برجر سموكي تشيز دبل',
              'sku': 'MENU-BRG-04',
              'category': 'البرجر',
              'quantity': _sandwichCount,
              'unitPrice': 240.0,
            },
          if (_chickenCount > 0)
            {
              'name': 'ستربس دجاج مقرمش',
              'sku': 'MENU-CHK-02',
              'category': 'الدجاج والمقبلات',
              'quantity': _chickenCount,
              'unitPrice': 110.0,
            },
        ],
      );

      await _repository.recordShiftEntry(entry);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ حركات المبيعات وتحديث حسابات الوردية بنجاح')),
        );
        context.push('/sales/shift/review');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تسجيل مبيعات الوردية: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'إدخال مبيعات الوردية',
    showProfile: false,
    children: [
      if (_isSubmitting)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: LinearProgressIndicator(),
        ),
      _shiftInfo(),
      const SizedBox(height: 10),
      const RmsOpsBanner(
        title: 'قاعدة التسعير التاريخي المعتمد',
        message: 'السعر المسجل هو سعر البيع المعتمد بالقائمة وقت تسجيل الطلب.',
        color: AppColors.tertiaryFixed,
      ),
      const SizedBox(height: 10),
      _itemPicker(),
      const SizedBox(height: 10),
      _enteredItems(),
      const SizedBox(height: 12),
      _summary(),
      const SizedBox(height: 10),
      RmsPrimaryButton(
        label: _isSubmitting
            ? 'جاري الحفظ والتسجيل...'
            : 'حفظ ومراجعة إغلاق الوردية (SALES-07)',
        icon: Icons.check_circle_outline,
        onPressed: _isSubmitting ? null : _saveAndReview,
      ),
      TextButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Text('إلغاء وتراجع'),
      ),
    ],
  );

  Widget _shiftInfo() => const RmsOpsSection(
    title: 'الوردية الصباحية • 08:00 ص — 04:00 م',
    icon: Icons.schedule,
    child: Text(
      'فرع وسط البلد (#01) • المدير المسؤول: م. ألفاريز • التسجيل مفتوح',
    ),
  );

  Widget _itemPicker() => RmsOpsSection(
    title: 'إضافة صنف لمبيعات الوردية',
    icon: Icons.add_shopping_cart,
    child: Column(
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _selectedProduct,
          decoration: const InputDecoration(labelText: 'الصنف من قائمة الفرع'),
          items: _menuItems
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (item) => setState(() => _selectedProduct = item!),
        ),
        const SizedBox(height: 8),
        _stepper(
          'الكمية',
          _draftQuantity,
          (value) => setState(() => _draftQuantity = value),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            onPressed: _addSelectedProduct,
            icon: const Icon(Icons.add),
            label: const Text('إضافة الصنف'),
          ),
        ),
      ],
    ),
  );

  void _addSelectedProduct() {
    setState(() {
      switch (_selectedProduct) {
        case 'برجر كلاسيك سينجل':
          _burgerCount += _draftQuantity;
        case 'برجر سموكي تشيز دبل':
          _sandwichCount += _draftQuantity;
        case 'ستربس دجاج مقرمش':
          _chickenCount += _draftQuantity;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تمت إضافة $_selectedProduct محلياً')),
    );
  }

  Widget _enteredItems() => RmsOpsSection(
    title: 'الأصناف المسجلة',
    child: Column(
      children: [
        _salesLine(
          'برجر كلاسيك سينجل',
          'MENU-BRG-01',
          _burgerCount,
          180,
          (value) => setState(() => _burgerCount = value),
        ),
        _salesLine(
          'برجر سموكي تشيز دبل',
          'MENU-BRG-04',
          _sandwichCount,
          240,
          (value) => setState(() => _sandwichCount = value),
        ),
        _salesLine(
          'ستربس دجاج مقرمش',
          'MENU-CHK-02',
          _chickenCount,
          110,
          (value) => setState(() => _chickenCount = value),
        ),
      ],
    ),
  );

  Widget _salesLine(
    String name,
    String code,
    int count,
    int price,
    ValueChanged<int> onChanged,
  ) => ListTile(
    title: Text(name),
    subtitle: Text('$code • سعر البيع ${price.toString()} ج.م'),
    trailing: _stepper('وجبة', count, onChanged),
  );

  Widget _stepper(String label, int count, ValueChanged<int> onChanged) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        onPressed: () => onChanged((count - 1).clamp(0, 999).toInt()),
        icon: const Icon(Icons.remove),
      ),
      Text('$count $label'),
      IconButton(
        onPressed: () => onChanged(count + 1),
        icon: const Icon(Icons.add),
      ),
    ],
  );

  Widget _summary() => RmsOpsMetric(
    label: 'إجمالي مبيعات الوردية اللحظي',
    value: '${_total.toString()} ج.م • 3 أصناف',
  );
}
