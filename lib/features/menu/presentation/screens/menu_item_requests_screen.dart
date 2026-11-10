import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/menu_item_request.dart';
import '../../domain/repositories/menu_repository.dart';

class MenuItemRequestsScreen extends StatefulWidget {
  const MenuItemRequestsScreen({super.key});

  @override
  State<MenuItemRequestsScreen> createState() => _MenuItemRequestsScreenState();
}

class _MenuItemRequestsScreenState extends State<MenuItemRequestsScreen> {
  final MenuRepository _repository = getIt<MenuRepository>();
  List<MenuItemRequest> _allRequests = [];
  String _activeTab = 'all'; // all, pending, approved, rejected
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final list = await _repository.getMenuItemRequests();
    if (mounted) {
      setState(() {
        _allRequests = list;
        _isLoading = false;
      });
    }
  }

  List<MenuItemRequest> get _filteredRequests {
    if (_activeTab == 'pending') {
      return _allRequests
          .where((r) => r.status == MenuItemRequestStatus.pending)
          .toList();
    } else if (_activeTab == 'approved') {
      return _allRequests
          .where((r) => r.status == MenuItemRequestStatus.approved)
          .toList();
    } else if (_activeTab == 'rejected') {
      return _allRequests
          .where((r) => r.status == MenuItemRequestStatus.rejected)
          .toList();
    }
    return _allRequests;
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _allRequests
        .where((r) => r.status == MenuItemRequestStatus.pending)
        .length;
    final approvedCount = _allRequests
        .where((r) => r.status == MenuItemRequestStatus.approved)
        .length;
    final rejectedCount = _allRequests
        .where((r) => r.status == MenuItemRequestStatus.rejected)
        .length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('طلبات أصناف القائمة')),
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
                    // Header text & Action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'طلبات الفروع للأصناف',
                              style: AppTypography.headlineSm.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'تتطلب موافقة المدير التنفيذي قبل الإدراج',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'يتم تقديم طلب الصنف من حساب مدير الفرع',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('طلب جديد'),
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

                    // Operational Alert Notice
                    Container(
                      padding: const EdgeInsets.all(AppDimens.paddingMd),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusLg,
                              ),
                            ),
                            child: const Icon(
                              Icons.info,
                              color: AppColors.primary,
                              size: 20,
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
                                      'تنبيه تشغيلي مركزي',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.primary,
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
                                  'تقديم طلب الصنف من مدير الفرع لا ينشئه بالقائمة تلقائياً، الصنف يتطلب موافقة المدير التنفيذي ليصبح متاحاً للبيع فورياً.',
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

                    // Filter tabs
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
                            'قيد المراجعة ($pendingCount)',
                          ),
                          _buildTabButton('approved', 'مقبول ($approvedCount)'),
                          _buildTabButton('rejected', 'مرفوض ($rejectedCount)'),
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
                          'لا توجد طلبات في هذه الحالة',
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
                          return _buildRequestCard(req);
                        },
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
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

  Widget _buildRequestCard(MenuItemRequest req) {
    Color statusBg;
    Color statusText;
    switch (req.status) {
      case MenuItemRequestStatus.pending:
        statusBg = AppColors.errorContainer;
        statusText = AppColors.onErrorContainer;
        break;
      case MenuItemRequestStatus.approved:
        statusBg = const Color(0xFFEAF5EA);
        statusText = const Color(0xFF2E8B2E);
        break;
      case MenuItemRequestStatus.rejected:
        statusBg = AppColors.surfaceContainerHighest;
        statusText = AppColors.secondary;
        break;
    }

    return InkWell(
      onTap: () async {
        await context.push('/menu/requests/${req.id}');
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Text(
                    req.requestNumber,
                    style: AppTypography.labelSm.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
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
            Text(
              req.itemNameAr,
              style: AppTypography.labelMd.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              req.itemNameEn,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.secondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'السعر المقترح: ',
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
                Text(
                  req.branchName,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'مقدم الطلب: ${req.requestedByName}',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
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
