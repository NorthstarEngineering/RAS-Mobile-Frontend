import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';

class BranchesRemoteDataSource {
  final ApiClient _apiClient;

  BranchesRemoteDataSource({ApiClient? apiClient})
      : _apiClient = apiClient ??
            (sl.isRegistered<ApiClient>() ? sl<ApiClient>() : ApiClient());

  /// استرجاع قائمة الفروع من الخادم
  Future<List<Map<String, dynamic>>> getBranches({
    String? search,
    String? type,
    bool? isActive,
  }) async {
    final queryParams = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (type != null && type.trim().isNotEmpty) {
      queryParams['type'] = type.trim();
    }
    if (isActive != null) {
      queryParams['is_active'] = isActive.toString();
    }

    final query = queryParams.isNotEmpty
        ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
        : '';

    final res = await _apiClient.get('/branches$query');
    if (res.success && res.data is List) {
      return (res.data as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    if (!res.success) {
      throw Exception(res.error?.toString() ?? 'فشل جلب قائمة الفروع من الخادم');
    }
    return [];
  }

  /// استرجاع بيانات فرع محدد بواسطة المعرف أو الكود
  Future<Map<String, dynamic>?> getBranchById(String id) async {
    final res = await _apiClient.get('/branches/$id');
    if (res.success && res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    if (!res.success) {
      final err = res.error?.toString() ?? '';
      if (err.contains('404') || err.contains('غير موجود')) {
        return null;
      }
      throw Exception(res.error?.toString() ?? 'فشل استرجاع بيانات الفرع');
    }
    return null;
  }

  /// إنشاء فرع جديد وإرساله للخادم الموحد
  Future<Map<String, dynamic>> createBranch(Map<String, dynamic> payload) async {
    final res = await _apiClient.post('/branches', body: payload);
    if (res.success && res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    throw Exception(res.error?.toString() ?? 'فشل إنشاء الفرع في الخادم');
  }

  /// تحديث بيانات فرع قائم في الخادم
  Future<Map<String, dynamic>> updateBranch(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _apiClient.put('/branches/$id', body: payload);
    if (res.success && res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    throw Exception(res.error?.toString() ?? 'فشل تحديث بيانات الفرع');
  }

  /// حذف الفرع من الخادم
  Future<void> deleteBranch(String id) async {
    final res = await _apiClient.delete('/branches/$id');
    if (!res.success) {
      throw Exception(res.error?.toString() ?? 'فشل حذف الفرع من الخادم');
    }
  }

  /// استرجاع ملخص مؤشرات أداء المطبخ والمستودع المركزي
  Future<Map<String, dynamic>> getCentralKitchenSummary() async {
    final res = await _apiClient.get('/branches/central-kitchen/summary');
    if (res.success && res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    if (!res.success) {
      throw Exception(res.error?.toString() ?? 'فشل جلب ملخص المطبخ المركزي');
    }
    return {};
  }
}
