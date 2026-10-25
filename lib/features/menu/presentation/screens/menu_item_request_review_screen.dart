import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/entities/menu_item_request.dart';
import '../../domain/repositories/menu_repository.dart';

class MenuItemRequestReviewScreen extends StatefulWidget {
  final String requestId;

  const MenuItemRequestReviewScreen({super.key, required this.requestId});

  @override
  State<MenuItemRequestReviewScreen> createState() => _MenuItemRequestReviewScreenState();
}

class _MenuItemRequestReviewScreenState extends State<MenuItemRequestReviewScreen> {
  final MenuRepository _repository = getIt<MenuRepository>();
  MenuItemRequest? _request;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  Future<void> _loadRequest() async {
    setState(() => _isLoading = true);
    final req = await _repository.getMenuItemRequestById(widget.requestId);
    if (mounted) {
      setState(() {
        _request = req;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDecision(bool isApproved) async {
    setState(() => _isSubmitting = true);

    await _repository.reviewMenuItemRequest(
      requestId: widget.requestId,
      isApproved: isApproved,
    );

    if (isApproved && _request != null) {
      // Automatically add as a new menu item
      final newItem = MenuItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}',
        sku: 'REQ-${_request!.id}',
        barcode: '6223001849${DateTime.now().millisecond}',
        nameAr: _request!.itemNameAr,
        nameEn: _request!.itemNameEn,
        categoryId: 'cat_burgers',
        categoryName: _request!.categoryName,
        price: _request!.proposedPrice,
        cost: _request!.estimatedCost,
        branches: [_request!.branchName],
      );
      await _repository.saveMenuItem(newItem);
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isApproved
                ? 'تم قبول الطلب وإدراج الصنف بالقائمة المركزية فوراً'
                : 'تم رفض طلب الصنف وتسجيل السبب التشغيلي',
          ),
          backgroundColor: isApproved ? const Color(0xFF2E8B2E) : AppColors.error,
        ),
      );
      context.pop();
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

    if (_request == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: const Text('مراجعة طلب الصنف')),
        body: const Center(child: Text('الطلب غير موجود')),
      );
    }

    final req = _request!;
    final profit = req.proposedPrice - req.estimatedCost;
    final marginPercent = (profit / req.proposedPrice) * 100;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('مراجعة طلب الصنف'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Authority Context Notice
            Container(
              padding: const EdgeInsets.all(AppDimens.paddingMd),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimens.radiusXl),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'صلاحية اعتماد حصري: الإدارة التنفيذية',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: Text(
                      req.requestNumber,
                      style: AppTypography.labelSm.copyWith(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Request metadata card
            Container(
              padding: const EdgeInsets.all(AppDimens.paddingLg),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'بيانات الطلب التشغيلي',
                        style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                        ),
                        child: Text(
                          req.status.labelArabic,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onErrorContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetaField('الفرع ومقدم الطلب', '${req.requestedByName}\n(${req.branchName})'),
                      ),
                      Expanded(
                        child: _buildMetaField('تاريخ التقديم', '16 أبريل 2024 • 11:30 ص'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Proposed item details
            Container(
              padding: const EdgeInsets.all(AppDimens.paddingLg),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: Text(
                      req.categoryName,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSecondaryFixedVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    req.itemNameAr,
                    style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    req.itemNameEn,
                    style: AppTypography.bodySm.copyWith(color: AppColors.secondary),
                  ),
                  const SizedBox(height: AppDimens.paddingMd),

                  // Pricing matrix
                  Row(
                    children: [
                      Expanded(
                        child: _buildPriceBox('السعر المقترح', '${req.proposedPrice.toStringAsFixed(2)} ج.م', AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPriceBox('التكلفة المقدرة', '${req.estimatedCost.toStringAsFixed(2)} ج.م', AppColors.secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'هامش الربح المتوقع',
                          style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
                        ),
                        Text(
                          '+${marginPercent.toStringAsFixed(1)}% (${profit.toStringAsFixed(2)} ج.م)',
                          style: AppTypography.labelMd.copyWith(
                            color: const Color(0xFF2E8B2E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimens.paddingMd),

                  // Operational Reason
                  Text(
                    'مبررات الطلب من مدير الفرع:',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                    child: Text(
                      req.reason.isEmpty ? 'لا توجد ملاحظات إضافية' : req.reason,
                      style: AppTypography.bodySm.copyWith(color: AppColors.onSurface),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingLg),

            // Decision Buttons
            if (req.status == MenuItemRequestStatus.pending) ...[
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : () => _handleDecision(true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('قبول وإدراج الصنف بالقائمة المركزية فوراً'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E8B2E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : () => _handleDecision(false),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('رفض طلب الصنف'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                  ),
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(AppDimens.paddingMd),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                ),
                child: Text(
                  'تم اتخاذ القرار مسبقاً: ${req.status.labelArabic}',
                  style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaField(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPriceBox(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
          const SizedBox(height: 2),
          Text(value, style: AppTypography.labelMd.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
