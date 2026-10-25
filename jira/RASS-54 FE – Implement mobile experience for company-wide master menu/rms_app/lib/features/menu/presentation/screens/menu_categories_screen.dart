import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/routing/navigation_utils.dart';
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
    try {
      final list = await _repository.getCategories();
      if (mounted) {
        setState(() {
          _categories = List.from(list);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحميل الفئات من الخادم: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
                try {
                  await _repository.addCategory(newCat);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadCategories();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تمت إضافة الفئة بنجاح وتحديث نقاط البيع'),
                        backgroundColor: Color(0xFF2E8B2E),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('فشل إضافة الفئة: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
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

  void _showEditCategorySheet(MenuCategory cat) {
    final arController = TextEditingController(text: cat.nameAr);
    final enController = TextEditingController(text: cat.nameEn);

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
                  'تعديل الفئة',
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
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),
            TextField(
              controller: enController,
              decoration: const InputDecoration(
                labelText: 'اسم الفئة بالإنجليزية',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimens.paddingLg),
            ElevatedButton(
              onPressed: () async {
                if (arController.text.trim().isEmpty) return;
                final updated = MenuCategory(
                  id: cat.id,
                  nameAr: arController.text.trim(),
                  nameEn: enController.text.trim().isEmpty
                      ? arController.text.trim()
                      : enController.text.trim(),
                  itemsCount: cat.itemsCount,
                  sortOrder: cat.sortOrder,
                  isActive: cat.isActive,
                );
                try {
                  await _repository.updateCategory(updated);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadCategories();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تحديث الفئة بنجاح'),
                        backgroundColor: Color(0xFF2E8B2E),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('فشل تحديث الفئة: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
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
              child: const Text('حفظ التعديلات'),
            ),
            if (cat.itemsCount == 0) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  try {
                    await _repository.deleteCategory(cat.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadCategories();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم حذف الفئة بنجاح'),
                          backgroundColor: Color(0xFF2E8B2E),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('فشل حذف الفئة: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  'حذف الفئة',
                  style: AppTypography.labelMd.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _categories.fold(0, (sum, cat) => sum + cat.itemsCount);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.safePop(fallback: '/menu');
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => context.safePop(fallback: '/menu'),
          ),
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
                      Expanded(
                        child: Column(
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
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
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.drag_indicator,
                                size: 18,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'اسحب لإعادة الترتيب التلقائي على أجهزة الكاشير',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppDimens.paddingXs),
                        TextButton(
                          onPressed: () async {
                            try {
                              await _repository.updateCategoryOrder(_categories);
                              await _loadCategories();
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'تم حفظ وتحديث الترتيب على الكاشير',
                                  ),
                                  backgroundColor: Color(0xFF2E8B2E),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('فشل حفظ الترتيب: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
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
                                      Expanded(
                                        child: Text(
                                          cat.nameAr,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.labelMd.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 100,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors
                                                .surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(
                                              AppDimens.radiusFull,
                                            ),
                                          ),
                                          child: Text(
                                            cat.nameEn,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.labelSm
                                                .copyWith(
                                                  fontSize: 10,
                                                  color: AppColors
                                                      .onSurfaceVariant,
                                                ),
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
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: AppColors.secondary,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'تعديل الفئة',
                              onPressed: () => _showEditCategorySheet(cat),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
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
