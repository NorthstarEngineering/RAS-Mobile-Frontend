import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../auth/domain/entities/user_session.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/menu_category.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/repositories/menu_repository.dart';
import '../widgets/menu_load_view.dart';

class CreateEditMenuItemScreen extends StatefulWidget {
  const CreateEditMenuItemScreen({super.key, this.itemId});
  final String? itemId;
  @override
  State<CreateEditMenuItemScreen> createState() =>
      _CreateEditMenuItemScreenState();
}

class _CreateEditMenuItemScreenState extends State<CreateEditMenuItemScreen> {
  final _repository = sl<MenuRepository>();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nameEn = TextEditingController();
  final _sku = TextEditingController();
  final _price = TextEditingController();
  final _station = TextEditingController();
  final _prepTime = TextEditingController(text: '0');
  final _description = TextEditingController();
  late Future<List<MenuCategory>> _initial;
  String _categoryId = '';
  bool _active = true;
  bool _saving = false;
  bool get _isEdit => widget.itemId != null;

  @override
  void initState() {
    super.initState();
    _initial = _load();
  }

  Future<List<MenuCategory>> _load() async {
    final categories = await _repository.getCategories();
    if (_isEdit) {
      final item = await _repository.getMenuItemById(widget.itemId!);
      if (item == null) throw const FormatException('الصنف غير موجود');
      if (!mounted) return categories;
      _name.text = item.nameAr;
      _nameEn.text = item.nameEn;
      _sku.text = item.sku;
      _price.text = item.price.toStringAsFixed(2);
      _station.text = item.kitchenStation;
      _prepTime.text = item.prepTimeMinutes.toString();
      _description.text = item.description;
      _categoryId = item.categoryId;
      _active = item.isActive;
    }
    return categories;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _nameEn,
      _sku,
      _price,
      _station,
      _prepTime,
      _description,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  MenuItem _draft() => MenuItem(
    id: widget.itemId ?? '',
    sku: _sku.text.trim(),
    barcode: '',
    nameAr: _name.text.trim(),
    nameEn: _nameEn.text.trim(),
    categoryId: _categoryId,
    categoryName: '',
    price: double.parse(_price.text.trim()),
    cost: 0,
    kitchenStation: _station.text.trim(),
    description: _description.text.trim(),
    prepTimeMinutes: int.parse(_prepTime.text.trim()),
    isActive: _active,
  );

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _repository.saveMenuItem(_draft());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ الصنف')));
      context.pop(true);
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(menuErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_isEdit ? 'تعديل صنف القائمة' : 'إضافة صنف جديد'),
    ),
    body: sl<AuthBloc>().state.session?.role != StaffRole.ceo
        ? const Center(child: Text('إدارة الأصناف متاحة للمدير التنفيذي فقط'))
        : MenuLoadView<List<MenuCategory>>(
            future: _initial,
            onRetry: () => setState(() => _initial = _load()),
            builder: _form,
          ),
  );

  Widget _form(List<MenuCategory> categories) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppDimens.paddingMd),
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'اسم الصنف *'),
            validator: (text) =>
                text == null || text.trim().isEmpty ? 'أدخل اسم الصنف' : null,
          ),
          const SizedBox(height: 16),
          _field(_nameEn, 'الاسم بالإنجليزية'),
          TextFormField(
            controller: _sku,
            enabled: !_isEdit,
            decoration: const InputDecoration(labelText: 'كود الصنف SKU *'),
            validator: (text) =>
                text == null || text.trim().isEmpty ? 'أدخل كود الصنف' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'التصنيف'),
            items: [
              const DropdownMenuItem(value: '', child: Text('بدون تصنيف')),
              ...categories.map(
                (category) => DropdownMenuItem(
                  value: category.id,
                  child: Text(category.nameAr),
                ),
              ),
              if (_categoryId.isNotEmpty &&
                  !categories.any((c) => c.id == _categoryId))
                DropdownMenuItem(
                  value: _categoryId,
                  child: const Text('التصنيف الحالي'),
                ),
            ],
            onChanged: (selected) =>
                setState(() => _categoryId = selected ?? ''),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'سعر البيع *'),
            validator: (text) {
              final price = double.tryParse(text?.trim() ?? '');
              return price == null || !price.isFinite || price <= 0
                  ? 'أدخل سعرًا أكبر من صفر'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          _field(_station, 'محطة التحضير'),
          TextFormField(
            controller: _prepTime,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'وقت التحضير بالدقائق',
            ),
            validator: (text) {
              final minutes = int.tryParse(text?.trim() ?? '');
              return minutes == null || minutes < 0
                  ? 'أدخل عدد دقائق صحيحًا غير سالب'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          _field(_description, 'الوصف'),
          if (_isEdit)
            SwitchListTile(
              title: const Text('الصنف نشط'),
              value: _active,
              onChanged: (active) => setState(() => _active = active),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الصنف'),
          ),
        ],
      ),
    ),
  );
}
