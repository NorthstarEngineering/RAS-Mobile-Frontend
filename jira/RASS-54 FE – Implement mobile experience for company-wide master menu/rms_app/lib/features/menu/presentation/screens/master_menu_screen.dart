import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/routing/navigation_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/menu_category.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/repositories/menu_repository.dart';

class MasterMenuScreen extends StatefulWidget {
  const MasterMenuScreen({super.key});

  @override
  State<MasterMenuScreen> createState() => _MasterMenuScreenState();
}

class _MasterMenuScreenState extends State<MasterMenuScreen> {
  final MenuRepository _repository = getIt<MenuRepository>();
  List<MenuItem> _allItems = [];
  List<MenuCategory> _categories = [];
  String _selectedCategoryId = 'all';
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await _repository.getMenuItems();
      final categories = await _repository.getCategories();
      if (mounted) {
        setState(() {
          _allItems = items;
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحميل بيانات المنيو من الخادم: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  List<MenuItem> get _filteredItems {
    return _allItems.where((item) {
      final matchesCategory =
          _selectedCategoryId == 'all' ||
          item.categoryId == _selectedCategoryId;
      final matchesSearch =
          _searchQuery.isEmpty ||
          item.nameAr.contains(_searchQuery) ||
          item.nameEn.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.sku.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.barcode.contains(_searchQuery);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _allItems.where((i) => i.isActive).length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.safePop(fallback: '/home');
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => context.safePop(fallback: '/home'),
          ),
          title: const Text('القائمة الرئيسية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.inbox_outlined),
            tooltip: 'طلبات الأصناف',
            onPressed: () async {
              await context.push('/menu/requests');
              _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'إدارة الفئات',
            onPressed: () async {
              await context.push('/menu/categories');
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.paddingMd,
                  vertical: AppDimens.paddingSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header action row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryContainer,
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusFull,
                                  ),
                                ),
                                child: Text(
                                  'قائمة موحدة للشركة',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.onSecondaryFixedVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'أصناف المطعم المركزية',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.headlineSm.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await context.push('/menu/create');
                            _loadData();
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('إضافة صنف'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusXl,
                              ),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.paddingMd),

                    // Metrics Strip
                    Container(
                      padding: const EdgeInsets.all(AppDimens.paddingMd),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildMetricItem(
                                    'الإجمالي',
                                    '${_allItems.length} صنف',
                                  ),
                                ),
                                Container(
                                  height: 32,
                                  width: 1,
                                  color: AppColors.surfaceContainerHigh,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                ),
                                Expanded(
                                  child: _buildMetricItem(
                                    'النشط',
                                    '$activeCount نشط',
                                    isPositive: true,
                                  ),
                                ),
                                Container(
                                  height: 32,
                                  width: 1,
                                  color: AppColors.surfaceContainerHigh,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                ),
                                Expanded(
                                  child: _buildMetricItem(
                                    'الأقسام',
                                    '${_categories.length} أقسام',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppDimens.paddingXs),
                          TextButton.icon(
                            onPressed: () => context.push('/menu/categories'),
                            icon: const Icon(Icons.arrow_back, size: 14),
                            label: const Text('الفئات'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.paddingMd),

                    // Search input
                    Container(
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
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'بحث بالاسم، الكود، أو الباركود...',
                          hintStyle: AppTypography.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.onSurfaceVariant,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.qr_code_scanner,
                              color: AppColors.primary,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'ماسح الباركود متصل وجاهز للعمل',
                                  ),
                                ),
                              );
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.paddingMd,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimens.paddingMd),

                    // Category filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'الكل (${_allItems.length})'),
                          ..._categories.map(
                            (cat) => _buildFilterChip(
                              cat.id,
                              '${cat.nameAr} (${cat.itemsCount})',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.paddingMd),

                    // Items list
                    if (_filteredItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppDimens.paddingXl),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            const Icon(
                              Icons.restaurant_menu,
                              size: 48,
                              color: AppColors.outlineVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'لا توجد أصناف مطابقة للبحث أو الفئة',
                              style: AppTypography.bodyMd.copyWith(
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          return _buildMenuItemCard(item);
                        },
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    ),
  );
  }

  Widget _buildMetricItem(
    String label,
    String value, {
    bool isPositive = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            if (isPositive)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(left: 4),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String id, String label) {
    final isSelected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedCategoryId = id),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surfaceContainerLowest,
        labelStyle: AppTypography.labelSm.copyWith(
          color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          side: BorderSide(
            color: isSelected
                ? AppColors.primary
                : AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItemCard(MenuItem item) {
    return InkWell(
      onTap: () async {
        await context.push('/menu/${item.id}');
        _loadData();
      },
      borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
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
            // Thumbnail avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              ),
              child: const Icon(
                Icons.fastfood_outlined,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: AppDimens.paddingMd),

            // Item Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.nameAr,
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusSm,
                          ),
                        ),
                        child: Text(
                          item.sku,
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: AppColors.onSecondaryFixedVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.categoryName,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.secondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.price.toStringAsFixed(2)} ج.م',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Status chip & Arrow
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: item.isActive
                        ? const Color(0xFFEAF5EA)
                        : AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                  ),
                  child: Text(
                    item.isActive ? 'نشط' : 'معطل',
                    style: AppTypography.labelSm.copyWith(
                      color: item.isActive
                          ? const Color(0xFF2E8B2E)
                          : AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
