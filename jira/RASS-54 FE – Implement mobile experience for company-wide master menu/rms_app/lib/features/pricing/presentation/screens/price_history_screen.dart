import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/item_pricing_summary.dart';
import '../../domain/entities/price_history_entry.dart';
import '../../domain/repositories/pricing_repository.dart';

class PriceHistoryScreen extends StatefulWidget {
  final String itemId;

  const PriceHistoryScreen({super.key, required this.itemId});

  @override
  State<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends State<PriceHistoryScreen> {
  final PricingRepository _repository = getIt<PricingRepository>();
  List<PriceHistoryEntry> _history = [];
  ItemPricingSummary? _itemSummary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repository.getPriceHistory(widget.itemId),
        _repository.getItemPricingSummary(widget.itemId),
      ]);
      if (mounted) {
        setState(() {
          _history = results[0] as List<PriceHistoryEntry>;
          _itemSummary = results[1] as ItemPricingSummary?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final msg = e.toString().replaceFirst(RegExp(r'^(Exception|NetworkException):\s*'), '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحميل السجل التاريخي: $msg'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('السجل التاريخي للأسعار')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.paddingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Context Briefing
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.history_toggle_off,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'التتبع الزمني المالي لأسعار بيع الصنف',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppDimens.paddingSm),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusFull,
                            ),
                          ),
                          child: Text(
                            '${_history.length} قيود مسجلة',
                            textAlign: TextAlign.center,
                            style: AppTypography.labelSm.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.paddingMd),

                  // Item Summary Card
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
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusLg,
                                ),
                              ),
                              child: const Icon(
                                Icons.lunch_dining,
                                color: AppColors.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: AppDimens.paddingMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceContainer,
                                          borderRadius: BorderRadius.circular(
                                            AppDimens.radiusSm,
                                          ),
                                        ),
                                        child: Text(
                                          _itemSummary?.itemSku.isNotEmpty == true
                                              ? _itemSummary!.itemSku
                                              : widget.itemId,
                                          style: AppTypography.labelSm.copyWith(
                                            fontFamily: 'monospace',
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _itemSummary?.categoryName.isNotEmpty == true
                                              ? _itemSummary!.categoryName
                                              : 'عام',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.labelSm.copyWith(
                                            color: AppColors.secondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _itemSummary?.itemNameAr.isNotEmpty == true
                                        ? _itemSummary!.itemNameAr
                                        : 'صنف غير محدد',
                                    style: AppTypography.headlineSm.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_itemSummary?.itemNameEn.isNotEmpty == true)
                                    Text(
                                      _itemSummary!.itemNameEn,
                                      style: AppTypography.bodySm.copyWith(
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimens.paddingMd),

                        // Metrics Grid
                        Row(
                          children: [
                            // Current Active Box
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(
                                  AppDimens.paddingMd,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusLg,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'السعر الحالي',
                                          style: AppTypography.labelSm.copyWith(
                                            color: AppColors.secondary,
                                          ),
                                        ),
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(_itemSummary?.currentPrice ?? (_history.isNotEmpty ? _history.first.newPrice : 0.0)).toStringAsFixed(2)} ج.م',
                                      style: AppTypography.headlineSm.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _itemSummary?.effectiveSince != null
                                          ? 'سارٍ منذ ${_itemSummary!.effectiveSince}'
                                          : (_history.isNotEmpty
                                              ? 'سارٍ منذ ${_history.first.effectiveDate.year}-${_history.first.effectiveDate.month.toString().padLeft(2, '0')}-${_history.first.effectiveDate.day.toString().padLeft(2, '0')}'
                                              : 'السعر الأساسي المعتمد'),
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.secondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Upcoming Approved Box
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(
                                  AppDimens.paddingMd,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.tertiaryFixed.withValues(
                                    alpha: 0.4,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusLg,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _itemSummary?.upcomingStatus == 'approved'
                                                ? 'السعر القادم (معتمد)'
                                                : (_itemSummary?.upcomingPrice != null
                                                    ? 'السعر المقترح'
                                                    : 'السعر القادم'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.labelSm
                                                .copyWith(
                                                  color: AppColors.tertiary,
                                                ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.schedule_send,
                                          size: 16,
                                          color: AppColors.tertiary,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _itemSummary?.upcomingPrice != null
                                          ? '${_itemSummary!.upcomingPrice!.toStringAsFixed(2)} ج.م'
                                          : 'مستقر',
                                      style: AppTypography.headlineSm.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        color: AppColors.onTertiaryFixed,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _itemSummary?.upcomingEffectiveDate != null
                                          ? 'يبدأ ${_itemSummary!.upcomingEffectiveDate}'
                                          : (_itemSummary?.upcomingPrice != null
                                              ? 'قيد المراجعة'
                                              : 'لا توجد تعديلات قادمة'),
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.onTertiaryFixedVariant,
                                        fontSize: 10,
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
                  const SizedBox(height: AppDimens.paddingLg),

                  // Timeline Heading
                  Text(
                    'سجل التعديلات المعتمدة',
                    style: AppTypography.headlineSm.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimens.paddingSm),

                  // Timeline Entries
                  if (_history.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(AppDimens.paddingXl),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusXl,
                        ),
                      ),
                      child: Text(
                        'لا توجد سجلات تاريخية لتغيير سعر هذا الصنف بعد',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = _history[index];
                      return Container(
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: AppDimens.paddingSm,
                              runSpacing: AppDimens.paddingSm,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${entry.newPrice.toStringAsFixed(2)} ج.م',
                                      style: AppTypography.labelMd.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'بدلاً من ${entry.oldPrice.toStringAsFixed(2)} ج.م',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.secondary,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF5EA),
                                    borderRadius: BorderRadius.circular(
                                      AppDimens.radiusSm,
                                    ),
                                  ),
                                  child: Text(
                                    '+${entry.percentageChange.toStringAsFixed(1)}%',
                                    style: AppTypography.labelSm.copyWith(
                                      color: const Color(0xFF2E8B2E),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.reason,
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.onSurface,
                              ),
                            ),
                            const Divider(height: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الاعتماد: ${entry.approvedByName}',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.secondary,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  'تاريخ السريان: ${entry.effectiveDate.year}-${entry.effectiveDate.month.toString().padLeft(2, '0')}-${entry.effectiveDate.day.toString().padLeft(2, '0')}',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.secondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
