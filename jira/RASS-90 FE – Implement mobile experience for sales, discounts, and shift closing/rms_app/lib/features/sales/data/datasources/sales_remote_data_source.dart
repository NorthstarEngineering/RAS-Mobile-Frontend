import '../../../../core/network/api_client.dart';

abstract class SalesRemoteDataSource {
  Future<Map<String, dynamic>> getSalesDashboard({String? branchId, String? shiftId});
  Future<Map<String, dynamic>> getRestaurantSales({
    String? branchId,
    String? shiftId,
    String? category,
    String? query,
  });
  Future<Map<String, dynamic>> getDeliverySales({
    String? branchId,
    String? shiftId,
    String? channel,
  });
  Future<List<Map<String, dynamic>>> getDiscounts({
    String? shiftId,
    String? branchId,
    String? status,
  });
  Future<Map<String, dynamic>> cancelDiscount({
    required String discountId,
    required String reason,
    String? note,
    String? cancelledByUserId,
  });
  Future<Map<String, dynamic>> recordShiftEntry(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> getShiftReview({String? shiftId});
  Future<Map<String, dynamic>> closeShift(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> getClosedShiftSummary({String? shiftId});
}

class SalesRemoteDataSourceImpl implements SalesRemoteDataSource {
  SalesRemoteDataSourceImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<Map<String, dynamic>> getSalesDashboard({
    String? branchId,
    String? shiftId,
  }) async {
    final queryParams = <String, String>{};
    if (branchId != null) queryParams['branchId'] = branchId;
    if (shiftId != null) queryParams['shiftId'] = shiftId;

    String path = '/sales/dashboard';
    if (queryParams.isNotEmpty) {
      final query = Uri(queryParameters: queryParams).query;
      path = '$path?$query';
    }

    final res = await _apiClient.get(path);
    if (res.success && res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    throw Exception('Failed to load sales dashboard: ${res.error}');
  }

  @override
  Future<Map<String, dynamic>> getRestaurantSales({
    String? branchId,
    String? shiftId,
    String? category,
    String? query,
  }) async {
    final queryParams = <String, String>{};
    if (branchId != null) queryParams['branchId'] = branchId;
    if (shiftId != null) queryParams['shiftId'] = shiftId;
    if (category != null && category != 'الكل') queryParams['category'] = category;
    if (query != null && query.isNotEmpty) queryParams['query'] = query;

    String path = '/sales/restaurant';
    if (queryParams.isNotEmpty) {
      final queryString = Uri(queryParameters: queryParams).query;
      path = '$path?$queryString';
    }

    final res = await _apiClient.get(path);
    if (res.success && res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    throw Exception('Failed to load restaurant sales: ${res.error}');
  }

  @override
  Future<Map<String, dynamic>> getDeliverySales({
    String? branchId,
    String? shiftId,
    String? channel,
  }) async {
    final queryParams = <String, String>{};
    if (branchId != null) queryParams['branchId'] = branchId;
    if (shiftId != null) queryParams['shiftId'] = shiftId;
    if (channel != null && channel != 'الكل') queryParams['channel'] = channel;

    String path = '/sales/delivery';
    if (queryParams.isNotEmpty) {
      final queryString = Uri(queryParameters: queryParams).query;
      path = '$path?$queryString';
    }

    final res = await _apiClient.get(path);
    if (res.success && res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    throw Exception('Failed to load delivery sales: ${res.error}');
  }

  @override
  Future<List<Map<String, dynamic>>> getDiscounts({
    String? shiftId,
    String? branchId,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (shiftId != null) queryParams['shiftId'] = shiftId;
    if (branchId != null) queryParams['branchId'] = branchId;
    if (status != null && status != 'الكل') queryParams['status'] = status;

    String path = '/sales/discounts';
    if (queryParams.isNotEmpty) {
      final queryString = Uri(queryParameters: queryParams).query;
      path = '$path?$queryString';
    }

    final res = await _apiClient.get(path);
    if (res.success && res.data is List) {
      return (res.data as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    throw Exception('Failed to load discounts: ${res.error}');
  }

  @override
  Future<Map<String, dynamic>> cancelDiscount({
    required String discountId,
    required String reason,
    String? note,
    String? cancelledByUserId,
  }) async {
    final payload = <String, dynamic>{
      'reason': reason,
      if (note != null) 'note': note,
      'cancelledByUserId': cancelledByUserId ?? 'usr_bm1',
    };

    final res = await _apiClient.post(
      '/sales/discounts/$discountId/cancel',
      body: payload,
    );
    if (res.success && res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    throw Exception('Failed to cancel discount: ${res.error}');
  }

  @override
  Future<Map<String, dynamic>> recordShiftEntry(Map<String, dynamic> payload) async {
    final res = await _apiClient.post('/sales/shift/entry', body: payload);
    if (res.success && res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    throw Exception('Failed to record shift entry: ${res.error}');
  }

  @override
  Future<Map<String, dynamic>> getShiftReview({String? shiftId}) async {
    final query = shiftId != null ? '?shiftId=$shiftId' : '';
    final res = await _apiClient.get('/sales/shift/review$query');
    if (res.success && res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    throw Exception('Failed to load shift review: ${res.error}');
  }

  @override
  Future<Map<String, dynamic>> closeShift(Map<String, dynamic> payload) async {
    final res = await _apiClient.post('/sales/shift/close', body: payload);
    if (res.success && res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    throw Exception('Failed to close shift: ${res.error}');
  }

  @override
  Future<Map<String, dynamic>> getClosedShiftSummary({String? shiftId}) async {
    final query = shiftId != null ? '?shiftId=$shiftId' : '';
    final res = await _apiClient.get('/sales/shift/closed$query');
    if (res.success && res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    throw Exception('Failed to load closed shift summary: ${res.error}');
  }
}
