import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/repositories/menu_repository.dart';

class MenuItemDetailsScreen extends StatefulWidget {
  final String itemId;

  const MenuItemDetailsScreen({super.key, required this.itemId});

  @override
  State<MenuItemDetailsScreen> createState() => _MenuItemDetailsScreenState();
}

class _MenuItemDetailsScreenState extends State<MenuItemDetailsScreen> {
  final MenuRepository _repository = getIt<MenuRepository>();
  MenuItem? _item;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  Future<void> _loadItem() async {
    setState(() => _isLoading = true);
    try {
      final item = await _repository.getMenuItemById(widget.itemId);
      if (mounted) {
        setState(() {
          _item = item;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحميل بيانات الصنف من الخادم: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_item == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: const Text('تفاصيل الصنف')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('لم يتم العثور على الصنف المطلوب'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('رجوع للقائمة'),
              ),
            ],
          ),
        ),
      );
    }

    final item = _item!;
    final profit = item.price - item.cost;
    final marginPercent = (profit / item.price) * 100;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(item.nameAr),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_toggle_off),
            tooltip: 'سجل الأسعار',
            onPressed: () => context.push('/pricing/history/${item.id}'),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'تعديل الصنف',
            onPressed: () async {
              await context.push('/menu/edit/${item.id}');
              _loadItem();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'حذف الصنف',
            onPressed: () => _confirmAndDeleteItem(item),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Context Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'صنف معتمد بالقائمة الرئيسية المركزية',
                        style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: Text(
                      '#MNU-${item.id}',
                      style: AppTypography.labelSm.copyWith(
                        fontFamily: 'monospace',
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Hero Summary Card
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
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                        ),
                        child: const Icon(
                          Icons.lunch_dining,
                          size: 38,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppDimens.paddingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.nameAr,
                              style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              item.nameEn,
                              style: AppTypography.bodySm.copyWith(color: AppColors.secondary),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryContainer,
                                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                                  ),
                                  child: Text(
                                    item.categoryName,
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.onSecondaryFixedVariant,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: item.isActive
                                        ? const Color(0xFFEAF5EA)
                                        : AppColors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: item.isActive
                                              ? const Color(0xFF2E8B2E)
                                              : AppColors.secondary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getStatusLabel(item),
                                        style: AppTypography.labelSm.copyWith(
                                          color: item.isActive
                                              ? const Color(0xFF2E8B2E)
                                              : AppColors.secondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.paddingMd),
                  // SKU & Barcode
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppDimens.paddingSm),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'رمز الصنف (SKU)',
                                style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.sku,
                                style: AppTypography.labelMd.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppDimens.paddingSm),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الباركود المسجل',
                                style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.barcode,
                                style: AppTypography.labelMd.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Financial & Pricing Matrix
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
                        'هيكل التسعير والربحية',
                        style: AppTypography.headlineSm.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => context.push('/pricing/history/${item.id}'),
                        icon: const Icon(Icons.trending_up, size: 16),
                        label: const Text('سجل الأسعار'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.paddingSm),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPriceBox(
                          title: 'سعر البيع',
                          amount: '${item.price.toStringAsFixed(2)} ج.م',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPriceBox(
                          title: 'تكلفة الإنتاج',
                          amount: '${item.cost.toStringAsFixed(2)} ج.م',
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'هامش الربح الإجمالي',
                              style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
                            ),
                            Text(
                              '${profit.toStringAsFixed(2)} ج.م',
                              style: AppTypography.labelMd.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2E8B2E),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5EA),
                            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                          ),
                          child: Text(
                            '+${marginPercent.toStringAsFixed(1)}%',
                            style: AppTypography.labelMd.copyWith(
                              color: const Color(0xFF2E8B2E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Operational & Kitchen Setup
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
                    'البيانات التشغيلية ومحطات الطهي',
                    style: AppTypography.headlineSm.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimens.paddingSm),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.soup_kitchen_outlined, color: AppColors.primary),
                    title: const Text('محطة الطهي (KDS)'),
                    subtitle: Text(item.kitchenStation),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.storefront_outlined, color: AppColors.primary),
                    title: const Text('الفروع المتاح بها'),
                    subtitle: Text(item.branches.join(', ')),
                  ),
                  if (item.allergens.isNotEmpty) ...[
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                      title: const Text('مسببات الحساسية'),
                      subtitle: Text(item.allergens.join(' • ')),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingLg),

            // Action Buttons
            ElevatedButton.icon(
              onPressed: () async {
                await context.push('/menu/edit/${item.id}');
                _loadItem();
              },
              icon: const Icon(Icons.edit),
              label: const Text('تعديل بيانات الصنف'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.push('/pricing/history/${item.id}'),
              icon: const Icon(Icons.price_change_outlined),
              label: const Text('عرض السجل المالي وتاريخ الأسعار'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onSurface,
                side: const BorderSide(color: AppColors.outlineVariant),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _confirmAndDeleteItem(item),
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              label: const Text('حذف الصنف من القائمة المركزية', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _getStatusLabel(MenuItem item) {
    if (!item.isActive) return 'معطل تشغيلياً';
    if (item.branches.isEmpty) return 'نشط تشغيلياً';
    if (item.branches.contains('كافة الفروع') || item.branches.contains('all')) {
      return 'نشط بكافة الفروع';
    }
    return 'نشط في: ${item.branches.join('، ')}';
  }

  Future<void> _confirmAndDeleteItem(MenuItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('تأكيد حذف الصنف'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف الصنف "${item.nameAr}" نهائياً من قائمة الطعام المركزية؟\n\nلا يمكن التراجع عن هذا الإجراء.',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _repository.deleteMenuItem(item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الصنف بنجاح من القائمة'),
              backgroundColor: Color(0xFF2E8B2E),
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذر حذف الصنف: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildPriceBox({
    required String title,
    required String amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: AppTypography.headlineSm.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
