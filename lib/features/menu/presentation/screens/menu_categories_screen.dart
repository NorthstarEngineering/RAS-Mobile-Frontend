import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/menu_category.dart';
import '../../domain/repositories/menu_repository.dart';

class MenuCategoriesScreen extends StatefulWidget {
  const MenuCategoriesScreen({super.key});

  @override
  State<MenuCategoriesScreen> createState() => _MenuCategoriesScreenState();
}

class _MenuCategoriesScreenState extends State<MenuCategoriesScreen> {
  final MenuRepository _repository = getIt<MenuRepository>();
  List<MenuCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final list = await _repository.getCategories();
    if (mounted) {
      setState(() {
        _categories = List.from(list);
        _isLoading = false;
      });
    }
  }

  void _showAddCategorySheet() {
    final arController = TextEditingController();
    final enController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppDimens.paddingLg,
          left: AppDimens.paddingLg,
          right: AppDimens.paddingLg,
          top: AppDimens.paddingLg,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'إضافة فئة جديدة',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.paddingMd),
            TextField(
              controller: arController,
              decoration: const InputDecoration(
                labelText: 'اسم الفئة بالعربية *',
                hintText: 'مثال: بيتزا وفطائر',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),
            TextField(
              controller: enController,
              decoration: const InputDecoration(
                labelText: 'اسم الفئة بالإنجليزية',
                hintText: 'e.g. Pizza & Pies',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimens.paddingLg),
            ElevatedButton(
              onPressed: () async {
                if (arController.text.trim().isEmpty) return;
                final newCat = MenuCategory(
                  id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
                  nameAr: arController.text.trim(),
                  nameEn: enController.text.trim().isEmpty
                      ? arController.text.trim()
                      : enController.text.trim(),
                  itemsCount: 0,
                  sortOrder: _categories.length + 1,
                );
                await _repository.addCategory(newCat);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadCategories();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تمت إضافة الفئة بنجاح وتحديث نقاط البيع'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                ),
              ),
              child: const Text('حفظ الفئة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _categories.fold(0, (sum, cat) => sum + cat.itemsCount);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('إدارة فئات القائمة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'فئة جديدة',
            onPressed: _showAddCategorySheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.paddingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title and Add button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تصنيفات المنيو المركزي',
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'تتحكم بترتيب ظهور الأصناف على نقاط البيع (POS)',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _showAddCategorySheet,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('فئة جديدة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusXl,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.paddingMd),

                  // Quick Stats Bento Strip
                  Row(
                    children: [
                      Expanded(
                        child: _buildBentoCard(
                          title: '${_categories.length}',
                          subtitle: 'فئات رئيسية',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildBentoCard(
                          title: '$totalItems',
                          subtitle: 'صنف مرتبط',
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildBentoCard(
                          icon: Icons.store,
                          subtitle: 'كافة الفروع',
                          color: AppColors.tertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.paddingMd),

                  // Reorder Guidance Hint
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.drag_indicator,
                              size: 18,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'اسحب لإعادة الترتيب التلقائي على أجهزة الكاشير',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            _repository.updateCategoryOrder(_categories);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تم حفظ وتحديث الترتيب على الكاشير',
                                ),
                              ),
                            );
                          },
                          child: Text(
                            'حفظ الترتيب',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.tertiary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimens.paddingMd),

                  // Reorderable list
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _categories.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _categories.removeAt(oldIndex);
                        _categories.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      return Container(
                        key: ValueKey(cat.id),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(AppDimens.paddingMd),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusXl,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.drag_indicator,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: AppDimens.paddingSm),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryFixed,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: AppTypography.labelMd.copyWith(
                                  color: AppColors.onPrimaryFixed,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimens.paddingMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        cat.nameAr,
                                        style: AppTypography.labelMd.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              AppColors.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            AppDimens.radiusFull,
                                          ),
                                        ),
                                        child: Text(
                                          cat.nameEn,
                                          style: AppTypography.labelSm.copyWith(
                                            fontSize: 10,
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${cat.itemsCount} صنف مرتبط بالمنيو',
                                    style: AppTypography.bodySm.copyWith(
                                      color: AppColors.secondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.secondary,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBentoCard({
    String? title,
    IconData? icon,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: Column(
        children: [
          if (title != null)
            Text(
              title,
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            )
          else if (icon != null)
            Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}
