import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/routing/navigation_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/domain/entities/user_session.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/entities/menu_category.dart';
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
  List<MenuCategory> _categories = [];
  UserSession? _session;
  String _activeTab = 'all'; // all, pending, approved, rejected
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repository.getMenuItemRequests();
      List<MenuCategory> cats = [];
      try {
        cats = await _repository.getCategories();
      } catch (_) {}

      UserSession? session;
      if (getIt.isRegistered<AuthRepository>()) {
        try {
          session = await getIt<AuthRepository>().getCurrentSession();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _allRequests = list;
          _categories = cats;
          _session = session;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحميل طلبات الأصناف من الخادم: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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

  void _showCreateRequestSheet() {
    final nameArController = TextEditingController();
    final nameEnController = TextEditingController();
    final priceController = TextEditingController();
    final costController = TextEditingController();
    final reasonController = TextEditingController();
    String? selectedCategoryId = _categories.isNotEmpty ? _categories.first.id : null;
    final requesterName = _session?.name ?? 'المستخدم المسجل';
    final branchName = _session?.branchName ?? 'الفرع المخصص';
    final branchId = _session?.branchId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تقديم طلب صنف جديد',
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
                const SizedBox(height: AppDimens.paddingSm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.badge_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'مقدم الطلب: $requesterName • الفرع: $branchName',
                          style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.paddingMd),
                TextField(
                  controller: nameArController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الصنف بالعربية *',
                    hintText: 'مثال: ساندوتش فاهيتا لحم',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppDimens.paddingMd),
                TextField(
                  controller: nameEnController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الصنف بالإنجليزية',
                    hintText: 'e.g. Beef Fajita Sandwich',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppDimens.paddingMd),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'فئة الصنف المعتمدة *',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.nameAr),
                  )).toList(),
                  onChanged: (val) {
                    setModalState(() => selectedCategoryId = val);
                  },
                ),
                const SizedBox(height: AppDimens.paddingMd),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'السعر المقترح (ج.م) *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: costController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'التكلفة المقدرة (ج.م)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.paddingMd),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'مبررات الطلب التشغيلي',
                    hintText: 'مثال: إقبال ملحوظ من زبائن الفرع وتوفر المواد الخام',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppDimens.paddingLg),
                ElevatedButton(
                  onPressed: () async {
                    if (nameArController.text.trim().isEmpty) return;
                    if (selectedCategoryId == null && _categories.isNotEmpty) {
                      selectedCategoryId = _categories.first.id;
                    }
                    if (selectedCategoryId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يرجى اختيار فئة معتمدة للصنف'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }
                    final selectedCat = _categories.firstWhere(
                      (c) => c.id == selectedCategoryId,
                      orElse: () => _categories.first,
                    );
                    final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                    final cost = double.tryParse(costController.text.trim()) ?? 0.0;
                    if (price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يرجى إدخال سعر مقترح صالح أكبر من صفر'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }

                    final req = MenuItemRequest(
                      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
                      requestNumber: 'REQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                      itemNameAr: nameArController.text.trim(),
                      itemNameEn: nameEnController.text.trim(),
                      categoryId: selectedCat.id,
                      categoryName: selectedCat.nameAr,
                      proposedPrice: price,
                      estimatedCost: cost,
                      branchId: branchId,
                      branchName: branchName,
                      requestedByName: requesterName,
                      requestDate: DateTime.now(),
                      status: MenuItemRequestStatus.pending,
                      reason: reasonController.text.trim(),
                    );
                    try {
                      await _repository.createMenuItemRequest(req);
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadRequests();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم إرسال طلب الصنف بنجاح وبانتظار اعتماد الإدارة'),
                            backgroundColor: Color(0xFF2E8B2E),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('فشل إرسال طلب الصنف: $e'),
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
                  child: const Text('إرسال الطلب للاعتماد'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
          title: const Text('طلبات أصناف القائمة'),
        ),
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
                        Expanded(
                          child: Column(
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
                        ),
                        const SizedBox(width: AppDimens.paddingSm),
                        Flexible(
                          child: ElevatedButton.icon(
                            onPressed: _showCreateRequestSheet,
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: AppDimens.paddingSm,
              spacing: AppDimens.paddingMd,
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
                Expanded(
                  child: Text(
                    'مقدم الطلب: ${req.requestedByName}',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
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
