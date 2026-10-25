import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/price_change_request.dart';
import '../../domain/repositories/pricing_repository.dart';

class PriceChangeRequestsScreen extends StatefulWidget {
  const PriceChangeRequestsScreen({super.key});

  @override
  State<PriceChangeRequestsScreen> createState() =>
      _PriceChangeRequestsScreenState();
}

class _PriceChangeRequestsScreenState extends State<PriceChangeRequestsScreen> {
  final PricingRepository _repository = getIt<PricingRepository>();
  List<PriceChangeRequest> _allRequests = [];
  String _activeTab = 'all'; // all, pending, approved, rejected
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final list = await _repository.getPriceChangeRequests();
    if (mounted) {
      setState(() {
        _allRequests = list;
        _isLoading = false;
      });
    }
  }

  List<PriceChangeRequest> get _filteredRequests {
    if (_activeTab == 'pending') {
      return _allRequests
          .where((r) => r.status == PriceRequestStatus.pending)
          .toList();
    } else if (_activeTab == 'approved') {
      return _allRequests
          .where((r) => r.status == PriceRequestStatus.approved)
          .toList();
    } else if (_activeTab == 'rejected') {
      return _allRequests
          .where((r) => r.status == PriceRequestStatus.rejected)
          .toList();
    }
    return _allRequests;
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _allRequests
        .where((r) => r.status == PriceRequestStatus.pending)
        .length;
    final approvedCount = _allRequests
        .where((r) => r.status == PriceRequestStatus.approved)
        .length;
    final rejectedCount = _allRequests
        .where((r) => r.status == PriceRequestStatus.rejected)
        .length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('طلبات تعديل الأسعار')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadRequests,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppDimens.paddingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Policy Notice Banner
                    Container(
                      padding: const EdgeInsets.all(AppDimens.paddingMd),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_user,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: AppDimens.paddingSm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'سياسة تسعير RMS المركزية',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.onSurface,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'لا يملك مدير الفرع صلاحية التعديل المباشر على أسعار القائمة. التعديل يسري تلقائياً على نقاط البيع (POS) بعد اعتماد المدير التنفيذي فقط.',
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.paddingMd),

                    // Quick Stats Strip
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'قيد الانتظار',
                            '$pendingCount طلبات',
                            AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'معتمدة هذا الشهر',
                            '$approvedCount صنف',
                            AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'متوسط الزيادة',
                            '+14%',
                            AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.paddingMd),

                    // Segmented Filter Tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTabButton(
                            'all',
                            'الكل (${_allRequests.length})',
                          ),
                          _buildTabButton(
                            'pending',
                            'قيد الانتظار ($pendingCount)',
                          ),
                          _buildTabButton(
                            'approved',
                            'معتمدة ($approvedCount)',
                          ),
                          _buildTabButton(
                            'rejected',
                            'مرفوضة ($rejectedCount)',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.paddingMd),

                    // Request cards
                    if (_filteredRequests.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppDimens.paddingXl),
                        alignment: Alignment.center,
                        child: Text(
                          'لا توجد طلبات تسعير مطابقة',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.secondary,
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredRequests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final req = _filteredRequests[index];
                          return _buildPriceRequestCard(req);
                        },
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
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
            label,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.secondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.labelMd.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabId, String label) {
    final isSelected = _activeTab == tabId;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _activeTab = tabId),
        selectedColor: AppColors.onSurface,
        backgroundColor: AppColors.surfaceContainer,
        labelStyle: AppTypography.labelSm.copyWith(
          color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          side: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildPriceRequestCard(PriceChangeRequest req) {
    Color statusBg;
    Color statusText;
    switch (req.status) {
      case PriceRequestStatus.pending:
        statusBg = AppColors.errorContainer;
        statusText = AppColors.onErrorContainer;
        break;
      case PriceRequestStatus.approved:
        statusBg = const Color(0xFFEAF5EA);
        statusText = const Color(0xFF2E8B2E);
        break;
      case PriceRequestStatus.rejected:
        statusBg = AppColors.surfaceContainerHighest;
        statusText = AppColors.secondary;
        break;
    }

    return InkWell(
      onTap: () async {
        await context.push('/pricing/requests/${req.id}');
        _loadRequests();
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusSm,
                          ),
                        ),
                        child: Text(
                          req.requestNumber,
                          style: AppTypography.labelSm.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          req.branchName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.secondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.paddingSm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                  ),
                  child: Text(
                    req.status.labelArabic,
                    style: AppTypography.labelSm.copyWith(
                      color: statusText,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  req.itemNameAr,
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  req.categoryName,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.secondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppDimens.paddingSm),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF5EA),
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                    child: Text(
                      '+${req.difference.toStringAsFixed(0)} ج.م (+${req.percentageChange.toStringAsFixed(1)}%)',
                      style: AppTypography.labelSm.copyWith(
                        color: const Color(0xFF2E8B2E),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Price comparison bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: AppDimens.paddingSm,
                runSpacing: AppDimens.paddingSm,
                children: [
                  Row(
                    children: [
                      Text(
                        'الحالي: ',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                      Text(
                        '${req.currentPrice.toStringAsFixed(2)} ج.م',
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.arrow_back,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  Row(
                    children: [
                      Text(
                        'المقترح: ',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                      Text(
                        '${req.proposedPrice.toStringAsFixed(2)} ج.م',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'مقدم الطلب: ${req.requestedByName}',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.secondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: AppColors.secondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
