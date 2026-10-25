import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/rms_primary_button.dart';
import '../widgets/stock_widgets.dart';

class CreateStockItemScreen extends StatefulWidget {
  const CreateStockItemScreen({super.key});

  @override
  State<CreateStockItemScreen> createState() => _CreateStockItemScreenState();
}

class _CreateStockItemScreenState extends State<CreateStockItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _cost = TextEditingController();
  final _quantity = TextEditingController();
  final _safety = TextEditingController();
  String _category = 'لحوم ودواجن';
  String _unit = 'كجم';

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _cost.dispose();
    _quantity.dispose();
    _safety.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StockPageShell(
    title: 'إضافة صنف خام',
    showNavigation: false,
    child: StockScrollBody(
      children: [
        _notice(),
        const SizedBox(height: 14),
        Form(
          key: _formKey,
          child: Column(
            children: [
              _textInput(_name, 'اسم الصنف بالكامل', 'مثال: لحم بقري مفروم'),
              _textInput(_sku, 'كود الصنف (SKU)', 'RAW-MEAT-102'),
              _dropdown('الفئة التصنيفية', _category, const [
                'لحوم ودواجن',
                'زيوت ودهون',
                'صوصات مركزية',
                'خضروات',
                'مخبوزات',
              ], (v) => setState(() => _category = v!)),
              _dropdown('وحدة القياس المعتمدة', _unit, const [
                'كجم',
                'لتر',
                'قطعة',
                'كرتونة',
                'جوال',
              ], (v) => setState(() => _unit = v!)),
              _textInput(_cost, 'تكلفة الوحدة (ج.م)', '0.00', numeric: true),
              _textInput(_quantity, 'الكمية الحالية', '0', numeric: true),
              _textInput(_safety, 'حد الأمان الأدنى', '0', numeric: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _storageNotice(),
        const SizedBox(height: 16),
        RmsPrimaryButton(
          label: 'حفظ واعتماد الصنف المخزني',
          icon: Icons.save_outlined,
          onPressed: _save,
        ),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('إلغاء وتراجع'),
        ),
      ],
    ),
  );

  Widget _notice() => const Card(
    child: Padding(
      padding: EdgeInsets.all(AppDimens.paddingMd),
      child: Text(
        'أصناف المطبخ المركزي مخصصة للتحضير الداخلي والتوريد للفروع، وليست أصناف بيع مباشر.',
      ),
    ),
  );

  Widget _textInput(
    TextEditingController controller,
    String label,
    String hint, {
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      validator: (text) =>
          text == null || text.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: options
          .map((option) => DropdownMenuItem(value: option, child: Text(option)))
          .toList(),
      onChanged: onChanged,
    ),
  );

  Widget _storageNotice() => Container(
    padding: const EdgeInsets.all(AppDimens.paddingMd),
    decoration: BoxDecoration(
      color: AppColors.primaryFixed,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
    ),
    child: const Text(
      'وحدة القياس ثابتة لجميع أذونات الإدخال والصرف والتحويل.',
    ),
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم التحقق من بيانات الصنف محلياً')),
    );
  }
}
