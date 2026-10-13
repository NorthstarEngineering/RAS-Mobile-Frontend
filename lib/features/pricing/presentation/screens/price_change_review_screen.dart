import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/price_change_request.dart';
import '../../domain/repositories/pricing_repository.dart';

class PriceChangeReviewScreen extends StatefulWidget {
  final String requestId;

  const PriceChangeReviewScreen({super.key, required this.requestId});

  @override
  State<PriceChangeReviewScreen> createState() => _PriceChangeReviewScreenState();
}

class _PriceChangeReviewScreenState extends State<PriceChangeReviewScreen> {
  final PricingRepository _repository = getIt<PricingRepository>();
  PriceChangeRequest? _request;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  Future<void> _loadRequest() async {
    setState(() => _isLoading = true);
    final req = await _repository.getPriceChangeRequestById(widget.requestId);
    if (mounted) {
      setState(() {
        _request = req;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDecision(bool isApproved) async {
    setState(() => _isSubmitting = true);

    await _repository.reviewPriceChangeRequest(
      requestId: widget.requestId,
      isApproved: isApproved,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isApproved
                ? 'تم اعتماد تعديل السعر وجدولة تطبيقه على أجهزة نقاط البيع (POS)'
                : 'تم رفض طلب تعديل السعر',
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
        appBar: AppBar(title: const Text('مراجعة طلب السعر')),
        body: const Center(child: Text('الطلب غير موجود')),
      );
    }

    final req = _request!;
    final currentMargin = ((req.currentPrice - req.cost) / req.currentPrice) * 100;
    final proposedMargin = ((req.proposedPrice - req.cost) / req.proposedPrice) * 100;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('مراجعة تعديل السعر'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_toggle_off),
            tooltip: 'السجل التاريخي',
            onPressed: () => context.push('/pricing/history/${req.itemId}'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Authority Banner
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
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'بوابة الاعتمادات التشغيلية المباشرة',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'اعتماد المدير التنفيذي',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Item Identity Card
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                            ),
                            child: Text(
                              req.requestNumber,
                              style: AppTypography.labelSm.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '16 أبريل 2024',
                            style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
                          ),
                        ],
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                        ),
                        child: const Icon(Icons.lunch_dining, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    req.itemNameAr,
                    style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Text(
                        req.itemSku,
                        style: AppTypography.labelSm.copyWith(
                          fontFamily: 'monospace',
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('•', style: TextStyle(color: AppColors.secondary)),
                      const SizedBox(width: 6),
                      Text(
                        req.categoryName,
                        style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.paddingMd),
                  // Requester Box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.badge_outlined, size: 20, color: AppColors.secondary),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'مقدم الطلب',
                                  style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 10),
                                ),
                                Text(
                                  req.requestedByName,
                                  style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                          ),
                          child: Text(
                            req.branchName,
                            style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Comparison Matrix Card
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
                  Text(
                    'مقارنة الأسعار وهوامش الربح',
                    style: AppTypography.headlineSm.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppDimens.paddingMd),
                  Row(
                    children: [
                      Expanded(
                        child: _buildComparisonCol(
                          'السعر الحالي',
                          '${req.currentPrice.toStringAsFixed(2)} ج.م',
                          'هامش: ${currentMargin.toStringAsFixed(1)}%',
                          AppColors.onSurface,
                        ),
                      ),
                      Container(
                        height: 50,
                        width: 1,
                        color: AppColors.surfaceContainerHigh,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      Expanded(
                        child: _buildComparisonCol(
                          'السعر المقترح',
                          '${req.proposedPrice.toStringAsFixed(2)} ج.م',
                          'هامش: ${proposedMargin.toStringAsFixed(1)}%',
                          AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.paddingMd),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF5EA),
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الفرق المتوقع في الإيراد لكل وجبة',
                          style: AppTypography.labelSm.copyWith(
                            color: const Color(0xFF2E8B2E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '+${req.difference.toStringAsFixed(2)} ج.م (+${req.percentageChange.toStringAsFixed(1)}%)',
                          style: AppTypography.labelMd.copyWith(
                            color: const Color(0xFF2E8B2E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Justification & Rollout
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
                  Text(
                    'مبررات التعديل والجدولة التشغيلية',
                    style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                    child: Text(
                      req.reason,
                      style: AppTypography.bodySm.copyWith(color: AppColors.onSurface),
                    ),
                  ),
                  const SizedBox(height: AppDimens.paddingMd),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'تاريخ السريان التلقائي على الكاشير: ',
                        style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
                      ),
                      Text(
                        '01 مايو 2024',
                        style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingLg),

            // Decision Buttons
            if (req.status == PriceRequestStatus.pending) ...[
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : () => _handleDecision(true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('اعتماد التعديل وتطبيقه على كافة الفروع'),
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
                label: const Text('رفض طلب تعديل السعر'),
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
                  'تم اعتماد القرار مسبقاً: ${req.status.labelArabic}',
                  style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCol(String title, String price, String margin, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
        const SizedBox(height: 2),
        Text(
          price,
          style: AppTypography.headlineSm.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(margin, style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 11)),
      ],
    );
  }
}
