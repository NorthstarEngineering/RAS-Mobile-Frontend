import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';

abstract class SupplyRemoteDataSource {
  Future<List<Map<String, dynamic>>> getSupplyOrders({
    String? branchId,
    String? status,
    String? search,
  });

  Future<Map<String, dynamic>?> getSupplyOrderById(String id);

  Future<Map<String, dynamic>> createSupplyOrder(Map<String, dynamic> payload);

  Future<Map<String, dynamic>> executeSupplyOrder(
    String id,
    Map<String, dynamic> payload,
  );

  Future<Map<String, dynamic>> receiveSupplyOrder(
    String id,
    Map<String, dynamic> payload,
  );

  Future<Map<String, dynamic>> rejectSupplyOrder(
    String id, {
    String? reason,
    String? userId,
  });
}

class SupplyRemoteDataSourceImpl implements SupplyRemoteDataSource {
  SupplyRemoteDataSourceImpl({ApiClient? apiClient})
      : _apiClient = apiClient ??
            (sl.isRegistered<ApiClient>() ? sl<ApiClient>() : ApiClient());

  final ApiClient _apiClient;

  @override
  Future<List<Map<String, dynamic>>> getSupplyOrders({
    String? branchId,
    String? status,
    String? search,
  }) async {
    final queryParams = <String, String>{};
    if (branchId != null && branchId.isNotEmpty) {
      queryParams['branch_id'] = branchId;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    String path = '/supply';
    if (queryParams.isNotEmpty) {
      final query = queryParams.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      path = '$path?$query';
    }

    final res = await _apiClient.get(path);
    if (res.success && res.data != null) {
      return _extractList(res.data);
    }
    if (!res.success) {
      throw Exception(res.message ?? res.error ?? 'فشل جلب طلبات التوريد من الخادم');
    }
    return [];
  }

  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) {
      if (data['orders'] is List) {
        return (data['orders'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getSupplyOrderById(String id) async {
    final res = await _apiClient.get('/supply/$id');
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    if (!res.success) {
      throw Exception(res.message ?? res.error ?? 'طلب التوريد غير موجود');
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> createSupplyOrder(
    Map<String, dynamic> payload,
  ) async {
    final res = await _apiClient.post('/supply', body: payload);
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception(res.message ?? res.error ?? 'فشل إنشاء طلب التوريد في الخادم');
  }

  @override
  Future<Map<String, dynamic>> executeSupplyOrder(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _apiClient.post(
      '/supply/$id/execute',
      body: payload,
    );
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception(res.message ?? res.error ?? 'فشل صرف وتنفيذ طلب التوريد');
  }

  @override
  Future<Map<String, dynamic>> receiveSupplyOrder(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _apiClient.post(
      '/supply/$id/receive',
      body: payload,
    );
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception(res.message ?? res.error ?? 'فشل تأكيد استلام طلب التوريد');
  }

  @override
  Future<Map<String, dynamic>> rejectSupplyOrder(
    String id, {
    String? reason,
    String? userId,
  }) async {
    final queryParams = <String, String>{};
    if (reason != null && reason.isNotEmpty) {
      queryParams['reason'] = reason;
    }
    if (userId != null && userId.isNotEmpty) {
      queryParams['user_id'] = userId;
    }

    String path = '/supply/$id/reject';
    if (queryParams.isNotEmpty) {
      final query = queryParams.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      path = '$path?$query';
    }

    final res = await _apiClient.post(path);
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception(res.message ?? res.error ?? 'فشل رفض طلب التوريد');
  }
}
