import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/rms_primary_button.dart';
import '../../data/repositories/http_central_kitchen_repository.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/repositories/central_kitchen_repository.dart';
import '../widgets/stock_widgets.dart';

class CreateStockItemScreen extends StatefulWidget {
  const CreateStockItemScreen({
    super.key,
    this.initialItem,
    this.repository,
  });

  final StockItem? initialItem;
  final CentralKitchenRepository? repository;

  @override
  State<CreateStockItemScreen> createState() => _CreateStockItemScreenState();
}

class _CreateStockItemScreenState extends State<CreateStockItemScreen> {
  late final CentralKitchenRepository _repository;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _cost = TextEditingController();
  final _quantity = TextEditingController();
  final _safety = TextEditingController();
  String _category = 'لحوم ودواجن';
  String _unit = 'كجم';
  bool _isSubmitting = false;
  StockItem? _existingItem;
  bool _initialized = false;

  bool get _isEditing => _existingItem != null;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (sl.isRegistered<CentralKitchenRepository>()
            ? sl<CentralKitchenRepository>()
            : HttpCentralKitchenRepository(
                apiClient:
                    sl.isRegistered<ApiClient>() ? sl<ApiClient>() : null,
              ));

    if (widget.initialItem != null) {
      _applyItem(widget.initialItem!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      if (_existingItem == null) {
        _initFromRouteState();
      }
    }
  }

  void _initFromRouteState() {
    try {
      final state = GoRouterState.of(context);
      if (state.extra is StockItem) {
        _applyItem(state.extra as StockItem);
        return;
      }
      final qId = state.uri.queryParameters['id'];
      if (qId != null && qId.isNotEmpty) {
        _repository.getItemById(qId).then((item) {
          if (item != null && mounted) {
            _applyItem(item);
          }
        });
      }
    } catch (_) {}
  }

  void _applyItem(StockItem item) {
    setState(() {
      _existingItem = item;
      _name.text = item.name;
      _sku.text = item.sku;
      _cost.text = item.unitCost == item.unitCost.roundToDouble()
          ? item.unitCost.toInt().toString()
          : item.unitCost.toString();
      _quantity.text = item.quantity == item.quantity.roundToDouble()
          ? item.quantity.toInt().toString()
          : item.quantity.toString();
      _safety.text = item.safetyStock == item.safetyStock.roundToDouble()
          ? item.safetyStock.toInt().toString()
          : item.safetyStock.toString();
      if (item.category.isNotEmpty) _category = item.category;
      if (item.unit.isNotEmpty) _unit = item.unit;
    });
  }

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
    title: _isEditing ? 'تعديل بيانات الصنف الخام' : 'إضافة صنف خام',
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
                'ألبان وخامات',
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
          label: _isSubmitting
              ? 'جاري الحفظ...'
              : (_isEditing ? 'تحديث بيانات الصنف المخزني' : 'حفظ واعتماد الصنف المخزني'),
          icon: _isEditing ? Icons.check_circle_outline : Icons.save_outlined,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _save,
        ),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('إلغاء وتراجع'),
        ),
      ],
    ),
  );

  Widget _notice() => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      child: Text(
        _isEditing
            ? 'تعديل بيانات الصنف بالمستودع المركزي مع تسجيل التغيير في سجل التدقيق المعتمد.'
            : 'أصناف المطبخ المركزي مخصصة للتحضير الداخلي والتوريد للفروع، وليست أصناف بيع مباشر.',
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
      initialValue: options.contains(value) ? value : options.first,
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final name = _name.text.trim();
      final sku = _sku.text.trim();
      final cost = double.tryParse(_cost.text.trim()) ?? 0.0;
      final quantity = double.tryParse(_quantity.text.trim()) ?? 0.0;
      final safety = double.tryParse(_safety.text.trim()) ?? 0.0;
      final cap = max(quantity, safety) * 2.0;

      if (_isEditing) {
        final existing = _existingItem!;
        final updatedItem = existing.copyWith(
          name: name,
          sku: sku,
          category: _category,
          quantity: quantity,
          unit: _unit,
          unitCost: cost,
          safetyStock: safety,
          capacity: cap > 0 ? cap : existing.capacity,
          branchId: existing.branchId.isNotEmpty ? existing.branchId : 'br_04',
          level: quantity <= safety * 0.5
              ? StockLevel.critical
              : (quantity <= safety ? StockLevel.low : StockLevel.available),
        );

        await _repository.updateItem(existing.id, updatedItem);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث بيانات الصنف المخزني بنجاح'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.of(context).maybePop(true);
      } else {
        final cleanId = sku.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
        final newItem = StockItem(
          id: 'ck_$cleanId',
          name: name,
          sku: sku,
          category: _category,
          quantity: quantity,
          unit: _unit,
          unitCost: cost,
          safetyStock: safety,
          capacity: cap > 0 ? cap : 100.0,
          location: 'المستودع الرئيسي للمطبخ المركزي',
          branchId: 'br_04',
          level: quantity <= safety * 0.5
              ? StockLevel.critical
              : (quantity <= safety ? StockLevel.low : StockLevel.available),
        );

        await _repository.createItem(newItem);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ واعتماد الصنف المخزني بالمطبخ المركزي بنجاح'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.of(context).maybePop(true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل حفظ الصنف: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
