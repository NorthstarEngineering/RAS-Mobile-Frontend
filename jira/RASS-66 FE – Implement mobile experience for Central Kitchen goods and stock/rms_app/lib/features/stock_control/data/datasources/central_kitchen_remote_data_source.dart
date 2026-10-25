import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';

abstract class CentralKitchenRemoteDataSource {
  Future<Map<String, dynamic>> getDashboardData();

  Future<List<Map<String, dynamic>>> getItems({
    String? category,
    String? status,
    String? query,
  });

  Future<Map<String, dynamic>?> getItemById(String id);

  Future<Map<String, dynamic>> createItem(Map<String, dynamic> data);

  Future<Map<String, dynamic>> updateItem(String id, Map<String, dynamic> data);

  Future<List<Map<String, dynamic>>> getMovements({
    String? filter,
    String? query,
    int? limit,
    int? offset,
  });
}

class CentralKitchenRemoteDataSourceImpl
    implements CentralKitchenRemoteDataSource {
  CentralKitchenRemoteDataSourceImpl({ApiClient? apiClient})
      : _apiClient = apiClient ??
            (sl.isRegistered<ApiClient>() ? sl<ApiClient>() : ApiClient());

  final ApiClient _apiClient;

  @override
  Future<Map<String, dynamic>> getDashboardData() async {
    try {
      final res = await _apiClient.get('/kitchen/dashboard');
      if (res.success && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
    } catch (_) {
      // Fallback to unified dashboards/supply endpoint
      try {
        final resSupply = await _apiClient.get('/dashboards/supply');
        if (resSupply.success && resSupply.data is Map) {
          return Map<String, dynamic>.from(resSupply.data as Map);
        }
      } catch (_) {
        rethrow;
      }
    }
    return {};
  }

  @override
  Future<List<Map<String, dynamic>>> getItems({
    String? category,
    String? status,
    String? query,
  }) async {
    final queryParams = <String, String>{};
    if (category != null && category != 'الكل' && category.isNotEmpty) {
      queryParams['category'] = category;
    }
    if (status != null && status != 'الكل' && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (query != null && query.isNotEmpty) {
      queryParams['q'] = query;
    }

    String queryString = '';
    if (queryParams.isNotEmpty) {
      queryString = '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';
    }

    try {
      final res = await _apiClient.get('/kitchen/items$queryString');
      if (res.success) {
        if (res.data is List) {
          return (res.data as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } else if (res.data is Map && (res.data as Map)['items'] is List) {
          return ((res.data as Map)['items'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (_) {
      // Fallback to inventory route with kitchen branch
      final fallbackQuery = queryParams.isEmpty
          ? '?branch_id=br_04'
          : '?branch_id=br_04&${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';
      try {
        final resInv = await _apiClient.get('/inventory$fallbackQuery');
        if (resInv.success && resInv.data is List) {
          return (resInv.data as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {
        rethrow;
      }
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getItemById(String id) async {
    try {
      final res = await _apiClient.get('/kitchen/items/$id');
      if (res.success && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
    } catch (_) {
      // Fallback to inventory item endpoint
      try {
        final resInv = await _apiClient.get('/inventory/$id?branch_id=br_04');
        if (resInv.success && resInv.data is Map) {
          return Map<String, dynamic>.from(resInv.data as Map);
        }
      } catch (_) {
        rethrow;
      }
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> createItem(Map<String, dynamic> data) async {
    final res = await _apiClient.post('/kitchen/items', body: data);
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception(res.error?.toString() ?? 'فشل حفظ الصنف بالمطبخ المركزي');
  }

  @override
  Future<Map<String, dynamic>> updateItem(String id, Map<String, dynamic> data) async {
    final res = await _apiClient.put('/kitchen/items/$id', body: data);
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception(res.error?.toString() ?? 'فشل تحديث بيانات الصنف بالمطبخ المركزي');
  }

  @override
  Future<List<Map<String, dynamic>>> getMovements({
    String? filter,
    String? query,
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, String>{};
    if (filter != null && filter != 'الكل' && filter.isNotEmpty) {
      queryParams['type'] = filter;
    }
    if (query != null && query.isNotEmpty) {
      queryParams['q'] = query;
    }
    if (limit != null) {
      queryParams['limit'] = limit.toString();
    }
    if (offset != null) {
      queryParams['offset'] = offset.toString();
    }

    String queryString = '';
    if (queryParams.isNotEmpty) {
      queryString = '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';
    }

    try {
      final res = await _apiClient.get('/kitchen/movements$queryString');
      if (res.success) {
        if (res.data is List) {
          return (res.data as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } else if (res.data is Map && (res.data as Map)['movements'] is List) {
          return ((res.data as Map)['movements'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (_) {
      // Fallback to inventory movements
      final sep = queryString.isEmpty ? '?' : '$queryString&';
      final fallbackQuery = '${sep}branch_id=br_04';
      try {
        final resInv = await _apiClient.get('/inventory/movements$fallbackQuery');
        if (resInv.success && resInv.data is List) {
          return (resInv.data as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {
        rethrow;
      }
    }
    return [];
  }
}
