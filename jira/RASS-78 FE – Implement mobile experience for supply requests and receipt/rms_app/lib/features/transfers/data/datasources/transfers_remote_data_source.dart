import '../../../../core/network/api_client.dart';

abstract class TransfersRemoteDataSource {
  Future<List<Map<String, dynamic>>> getTransfers({
    String? branchId,
    String? status,
    String? query,
  });

  Future<Map<String, dynamic>> getTransferMetrics({
    String? branchId,
  });

  Future<Map<String, dynamic>?> getTransferById(String id);

  Future<Map<String, dynamic>> createTransfer({
    required String sourceBranch,
    required String destinationBranch,
    required String item,
    required double quantity,
    bool isUrgent = false,
    String? notes,
    String? sourceBranchId,
    String? destinationBranchId,
    String? stockItemId,
  });

  Future<Map<String, dynamic>> reviewTransfer({
    required String transferId,
    required double approvedQuantity,
    bool approved = true,
    String? reason,
    bool acknowledged = true,
  });

  Future<Map<String, dynamic>> sendTransfer({
    required String transferId,
    required String vehicle,
    String? driverName,
    String? driverPhone,
    double? temperature,
    String? notes,
  });

  Future<Map<String, dynamic>> receiveTransfer({
    required String transferId,
    required double acceptedQuantity,
    bool hasDamage = false,
    String? damageNotes,
    bool acknowledged = true,
  });

  Future<List<Map<String, dynamic>>> getTransferHistory({
    String? branchId,
    String? query,
  });

  Future<List<Map<String, dynamic>>> getBranches();

  Future<List<Map<String, dynamic>>> getAvailableItems({
    required String branchId,
  });
}

class TransfersRemoteDataSourceImpl implements TransfersRemoteDataSource {
  TransfersRemoteDataSourceImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static String _resolveBranchId(String branch) {
    if (branch.contains('(#01)') || branch.contains('وسط البلد') || branch == 'br_01') {
      return 'br_01';
    }
    if (branch.contains('(#02)') || branch.contains('المعادي') || branch == 'br_02') {
      return 'br_02';
    }
    if (branch.contains('(#03)') || branch.contains('التجمع') || branch == 'br_03') {
      return 'br_03';
    }
    if (branch.contains('(#04)') || branch.contains('الشيخ زايد') || branch.contains('المطبخ') || branch == 'br_04') {
      return 'br_04';
    }
    return branch;
  }

  static String? _resolveSku(String item) {
    if (item.contains('دجاج')) return 'CHK-MAR-BR1';
    if (item.contains('شيدر')) return 'CHED-BR1';
    if (item.contains('لحم')) return 'RAW-BEEF-01';
    if (item.contains('خبز') || item.contains('بريوش')) return 'BUN-BRIO-01';
    if (item.contains('بطاطس')) return 'FRIES-BR1';
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getTransfers({
    String? branchId,
    String? status,
    String? query,
  }) async {
    final queryParams = <String, String>{};
    if (branchId != null) queryParams['branchId'] = branchId;
    if (status != null) queryParams['status'] = status;
    if (query != null && query.isNotEmpty) queryParams['search'] = query;

    String path = '/transfers';
    if (queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      path = '$path?$queryString';
    }

    final res = await _apiClient.get(path);
    if (res.success && res.data != null) {
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
    return [];
  }

  @override
  Future<Map<String, dynamic>> getTransferMetrics({String? branchId}) async {
    String path = '/transfers/metrics';
    if (branchId != null) {
      path = '$path?branchId=${Uri.encodeComponent(branchId)}';
    }
    final res = await _apiClient.get(path);
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    return {};
  }

  @override
  Future<Map<String, dynamic>?> getTransferById(String id) async {
    final res = await _apiClient.get('/transfers/$id');
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> createTransfer({
    required String sourceBranch,
    required String destinationBranch,
    required String item,
    required double quantity,
    bool isUrgent = false,
    String? notes,
    String? sourceBranchId,
    String? destinationBranchId,
    String? stockItemId,
  }) async {
    final resolvedSource = sourceBranchId ?? _resolveBranchId(sourceBranch);
    final resolvedDest = destinationBranchId ?? _resolveBranchId(destinationBranch);
    final resolvedSku = _resolveSku(item);

    final payload = <String, dynamic>{
      'sourceBranchId': resolvedSource,
      'destinationBranchId': resolvedDest,
      'items': [
        {
          if (stockItemId != null && stockItemId.isNotEmpty) 'stockItemId': stockItemId,
          if (resolvedSku != null) 'sku': resolvedSku,
          'itemName': item,
          'quantity': quantity,
        }
      ],
      'notes': notes,
      'isUrgent': isUrgent,
    };

    final res = await _apiClient.post('/transfers', body: payload);
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception(res.error?.toString() ?? 'فشل إنشاء طلب التحويل');
  }

  @override
  Future<Map<String, dynamic>> reviewTransfer({
    required String transferId,
    required double approvedQuantity,
    bool approved = true,
    String? reason,
    bool acknowledged = true,
  }) async {
    final payload = <String, dynamic>{
      'approved': approved,
      'decision': approved ? 'approved' : 'rejected',
      'notes': reason,
      if (approved)
        'approvedQuantities': {
          transferId: approvedQuantity,
        },
    };
    final res = await _apiClient.post('/transfers/$transferId/review', body: payload);
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception(res.error?.toString() ?? 'فشل مراجعة واعتماد التحويل');
  }

  @override
  Future<Map<String, dynamic>> sendTransfer({
    required String transferId,
    required String vehicle,
    String? driverName,
    String? driverPhone,
    double? temperature,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'driverName': (driverName != null && driverName.trim().isNotEmpty)
          ? driverName.trim()
          : 'سائق التحويلات التشغيلي',
      if (driverPhone != null && driverPhone.trim().isNotEmpty)
        'driverPhone': driverPhone.trim(),
      'vehicle': vehicle,
      'departureTime': '11:30 AM',
      if (temperature != null) 'temperature': '$temperature° مئوية',
      if (notes != null) 'notes': notes,
    };
    final res = await _apiClient.post('/transfers/$transferId/send', body: payload);
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception(res.error?.toString() ?? 'فشل إرسال الشحنة');
  }

  @override
  Future<Map<String, dynamic>> receiveTransfer({
    required String transferId,
    required double acceptedQuantity,
    bool hasDamage = false,
    String? damageNotes,
    bool acknowledged = true,
  }) async {
    final payload = <String, dynamic>{
      'hasDamage': hasDamage,
      if (damageNotes != null) 'damageNotes': damageNotes,
      'receivedItems': [
        {
          'receivedQuantity': acceptedQuantity,
        }
      ],
      'notes': damageNotes,
    };
    final res = await _apiClient.post('/transfers/$transferId/receive', body: payload);
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception(res.error?.toString() ?? 'فشل تأكيد استلام الشحنة');
  }

  @override
  Future<List<Map<String, dynamic>>> getTransferHistory({
    String? branchId,
    String? query,
  }) async {
    final queryParams = <String, String>{};
    if (branchId != null) queryParams['branchId'] = branchId;
    if (query != null && query.isNotEmpty) queryParams['search'] = query;

    String path = '/transfers/history';
    if (queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      path = '$path?$queryString';
    }

    try {
      final res = await _apiClient.get(path);
      if (res.success && res.data != null) {
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
      // Fallback
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getBranches() async {
    final res = await _apiClient.get('/transfers/branches');
    if (res.success && res.data is List) {
      return (res.data as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getAvailableItems({required String branchId}) async {
    final resolvedBranch = _resolveBranchId(branchId);
    final res = await _apiClient.get('/transfers/items?branchId=${Uri.encodeComponent(resolvedBranch)}');
    if (res.success && res.data is List) {
      return (res.data as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }
}
