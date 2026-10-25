import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';

abstract class InventoryRemoteDataSource {
  Future<List<Map<String, dynamic>>> getInventory({
    String branchId = 'br_01',
    String? category,
    String? stockLevel,
    String? query,
  });

  Future<Map<String, dynamic>?> getInventoryItem(
    String id, {
    String? branchId,
  });

  Future<Map<String, dynamic>> adjustStock(Map<String, dynamic> payload);

  Future<List<Map<String, dynamic>>> getStockMovements({
    String branchId = 'br_01',
    String? stockItemId,
    String? movementType,
    int limit = 50,
    int offset = 0,
  });

  Future<Map<String, dynamic>> getValuation({
    String branchId = 'br_01',
  });

  Future<List<Map<String, dynamic>>> getBranches();
}

class InventoryRemoteDataSourceImpl implements InventoryRemoteDataSource {
  InventoryRemoteDataSourceImpl({ApiClient? apiClient})
      : _apiClient = apiClient ??
            (sl.isRegistered<ApiClient>() ? sl<ApiClient>() : ApiClient());

  final ApiClient _apiClient;

  @override
  Future<List<Map<String, dynamic>>> getInventory({
    String branchId = 'br_01',
    String? category,
    String? stockLevel,
    String? query,
  }) async {
    final queryParams = <String, String>{
      'branch_id': branchId,
    };
    if (category != null && category != 'الكل' && category.isNotEmpty) {
      queryParams['category'] = category;
    }
    if (stockLevel != null && stockLevel != 'الكل' && stockLevel.isNotEmpty) {
      queryParams['status'] = stockLevel;
    }
    if (query != null && query.trim().isNotEmpty) {
      queryParams['q'] = query.trim();
    }

    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final res = await _apiClient.get('/inventory?$queryString');
    if (res.success && res.data is List) {
      return (res.data as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getInventoryItem(
    String id, {
    String? branchId,
  }) async {
    final branchParam = (branchId != null && branchId.isNotEmpty)
        ? '?branch_id=${Uri.encodeComponent(branchId)}'
        : '';
    final res = await _apiClient.get('/inventory/$id$branchParam');
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> adjustStock(Map<String, dynamic> payload) async {
    final res = await _apiClient.post('/inventory/adjust', body: payload);
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception(res.error?.toString() ?? 'فشل تنفيذ عملية التسوية المخزنية');
  }

  @override
  Future<List<Map<String, dynamic>>> getStockMovements({
    String branchId = 'br_01',
    String? stockItemId,
    String? movementType,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'branch_id': branchId,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (stockItemId != null && stockItemId.isNotEmpty) {
      queryParams['stock_item_id'] = stockItemId;
    }
    if (movementType != null &&
        movementType != 'الكل' &&
        movementType.isNotEmpty) {
      queryParams['type'] = movementType;
    }

    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final res = await _apiClient.get('/inventory/movements?$queryString');
    if (res.success && res.data is List) {
      return (res.data as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> getValuation({
    String branchId = 'br_01',
  }) async {
    try {
      final res = await _apiClient.get(
        '/inventory/valuation?branch_id=${Uri.encodeComponent(branchId)}',
      );
      if (res.success && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
    } catch (_) {
      final resAlt = await _apiClient.get(
        '/inventory/value?branch_id=${Uri.encodeComponent(branchId)}',
      );
      if (resAlt.success && resAlt.data is Map) {
        return Map<String, dynamic>.from(resAlt.data as Map);
      }
    }
    return {};
  }

  @override
  Future<List<Map<String, dynamic>>> getBranches() async {
    try {
      final res = await _apiClient.get('/branches');
      if (res.success && res.data is List) {
        return (res.data as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
