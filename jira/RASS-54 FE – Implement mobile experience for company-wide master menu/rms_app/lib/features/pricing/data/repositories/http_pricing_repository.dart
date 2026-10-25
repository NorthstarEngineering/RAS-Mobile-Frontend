import '../../../../core/network/api_client.dart';
import '../../domain/entities/item_pricing_summary.dart';
import '../../domain/entities/price_change_request.dart';
import '../../domain/entities/price_history_entry.dart';
import '../../domain/repositories/pricing_repository.dart';
import '../datasources/pricing_remote_data_source.dart';

class HttpPricingRepository implements PricingRepository {
  HttpPricingRepository({
    PricingRemoteDataSource? remoteDataSource,
    ApiClient? apiClient,
  }) : _remoteDataSource =
            remoteDataSource ?? PricingRemoteDataSourceImpl(apiClient: apiClient);

  final PricingRemoteDataSource _remoteDataSource;

  // Local in-memory cache populated only from confirmed network calls
  final List<PriceChangeRequest> _cachedRequests = [];
  final Map<String, List<PriceHistoryEntry>> _history = {};

  @override
  Future<List<PriceChangeRequest>> getPriceChangeRequests() async {
    try {
      final remoteList = await _remoteDataSource.getPriceChangeRequests();
      final parsed = remoteList.map(_mapJsonToRequest).toList();
      _cachedRequests.clear();
      _cachedRequests.addAll(parsed);
      return List.unmodifiable(_cachedRequests);
    } catch (e) {
      // Offline fallback only if cache was previously populated
      if (_cachedRequests.isNotEmpty) {
        return List.unmodifiable(_cachedRequests);
      }
      rethrow;
    }
  }

  @override
  Future<PriceChangeRequest?> getPriceChangeRequestById(String id) async {
    try {
      final remote = await _remoteDataSource.getPriceChangeRequestById(id);
      if (remote != null) {
        final req = _mapJsonToRequest(remote);
        final index = _cachedRequests.indexWhere((r) => r.id == id);
        if (index >= 0) {
          _cachedRequests[index] = req;
        } else {
          _cachedRequests.add(req);
        }
        return req;
      }
      return null;
    } catch (e) {
      final index = _cachedRequests.indexWhere((r) => r.id == id);
      if (index >= 0) {
        return _cachedRequests[index];
      }
      rethrow;
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
    final payload = <String, dynamic>{
      'itemId': itemId,
      'proposedPrice': proposedPrice,
      'reason': reason,
      if (currentPrice != null) 'currentPrice': currentPrice,
      if (effectiveDate != null)
        'effectiveDate':
            '${effectiveDate.year.toString().padLeft(4, '0')}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}',
      if (requestedByUserId != null) 'requestedByUserId': requestedByUserId,
    };

    final res = await _remoteDataSource.createPriceChangeRequest(payload);
    final created = _mapJsonToRequest(res);
    final existingIndex = _cachedRequests.indexWhere((r) => r.id == created.id);
    if (existingIndex >= 0) {
      _cachedRequests[existingIndex] = created;
    } else {
      _cachedRequests.insert(0, created);
    }
    return created;
  }

  @override
  Future<void> reviewPriceChangeRequest({
    required String requestId,
    required bool isApproved,
    DateTime? effectiveDate,
    String? note,
    double? approvedPrice,
  }) async {
    // 1. Perform network update — MUST NOT swallow errors or pretend success
    final effDateStr = effectiveDate != null
        ? '${effectiveDate.year.toString().padLeft(4, '0')}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}'
        : null;

    if (isApproved) {
      await _remoteDataSource.approvePriceChangeRequest(
        requestId,
        effectiveDate: effDateStr,
        reviewNotes: note,
        approvedPrice: approvedPrice,
      );
    } else {
      await _remoteDataSource.rejectPriceChangeRequest(
        requestId,
        reviewNotes: note,
      );
    }

    // 2. Synchronize local cache ONLY AFTER remote call succeeds
    final index = _cachedRequests.indexWhere((r) => r.id == requestId);
    if (index >= 0) {
      final req = _cachedRequests[index];
      _cachedRequests[index] = req.copyWith(
        status: isApproved ? PriceRequestStatus.approved : PriceRequestStatus.rejected,
        effectiveDate: effectiveDate ?? req.effectiveDate,
        approvedPrice: approvedPrice ?? req.approvedPrice ?? (isApproved ? req.proposedPrice : null),
      );
    }
    // Note: Never inject fabricated PriceHistoryEntry in RAM on review.
  }

  @override
  Future<List<PriceHistoryEntry>> getPriceHistory(String itemId) async {
    try {
      final remoteList = await _remoteDataSource.getPriceHistory(itemId);
      final parsed = remoteList.map(_mapJsonToHistory).toList();
      _history[itemId] = parsed;
      return List.unmodifiable(parsed);
    } catch (e) {
      if (_history.containsKey(itemId)) {
        return List.unmodifiable(_history[itemId]!);
      }
      rethrow;
    }
  }

  @override
  Future<ItemPricingSummary?> getItemPricingSummary(String itemId) async {
    final remote = await _remoteDataSource.getItemPricingSummary(itemId);
    if (remote != null) {
      return ItemPricingSummary.fromJson(remote);
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveMenuItems() async {
    return _remoteDataSource.getActiveMenuItems();
  }

  PriceChangeRequest _mapJsonToRequest(Map<String, dynamic> json) {
    PriceRequestStatus parseStatus(String? s) {
      switch (s?.toLowerCase()) {
        case 'approved':
          return PriceRequestStatus.approved;
        case 'rejected':
          return PriceRequestStatus.rejected;
        case 'pending':
        default:
          return PriceRequestStatus.pending;
      }
    }

    DateTime parseDate(dynamic d) {
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseOptionalDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    return PriceChangeRequest(
      id: json['id']?.toString() ?? '',
      requestNumber: json['requestNumber']?.toString() ?? 'PCR-2024-001',
      itemId: json['itemId']?.toString() ?? json['menu_item_id']?.toString() ?? '',
      itemNameAr: json['itemNameAr']?.toString() ?? json['item_name_ar']?.toString() ?? 'صنف غير محدد',
      itemNameEn: json['itemNameEn']?.toString() ?? json['item_name_en']?.toString() ?? '',
      itemSku: json['itemSku']?.toString() ?? json['item_sku']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? json['category_name']?.toString() ?? 'عام',
      currentPrice: (json['currentPrice'] as num?)?.toDouble() ??
          (json['current_price'] as num?)?.toDouble() ??
          0.0,
      proposedPrice: (json['proposedPrice'] as num?)?.toDouble() ??
          (json['proposed_price'] as num?)?.toDouble() ??
          0.0,
      cost: (json['cost'] as num?)?.toDouble() ??
          (json['item_cost'] as num?)?.toDouble() ??
          0.0,
      branchName: json['branchName']?.toString() ?? json['branch_name']?.toString() ?? 'الفرع الرئيسي',
      requestedByName: json['requestedByName']?.toString() ?? json['requested_by_name']?.toString() ?? 'م. ألفاريز',
      requestDate: parseDate(json['requestDate'] ?? json['created_at']),
      status: parseStatus(json['status']?.toString()),
      reason: json['reason']?.toString() ?? '',
      effectiveDate: parseOptionalDate(json['effectiveDate'] ?? json['effective_date']),
      approvedPrice: (json['approvedPrice'] as num?)?.toDouble() ??
          (json['approved_price'] as num?)?.toDouble(),
    );
  }

  PriceHistoryEntry _mapJsonToHistory(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    return PriceHistoryEntry(
      id: json['id']?.toString() ?? '',
      itemId: json['itemId']?.toString() ?? json['menu_item_id']?.toString() ?? '',
      oldPrice: (json['oldPrice'] as num?)?.toDouble() ??
          (json['old_price'] as num?)?.toDouble() ??
          0.0,
      newPrice: (json['newPrice'] as num?)?.toDouble() ??
          (json['new_price'] as num?)?.toDouble() ??
          0.0,
      effectiveDate: parseDate(json['effectiveDate'] ?? json['created_at']),
      approvedByName: json['approvedByName']?.toString() ??
          json['approved_by_name']?.toString() ??
          'المدير التنفيذي',
      reason: json['reason']?.toString() ?? '',
    );
  }
}
