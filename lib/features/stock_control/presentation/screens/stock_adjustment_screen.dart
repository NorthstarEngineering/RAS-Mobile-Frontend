import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/rms_primary_button.dart';
import '../../data/stock_preview_data.dart';
import '../../domain/entities/stock_item.dart';
import '../widgets/stock_widgets.dart';

enum _AdjustmentMode { deficit, surplus, setBalance }

class StockAdjustmentScreen extends StatefulWidget {
  const StockAdjustmentScreen({super.key, required this.itemId});
  final String itemId;

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  final _note = TextEditingController(
    text: 'تم استبعاد كمية تالفة بعد فحص الجودة أثناء التجهيز.',
  );
  _AdjustmentMode _mode = _AdjustmentMode.deficit;
  double _quantity = 3;
  String _reason = 'هالك أثناء التحضير';
  bool _acknowledged = false;

  StockItem get _item => StockPreviewData.branchItems.firstWhere(
    (item) => item.id == widget.itemId,
    orElse: () => StockPreviewData.branchItems.first,
  );
  double get _signedAdjustment => switch (_mode) {
    _AdjustmentMode.deficit => -_quantity,
    _AdjustmentMode.surplus => _quantity,
    _AdjustmentMode.setBalance => _quantity - _item.quantity,
  };
  double get _newBalance =>
      (_item.quantity + _signedAdjustment).clamp(0, double.infinity).toDouble();
  double get _financialImpact =>
      (_newBalance - _item.quantity) * _item.unitCost;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StockPageShell(
    title: 'تسوية المخزون',
    showNavigation: false,
    child: StockScrollBody(
      children: [
        _auditNotice(),
        const SizedBox(height: 12),
        _itemSummary(),
        const SizedBox(height: 12),
        _balanceEquation(),
        const SizedBox(height: 12),
        _modeSelector(),
        const SizedBox(height: 12),
        _quantityControl(),
        const SizedBox(height: 12),
        _reasonSelector(),
        const SizedBox(height: 12),
        _authorization(),
        _acknowledgement(),
        const SizedBox(height: 12),
        RmsPrimaryButton(
          label: 'تأكيد واعتماد التسوية المخزنية',
          icon: Icons.check_circle_outline,
          onPressed: _confirm,
        ),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('إلغاء وتراجع دون حفظ'),
        ),
      ],
    ),
  );

  Widget _auditNotice() => Container(
    padding: const EdgeInsets.all(AppDimens.paddingMd),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
    ),
    child: const Text(
      'تنبيه الحوكمة والتدقيق • التسوية تؤثر على تكلفة المخزون وتتطلب سبباً موثقاً وهوية المسؤول المعتمد.',
    ),
  );

  Widget _itemSummary() => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _item.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          Text('${_item.sku} • ${_item.category}'),
          const SizedBox(height: 8),
          Text('الفرع: وسط البلد (#01) • الموقع: ${_item.location}'),
        ],
      ),
    ),
  );

  Widget _balanceEquation() => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      child: Column(
        children: [
          const StockSectionTitle('معادلة رصيد التسوية الفعلي'),
          const SizedBox(height: 8),
          Text(
            '${_fmt(_item.quantity)} ${_item.unit}  →  ${_fmt(_signedAdjustment)}  →  ${_fmt(_newBalance)} ${_item.unit}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Text(
            'الأثر المالي المباشر: ${_financialImpact.toStringAsFixed(2)} ج.م',
            style: TextStyle(
              color: _financialImpact < 0 ? AppColors.error : AppColors.success,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _modeSelector() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('نوع التسوية المخزنية *'),
      const SizedBox(height: 5),
      SegmentedButton<_AdjustmentMode>(
        segments: const [
          ButtonSegment(
            value: _AdjustmentMode.deficit,
            label: Text('عجز / هالك'),
          ),
          ButtonSegment(value: _AdjustmentMode.surplus, label: Text('فائض')),
          ButtonSegment(
            value: _AdjustmentMode.setBalance,
            label: Text('تعديل رصيد'),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (selection) =>
            setState(() => _mode = selection.first),
      ),
    ],
  );

  Widget _quantityControl() => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('كمية التعديل (${_item.unit}) *'),
          Row(
            children: [
              IconButton(
                onPressed: () => _changeQuantity(-.5),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Expanded(
                child: Text(
                  _fmt(_quantity),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _changeQuantity(.5),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            children: <double>[.5, 1, 2, 5]
                .map(
                  (amount) => ActionChip(
                    label: Text('${_fmt(amount)} ${_item.unit}'),
                    onPressed: () => setState(() => _quantity = amount),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
  );

  Widget _reasonSelector() => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سبب التسوية الإلزامي *'),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _reason,
            items:
                const [
                      'هالك أثناء التحضير',
                      'تلف وتجاوز الصلاحية',
                      'خطأ في تسجيل الإدخال',
                      'عينة فحص جودة',
                      'كسر / انسكاب أثناء النقل',
                    ]
                    .map(
                      (reason) => DropdownMenuItem(
                        value: reason,
                        child: Text(
                          reason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (reason) => setState(() => _reason = reason!),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'تفاصيل السبب للتدقيق',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _authorization() => const ListTile(
    leading: Icon(Icons.verified_user_outlined, color: AppColors.primary),
    title: Text('م. ألفاريز'),
    subtitle: Text('مدير فرع وسط البلد (#01)'),
    trailing: Text('#ADJ-2024-0419'),
  );

  Widget _acknowledgement() => CheckboxListTile(
    value: _acknowledged,
    onChanged: (value) => setState(() => _acknowledged = value ?? false),
    controlAffinity: ListTileControlAffinity.leading,
    title: const Text(
      'أقر بصحة كمية الجرد، وأعلم أن الحركة لا يمكن تعديلها بعد الترحيل.',
    ),
  );

  void _changeQuantity(double delta) => setState(
    () => _quantity = (_quantity + delta).clamp(.5, 9999).toDouble(),
  );

  void _confirm() {
    if (!_acknowledged || _note.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكمل الإقرار وسبب التسوية قبل المتابعة')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم التحقق من التسوية محلياً؛ لا يوجد ربط بخدمة مخزون'),
      ),
    );
  }

  String _fmt(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}
