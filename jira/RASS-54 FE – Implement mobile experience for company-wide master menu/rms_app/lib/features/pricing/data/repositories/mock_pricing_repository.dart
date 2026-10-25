import '../../domain/entities/item_pricing_summary.dart';
import '../../domain/entities/price_change_request.dart';
import '../../domain/entities/price_history_entry.dart';
import '../../domain/repositories/pricing_repository.dart';

class MockPricingRepository implements PricingRepository {
  final List<PriceChangeRequest> _requests = [
    PriceChangeRequest(
      id: 'pcr_1',
      requestNumber: 'PCR-2024-089',
      itemId: 'item_1',
      itemNameAr: 'برجر كلاسيك سينجل',
      itemNameEn: 'Classic Burger Single',
      itemSku: 'BURG-1024',
      categoryName: 'برجر وسندوتشات',
      currentPrice: 120.00,
      proposedPrice: 135.00,
      cost: 58.50,
      branchName: 'فرع وسط البلد #01',
      requestedByName: 'م. ألفاريز',
      requestDate: DateTime(2024, 4, 16),
      status: PriceRequestStatus.pending,
      reason: 'ارتفاع أسعار توريد اللحوم البقرية الطازجة بنسبة 15% من المورد الرئيسي.',
      effectiveDate: DateTime(2024, 5, 1),
    ),
    PriceChangeRequest(
      id: 'pcr_2',
      requestNumber: 'PCR-2024-088',
      itemId: 'item_2',
      itemNameAr: 'تشيكن تندر سوبريم 5 قطع',
      itemNameEn: 'Chicken Tenders Supreme (5 pcs)',
      itemSku: 'CHK-04',
      categoryName: 'وجبات رئيسية',
      currentPrice: 145.00,
      proposedPrice: 165.00,
      cost: 65.00,
      branchName: 'فرع المعادي #02',
      requestedByName: 'أحمد نبيل',
      requestDate: DateTime(2024, 4, 14),
      status: PriceRequestStatus.pending,
      reason: 'زيادة حجم القطع وتكلفة زيت القلي المعتمد.',
      effectiveDate: DateTime(2024, 5, 1),
    ),
    PriceChangeRequest(
      id: 'pcr_3',
      requestNumber: 'PCR-2024-087',
      itemId: 'item_3',
      itemNameAr: 'دبل سموكد بيكون برجر',
      itemNameEn: 'Double Smoked Bacon Burger',
      itemSku: 'BURG-2048',
      categoryName: 'برجر وسندوتشات',
      currentPrice: 180.00,
      proposedPrice: 195.00,
      cost: 92.00,
      branchName: 'فرع التجمع #03',
      requestedByName: 'سارة مراد',
      requestDate: DateTime(2024, 4, 10),
      status: PriceRequestStatus.approved,
      reason: 'تحديث تسعير فئة البريميوم بما يتناسب مع السوق.',
      effectiveDate: DateTime(2024, 4, 15),
    ),
    PriceChangeRequest(
      id: 'pcr_4',
      requestNumber: 'PCR-2024-086',
      itemId: 'item_4',
      itemNameAr: 'حلقات بصل كريسبي مع صوص رانش',
      itemNameEn: 'Crispy Onion Rings with Ranch',
      itemSku: 'APP-02',
      categoryName: 'مقبلات وصوصات',
      currentPrice: 55.00,
      proposedPrice: 65.00,
      cost: 22.00,
      branchName: 'فرع الشيخ زايد #04',
      requestedByName: 'كريم عادل',
      requestDate: DateTime(2024, 4, 8),
      status: PriceRequestStatus.approved,
      reason: 'إضافة صوص الرانش المزدوج للطبق.',
      effectiveDate: DateTime(2024, 4, 12),
    ),
    PriceChangeRequest(
      id: 'pcr_5',
      requestNumber: 'PCR-2024-085',
      itemId: 'item_5',
      itemNameAr: 'عصير برتقال طازج معصور',
      itemNameEn: 'Fresh Squeezed Orange Juice',
      itemSku: 'DRK-01',
      categoryName: 'مشروبات وبار',
      currentPrice: 40.00,
      proposedPrice: 55.00,
      cost: 18.00,
      branchName: 'فرع وسط البلد #01',
      requestedByName: 'م. ألفاريز',
      requestDate: DateTime(2024, 4, 5),
      status: PriceRequestStatus.rejected,
      reason: 'الزيادة مبالغ فيها مقارنة بأسعار السوق للمشروبات الطبيعية.',
    ),
  ];

  final Map<String, List<PriceHistoryEntry>> _history = {
    'item_1': [
      PriceHistoryEntry(
        id: 'hist_1',
        itemId: 'item_1',
        oldPrice: 105.00,
        newPrice: 120.00,
        effectiveDate: DateTime(2024, 3, 1),
        approvedByName: 'د. سارة فهمي (المدير التنفيذي)',
        reason: 'تعديل التكلفة التشغيلية للربع الأول 2024',
      ),
      PriceHistoryEntry(
        id: 'hist_2',
        itemId: 'item_1',
        oldPrice: 95.00,
        newPrice: 105.00,
        effectiveDate: DateTime(2023, 11, 1),
        approvedByName: 'د. سارة فهمي (المدير التنفيذي)',
        reason: 'تحديث تسعير قائمة الشتاء السنوية',
      ),
      PriceHistoryEntry(
        id: 'hist_3',
        itemId: 'item_1',
        oldPrice: 85.00,
        newPrice: 95.00,
        effectiveDate: DateTime(2023, 6, 1),
        approvedByName: 'م. أحمد خالد (مدير العمليات)',
        reason: 'افتتاح الفروع الجديدة وتوحيد المنيو',
      ),
    ],
  };

  @override
  Future<List<PriceChangeRequest>> getPriceChangeRequests() async {
    return List.unmodifiable(_requests);
  }

  @override
  Future<PriceChangeRequest?> getPriceChangeRequestById(String id) async {
    try {
      return _requests.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PriceChangeRequest> createPriceChangeRequest({
    required String itemId,
    required double proposedPrice,
    required String reason,
    double? currentPrice,
    DateTime? effectiveDate,
    String? requestedByUserId,
  }) async {
    if (currentPrice != null && (proposedPrice - currentPrice).abs() < 0.005) {
      throw Exception('السعر المقترح يجب أن يختلف عن السعر الحالي');
    }
    final req = PriceChangeRequest(
      id: 'pcr_${DateTime.now().millisecondsSinceEpoch}',
      requestNumber: 'PCR-2024-${(_requests.length + 1).toString().padLeft(3, '0')}',
      itemId: itemId,
      itemNameAr: 'صنف $itemId',
      itemNameEn: 'Item $itemId',
      itemSku: 'SKU-$itemId',
      categoryName: 'عام',
      currentPrice: currentPrice ?? 100.0,
      proposedPrice: proposedPrice,
      cost: 50.0,
      branchName: 'الفرع الرئيسي',
      requestedByName: requestedByUserId ?? 'مستخدم تجريبي',
      requestDate: DateTime.now(),
      status: PriceRequestStatus.pending,
      reason: reason,
      effectiveDate: effectiveDate,
    );
    _requests.insert(0, req);
    return req;
  }

  @override
  Future<void> reviewPriceChangeRequest({
    required String requestId,
    required bool isApproved,
    DateTime? effectiveDate,
    String? note,
    double? approvedPrice,
  }) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index >= 0) {
      final req = _requests[index];
      final finalPrice = approvedPrice ?? req.proposedPrice;
      if (isApproved && approvedPrice != null) {
        if (approvedPrice <= 0) {
          throw Exception('السعر المعتمد يجب أن يكون رقماً حقيقياً موجباً (> 0)');
        }
        if ((approvedPrice - req.currentPrice).abs() < 0.005) {
          throw Exception('السعر المعتمد يجب أن يختلف عن السعر الحالي للصنف');
        }
      }
      _requests[index] = req.copyWith(
        status: isApproved ? PriceRequestStatus.approved : PriceRequestStatus.rejected,
        effectiveDate: effectiveDate ?? req.effectiveDate,
        approvedPrice: isApproved ? finalPrice : null,
      );

      if (isApproved) {
        // Record in history
        final list = _history.putIfAbsent(req.itemId, () => []);
        list.insert(
          0,
          PriceHistoryEntry(
            id: 'hist_${DateTime.now().millisecondsSinceEpoch}',
            itemId: req.itemId,
            oldPrice: req.currentPrice,
            newPrice: finalPrice,
            effectiveDate: effectiveDate ?? DateTime.now(),
            approvedByName: 'د. سارة فهمي (المدير التنفيذي)',
            reason: note ?? req.reason,
          ),
        );
      }
    }
  }

  @override
  Future<List<PriceHistoryEntry>> getPriceHistory(String itemId) async {
    return _history[itemId] ?? [];
  }

  @override
  Future<ItemPricingSummary?> getItemPricingSummary(String itemId) async {
    final req = _requests.cast<PriceChangeRequest?>().firstWhere(
      (r) => r?.itemId == itemId,
      orElse: () => null,
    );
    if (req != null) {
      return ItemPricingSummary(
        itemId: req.itemId,
        itemNameAr: req.itemNameAr,
        itemNameEn: req.itemNameEn,
        itemSku: req.itemSku,
        categoryName: req.categoryName,
        currentPrice: req.currentPrice,
        cost: req.cost,
        effectiveSince: '2024-03-01',
        upcomingPrice: req.proposedPrice,
        upcomingEffectiveDate: req.effectiveDate != null
            ? '${req.effectiveDate!.year}-${req.effectiveDate!.month.toString().padLeft(2, '0')}-${req.effectiveDate!.day.toString().padLeft(2, '0')}'
            : null,
        upcomingStatus: req.status.name,
      );
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveMenuItems() async {
    final seen = <String>{};
    final items = <Map<String, dynamic>>[];
    for (final r in _requests) {
      if (seen.add(r.itemId)) {
        items.add({
          'id': r.itemId,
          'nameAr': r.itemNameAr,
          'nameEn': r.itemNameEn,
          'sku': r.itemSku,
          'price': r.currentPrice,
          'cost': r.cost,
          'categoryName': r.categoryName,
        });
      }
    }
    return items;
  }
}
