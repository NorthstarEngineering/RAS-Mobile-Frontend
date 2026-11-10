import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/menu_category.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/repositories/menu_repository.dart';

class CreateEditMenuItemScreen extends StatefulWidget {
  final String? itemId;

  const CreateEditMenuItemScreen({super.key, this.itemId});

  @override
  State<CreateEditMenuItemScreen> createState() =>
      _CreateEditMenuItemScreenState();
}

class _CreateEditMenuItemScreenState extends State<CreateEditMenuItemScreen> {
  final MenuRepository _repository = getIt<MenuRepository>();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameArController;
  late TextEditingController _nameEnController;
  late TextEditingController _skuController;
  late TextEditingController _barcodeController;
  late TextEditingController _priceController;
  late TextEditingController _costController;
  late TextEditingController _kitchenStationController;

  String? _selectedCategoryId;
  bool _isActive = true;
  bool _isLoading = true;
  List<MenuCategory> _categories = [];

  bool get isEdit => widget.itemId != null;

  @override
  void initState() {
    super.initState();
    _nameArController = TextEditingController();
    _nameEnController = TextEditingController();
    _skuController = TextEditingController();
    _barcodeController = TextEditingController();
    _priceController = TextEditingController();
    _costController = TextEditingController();
    _kitchenStationController = TextEditingController(
      text: 'محطة البرجر واللحوم',
    );
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final cats = await _repository.getCategories();
    MenuItem? item;
    if (isEdit) {
      item = await _repository.getMenuItemById(widget.itemId!);
    }

    if (mounted) {
      setState(() {
        _categories = cats;
        if (cats.isNotEmpty) {
          _selectedCategoryId = cats.first.id;
        }

        if (item != null) {
          _nameArController.text = item.nameAr;
          _nameEnController.text = item.nameEn;
          _skuController.text = item.sku;
          _barcodeController.text = item.barcode;
          _priceController.text = item.price.toStringAsFixed(2);
          _costController.text = item.cost.toStringAsFixed(2);
          _kitchenStationController.text = item.kitchenStation;
          _selectedCategoryId = item.categoryId;
          _isActive = item.isActive;
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _kitchenStationController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final selectedCat = _categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => _categories.first,
    );

    final item = MenuItem(
      id: isEdit
          ? widget.itemId!
          : 'item_${DateTime.now().millisecondsSinceEpoch}',
      sku: _skuController.text.trim(),
      barcode: _barcodeController.text.trim(),
      nameAr: _nameArController.text.trim(),
      nameEn: _nameEnController.text.trim(),
      categoryId: selectedCat.id,
      categoryName: selectedCat.nameAr,
      price: double.tryParse(_priceController.text.trim()) ?? 0.0,
      cost: double.tryParse(_costController.text.trim()) ?? 0.0,
      kitchenStation: _kitchenStationController.text.trim(),
      isActive: _isActive,
    );

    await _repository.saveMenuItem(item);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'تم تحديث بيانات الصنف بنجاح'
                : 'تمت إضافة الصنف الجديد إلى المنيو',
          ),
          backgroundColor: const Color(0xFF2E8B2E),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(isEdit ? 'تعديل صنف القائمة' : 'إضافة صنف جديد'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.paddingMd),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top banner
                    Container(
                      padding: const EdgeInsets.all(AppDimens.paddingMd),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.restaurant_menu,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: AppDimens.paddingSm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit
                                      ? 'صنف رقم #${widget.itemId}'
                                      : 'إضافة صنف جديد بالقائمة المركزية',
                                  style: AppTypography.labelMd.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'تعديلات الصنف تنعكس مباشرة على أنظمة الكاشير المعتمدة',
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.secondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.errorContainer,
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusFull,
                              ),
                            ),
                            child: Text(
                              'خاص بالإدارة المركزية',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onErrorContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.paddingLg),

                    // Section 1: Basic Info
                    Container(
                      padding: const EdgeInsets.all(AppDimens.paddingLg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'البيانات الأساسية للصنف',
                                style: AppTypography.headlineSm.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'حقول إلزامية (*)',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimens.paddingMd),

                          // Name Ar
                          TextFormField(
                            controller: _nameArController,
                            decoration: const InputDecoration(
                              labelText: 'اسم الصنف بالعربية *',
                              hintText: 'مثال: برجر دجاج مقرمش',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.translate),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? 'يرجى إدخال اسم الصنف'
                                : null,
                          ),
                          const SizedBox(height: AppDimens.paddingMd),

                          // Name En
                          TextFormField(
                            controller: _nameEnController,
                            decoration: const InputDecoration(
                              labelText: 'اسم الصنف بالإنجليزية',
                              hintText: 'e.g. Crispy Chicken Burger',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.language),
                            ),
                          ),
                          const SizedBox(height: AppDimens.paddingMd),

                          // SKU & Barcode
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _skuController,
                                  decoration: const InputDecoration(
                                    labelText: 'رمز الصنف (SKU) *',
                                    hintText: 'CHK-01',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (val) =>
                                      val == null || val.trim().isEmpty
                                      ? 'مطلوب'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _barcodeController,
                                  decoration: const InputDecoration(
                                    labelText: 'الباركود',
                                    hintText: '6223001849...',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimens.paddingMd),

                          // Category select
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedCategoryId,
                            decoration: const InputDecoration(
                              labelText: 'الفئة / القسم *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: _categories.map((c) {
                              return DropdownMenuItem<String>(
                                value: c.id,
                                child: Text(c.nameAr),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _selectedCategoryId = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.paddingMd),

                    // Section 2: Pricing
                    Container(
                      padding: const EdgeInsets.all(AppDimens.paddingLg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'البيانات المالية والتسعير',
                            style: AppTypography.headlineSm.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppDimens.paddingMd),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _priceController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'سعر البيع (ج.م) *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.sell_outlined),
                                  ),
                                  validator: (val) =>
                                      val == null || val.trim().isEmpty
                                      ? 'مطلوب'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _costController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'تكلفة الإنتاج (ج.م)',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(
                                      Icons.account_balance_wallet_outlined,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.paddingMd),

                    // Section 3: Operations & Kitchen
                    Container(
                      padding: const EdgeInsets.all(AppDimens.paddingLg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'محطة التشغيل والحالة',
                            style: AppTypography.headlineSm.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppDimens.paddingMd),
                          TextFormField(
                            controller: _kitchenStationController,
                            decoration: const InputDecoration(
                              labelText: 'محطة الطهي (KDS)',
                              hintText: 'محطة البرجر واللحوم',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.kitchen_outlined),
                            ),
                          ),
                          const SizedBox(height: AppDimens.paddingMd),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('تفعيل الصنف للبيع على الكاشير'),
                            subtitle: const Text(
                              'عند الإلغاء، يختفي الصنف فوراً من نقاط البيع',
                            ),
                            value: _isActive,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) => setState(() => _isActive = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.paddingLg),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusXl,
                          ),
                        ),
                      ),
                      child: Text(
                        isEdit ? 'حفظ التعديلات' : 'إضافة الصنف للمنيو',
                        style: AppTypography.labelMd.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
