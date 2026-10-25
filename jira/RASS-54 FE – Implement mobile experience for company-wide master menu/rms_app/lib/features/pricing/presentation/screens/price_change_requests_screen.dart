import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/routing/navigation_utils.dart';
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
    try {
      final list = await _repository.getPriceChangeRequests();
      if (mounted) {
        setState(() {
          _allRequests = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final msg = e.toString().replaceFirst(RegExp(r'^(Exception|NetworkException):\s*'), '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحميل طلبات تغيير الأسعار: $msg'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
    final avgIncrease = _allRequests.isEmpty
        ? 0.0
        : _allRequests
                .map((r) => r.percentageChange)
                .reduce((a, b) => a + b) /
            _allRequests.length;
    final avgIncreaseStr = avgIncrease > 0
        ? '+${avgIncrease.toStringAsFixed(1)}%'
        : '${avgIncrease.toStringAsFixed(1)}%';

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
          title: const Text('طلبات تعديل الأسعار'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'طلب تعديل سعر جديد',
            onPressed: () => _showCreateRequestDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('طلب تعديل سعر'),
        onPressed: () => _showCreateRequestDialog(context),
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
                            avgIncreaseStr,
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

  Future<void> _showCreateRequestDialog(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    List<Map<String, dynamic>> menuItems = [];
    try {
      menuItems = await _repository.getActiveMenuItems();
    } catch (_) {
      menuItems = [];
    }

    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    String? selectedItemId = menuItems.isNotEmpty ? menuItems.first['id']?.toString() : null;
    final proposedPriceCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final effectiveDateCtrl = TextEditingController(
      text: DateTime.now().add(const Duration(days: 14)).toIso8601String().substring(0, 10),
    );
    bool isSubmitting = false;

    double? currentPrice = menuItems.isNotEmpty
        ? (menuItems.first['price'] as num?)?.toDouble()
        : null;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusXl),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppDimens.paddingSm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.price_change_outlined, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: AppDimens.paddingSm),
                  const Text('تقديم طلب تعديل سعر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Item Selector
                        if (menuItems.isNotEmpty) ...[
                          Text('اختر الصنف المراد تعديله', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            initialValue: selectedItemId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: menuItems.map((item) {
                              final name = item['nameAr'] ?? item['nameEn'] ?? item['id'];
                              final price = item['price'] != null ? '${item['price']} ج.م' : '';
                              return DropdownMenuItem<String>(
                                value: item['id']?.toString(),
                                child: Text('$name ($price)', overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                selectedItemId = val;
                                final match = menuItems.firstWhere(
                                  (m) => m['id']?.toString() == val,
                                  orElse: () => {},
                                );
                                currentPrice = (match['price'] as num?)?.toDouble();
                              });
                            },
                            validator: (val) => val == null || val.isEmpty ? 'يرجى اختيار صنف' : null,
                          ),
                        ] else ...[
                          Text('معرف الصنف (Item ID)', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                          const SizedBox(height: 4),
                          TextFormField(
                            initialValue: selectedItemId ?? 'item_1',
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                                borderSide: BorderSide.none,
                              ),
                              hintText: 'e.g. item_1',
                            ),
                            onChanged: (val) => selectedItemId = val.trim(),
                            validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال معرف الصنف' : null,
                          ),
                        ],
                        const SizedBox(height: AppDimens.paddingMd),

                        // Current Price indication
                        if (currentPrice != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('السعر الحالي المعتمد:', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                                Text('${currentPrice!.toStringAsFixed(2)} ج.م', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppDimens.paddingMd),
                        ],

                        // Proposed Price Input
                        Text('السعر المقترح الجديد (ج.م)', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: proposedPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                              borderSide: BorderSide.none,
                            ),
                            hintText: '0.00',
                            suffixText: 'ج.م',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'يرجى إدخال السعر المقترح';
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed <= 0) return 'يرجى إدخال رقم صحيح وموجب';
                            if (currentPrice != null && (parsed - currentPrice!).abs() < 0.005) {
                              return 'السعر المقترح يجب أن يختلف عن السعر الحالي';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimens.paddingMd),

                        // Reason Input
                        Text('سبب ومبررات طلب التعديل', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: reasonCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                              borderSide: BorderSide.none,
                            ),
                            hintText: 'مثال: ارتفاع تكلفة المواد الخام...',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'يرجى ذكر سبب طلب التعديل';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimens.paddingMd),

                        // Effective Date Input
                        Text('تاريخ السريان المقترح (YYYY-MM-DD)', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: effectiveDateCtrl,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.calendar_today, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final itemId = selectedItemId;
                          if (itemId == null || itemId.isEmpty) return;
                          final proposedPrice = double.parse(proposedPriceCtrl.text.trim());
                          final reason = reasonCtrl.text.trim();
                          final effDate = DateTime.tryParse(effectiveDateCtrl.text.trim());

                          if (currentPrice != null && (proposedPrice - currentPrice!).abs() < 0.005) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('السعر المقترح يجب أن يختلف عن السعر الحالي'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            await _repository.createPriceChangeRequest(
                              itemId: itemId,
                              proposedPrice: proposedPrice,
                              reason: reason,
                              currentPrice: currentPrice,
                              effectiveDate: effDate,
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('تم تقديم طلب تعديل السعر بنجاح'),
                                  backgroundColor: Color(0xFF2E8B2E),
                                ),
                              );
                              _loadRequests();
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              final msg = e.toString().replaceFirst(RegExp(r'^(Exception|NetworkException):\s*'), '');
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text('فشل تقديم طلب تعديل السعر: $msg'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('تقديم الطلب'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
