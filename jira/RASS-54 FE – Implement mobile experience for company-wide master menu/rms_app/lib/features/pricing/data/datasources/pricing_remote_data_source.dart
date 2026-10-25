import '../../../../core/network/api_client.dart';

abstract class PricingRemoteDataSource {
  Future<List<Map<String, dynamic>>> getPriceChangeRequests({
    String? status,
    String? itemId,
    String? branchId,
  });

  Future<Map<String, dynamic>?> getPriceChangeRequestById(String id);

  Future<Map<String, dynamic>> createPriceChangeRequest(
    Map<String, dynamic> payload,
  );

  Future<Map<String, dynamic>> approvePriceChangeRequest(
    String id, {
    String? approvedByUserId,
    String? effectiveDate,
    String? reviewNotes,
    double? approvedPrice,
  });

  Future<Map<String, dynamic>> rejectPriceChangeRequest(
    String id, {
    String? reviewedByUserId,
    String? reviewNotes,
  });

  Future<List<Map<String, dynamic>>> getPriceHistory(String itemId);

  Future<Map<String, dynamic>?> getItemPricingSummary(String itemId);

  Future<List<Map<String, dynamic>>> getActiveMenuItems();
}

class PricingRemoteDataSourceImpl implements PricingRemoteDataSource {
  PricingRemoteDataSourceImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<List<Map<String, dynamic>>> getPriceChangeRequests({
    String? status,
    String? itemId,
    String? branchId,
  }) async {
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;
    if (itemId != null) queryParams['item_id'] = itemId;
    if (branchId != null) queryParams['branch_id'] = branchId;

    String path = '/pricing/requests';
    if (queryParams.isNotEmpty) {
      final query = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      path = '$path?$query';
    }

    final res = await _apiClient.get(path);
    if (res.success && res.data is List) {
      return (res.data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getPriceChangeRequestById(String id) async {
    final res = await _apiClient.get('/pricing/requests/$id');
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> createPriceChangeRequest(
    Map<String, dynamic> payload,
  ) async {
    final res = await _apiClient.post('/pricing/requests', body: payload);
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw NetworkException(
      res.error?.toString() ?? 'فشل تقديم طلب تعديل السعر',
    );
  }

  @override
  Future<Map<String, dynamic>> approvePriceChangeRequest(
    String id, {
    String? approvedByUserId,
    String? effectiveDate,
    String? reviewNotes,
    double? approvedPrice,
  }) async {
    final payload = <String, dynamic>{
      if (approvedByUserId != null) 'approvedByUserId': approvedByUserId,
      if (effectiveDate != null) 'effectiveDate': effectiveDate,
      if (reviewNotes != null) 'reviewNotes': reviewNotes,
      if (approvedPrice != null) 'approvedPrice': approvedPrice,
    };
    final res = await _apiClient.post('/pricing/requests/$id/approve', body: payload);
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw NetworkException(
      res.error?.toString() ?? 'فشل اعتماد تعديل السعر',
    );
  }

  @override
  Future<Map<String, dynamic>> rejectPriceChangeRequest(
    String id, {
    String? reviewedByUserId,
    String? reviewNotes,
  }) async {
    final payload = <String, dynamic>{
      if (reviewedByUserId != null) 'reviewedByUserId': reviewedByUserId,
      if (reviewNotes != null) 'reviewNotes': reviewNotes,
    };
    final res = await _apiClient.post('/pricing/requests/$id/reject', body: payload);
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw NetworkException(
      res.error?.toString() ?? 'فشل رفض طلب تعديل السعر',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPriceHistory(String itemId) async {
    final res = await _apiClient.get('/pricing/history/$itemId');
    if (res.success && res.data is List) {
      return (res.data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getItemPricingSummary(String itemId) async {
    final res = await _apiClient.get('/pricing/summary/$itemId');
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveMenuItems() async {
    final res = await _apiClient.get('/pricing/menu-items');
    if (res.success && res.data is List) {
      return (res.data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    return [];
  }
}
