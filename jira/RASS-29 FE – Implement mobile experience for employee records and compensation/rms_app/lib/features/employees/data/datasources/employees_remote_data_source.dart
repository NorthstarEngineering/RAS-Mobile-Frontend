import '../../../../core/network/api_client.dart';

class EmployeesRemoteDataSource {
  EmployeesRemoteDataSource({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> getEmployees({
    String? branchId,
    String? status,
    String? wageType,
    String? search,
  }) async {
    final queryParams = <String, String>{};
    if (branchId != null) queryParams['branchId'] = branchId;
    if (status != null) queryParams['status'] = status;
    if (wageType != null) queryParams['wageType'] = wageType;
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    String path = '/employees';
    if (queryParams.isNotEmpty) {
      final queryString = Uri(queryParameters: queryParams).query;
      path = '$path?$queryString';
    }

    final response = await _apiClient.get(path);
    if (response.success && response.data is List) {
      return (response.data as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> getEmployeeById(String id) async {
    final response = await _apiClient.get('/employees/$id');
    if (response.success && response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>> createEmployee(
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.post('/employees', body: payload);
    if (response.success && response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Failed to create employee: ${response.error}');
  }

  Future<Map<String, dynamic>> updateEmployee(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.put('/employees/$id', body: payload);
    if (response.success && response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Failed to update employee: ${response.error}');
  }

  Future<Map<String, dynamic>?> getCompensation(String id) async {
    final response = await _apiClient.get('/employees/$id/compensation');
    if (response.success && response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getPayHistory(String id) async {
    final response = await _apiClient.get('/employees/$id/pay-history');
    if (response.success && response.data is List) {
      return (response.data as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    return [];
  }

  Future<void> deleteEmployee(String id) async {
    final response = await _apiClient.delete('/employees/$id');
    if (!response.success) {
      throw Exception(response.error ?? 'فشل حذف بيانات الموظف من الخادم');
    }
  }
}
