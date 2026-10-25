import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_config.dart';

/// ميثاق مصدر بيانات الساعات الإضافية عن بعد (Remote Data Source)
abstract class OvertimeRemoteDataSource {
  Future<List<Map<String, dynamic>>> getOvertimeRecords({
    String? status,
    String? employeeId,
    String? branchId,
  });

  Future<Map<String, dynamic>?> getOvertimeRecordById(String id);

  Future<Map<String, dynamic>> createOvertimeRecord({
    required String employeeId,
    required double hours,
    required String reason,
    String? id,
    String? branchId,
    String? date,
    double rateMultiplier = 1.5,
    double? hourlyRate,
    double? calculatedAmount,
    String? timeRange,
    String? trigger,
  });

  Future<Map<String, dynamic>> reviewOvertimeRecord({
    required String id,
    String? reviewerId,
    String? notes,
    double? hours,
    double? rateMultiplier,
  });

  Future<Map<String, dynamic>> approveOvertimeRecord({
    required String id,
    required bool isApproved,
    String? approvedByUserId,
    String? decisionReason,
  });
}

/// التنفيذ الفعلي لمصدر بيانات الساعات الإضافية عبر HTTP REST API
class OvertimeRemoteDataSourceImpl implements OvertimeRemoteDataSource {
  OvertimeRemoteDataSourceImpl({
    ApiClient? apiClient,
    http.Client? httpClient,
    String? baseUrl,
  })  : _apiClient = apiClient,
        _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? (apiClient?.baseUrl ?? ApiConfig.baseUrl);

  final ApiClient? _apiClient;
  final http.Client _httpClient;
  final String _baseUrl;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      };

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$_baseUrl$cleanPath';
    final uri = Uri.parse(fullUrl);
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  Map<String, dynamic> _extractData(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('data') && decoded['data'] is Map<String, dynamic>) {
        return decoded['data'] as Map<String, dynamic>;
      }
      return decoded;
    }
    throw const FormatException('Invalid JSON object received from server');
  }

  @override
  Future<List<Map<String, dynamic>>> getOvertimeRecords({
    String? status,
    String? employeeId,
    String? branchId,
  }) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) queryParams['status_filter'] = status;
    if (employeeId != null && employeeId.isNotEmpty) queryParams['employee_id'] = employeeId;
    if (branchId != null && branchId.isNotEmpty) queryParams['branch_id'] = branchId;

    if (_apiClient != null) {
      String path = '/overtime';
      if (queryParams.isNotEmpty) {
        final query = queryParams.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        path = '$path?$query';
      }
      final res = await _apiClient.get(path);
      if (res.success && res.data != null) {
        if (res.data is List) {
          return (res.data as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        if (res.data is Map && (res.data as Map)['data'] is List) {
          return ((res.data as Map)['data'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      return [];
    }

    final uri = _buildUri('/overtime', queryParams);
    final response = await _httpClient
        .get(uri, headers: _headers)
        .timeout(ApiConfig.connectTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic> && decoded['data'] is List) {
        return (decoded['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    }
    throw Exception('Server returned ${response.statusCode}: ${response.body}');
  }

  @override
  Future<Map<String, dynamic>?> getOvertimeRecordById(String id) async {
    if (_apiClient != null) {
      final res = await _apiClient.get('/overtime/$id');
      if (res.success && res.data != null) {
        return _extractData(res.data);
      }
      return null;
    }

    final uri = _buildUri('/overtime/$id');
    final response = await _httpClient
        .get(uri, headers: _headers)
        .timeout(ApiConfig.connectTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return _extractData(decoded);
    } else if (response.statusCode == 404) {
      return null;
    }
    throw Exception('Failed to load overtime record: ${response.statusCode}');
  }

  @override
  Future<Map<String, dynamic>> createOvertimeRecord({
    required String employeeId,
    required double hours,
    required String reason,
    String? id,
    String? branchId,
    String? date,
    double rateMultiplier = 1.5,
    double? hourlyRate,
    double? calculatedAmount,
    String? timeRange,
    String? trigger,
  }) async {
    final payload = <String, dynamic>{
      'employeeId': employeeId,
      'hours': hours,
      'reason': reason,
      'rateMultiplier': rateMultiplier,
      if (id != null) 'id': id,
      if (branchId != null) 'branchId': branchId,
      if (date != null) 'date': date,
      if (hourlyRate != null) 'hourlyRate': hourlyRate,
      if (calculatedAmount != null) 'calculatedAmount': calculatedAmount,
      if (timeRange != null) 'timeRange': timeRange,
      if (trigger != null) 'trigger': trigger,
    };

    if (_apiClient != null) {
      final res = await _apiClient.post('/overtime', body: payload);
      if (res.success && res.data != null) {
        return _extractData(res.data);
      }
      throw Exception(res.error ?? 'فشل تسجيل طلب الساعات الإضافية على الخادم');
    }

    final uri = _buildUri('/overtime');
    final response = await _httpClient
        .post(
          uri,
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.connectTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return _extractData(decoded);
    }
    throw Exception('Failed to create overtime record: ${response.body}');
  }

  @override
  Future<Map<String, dynamic>> reviewOvertimeRecord({
    required String id,
    String? reviewerId,
    String? notes,
    double? hours,
    double? rateMultiplier,
  }) async {
    final payload = <String, dynamic>{
      if (reviewerId != null) 'reviewerId': reviewerId,
      if (notes != null) 'decisionReason': notes,
      if (hours != null) 'hours': hours,
      if (rateMultiplier != null) 'rateMultiplier': rateMultiplier,
    };

    if (_apiClient != null) {
      final res = await _apiClient.patch('/overtime/$id/review', body: payload);
      if (res.success && res.data != null) {
        return _extractData(res.data);
      }
      throw Exception(res.error ?? 'فشل مراجعة وتحديث طلب الساعات الإضافية');
    }

    final uri = _buildUri('/overtime/$id/review');
    http.Response response = await _httpClient
        .patch(
          uri,
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.connectTimeout);

    if (response.statusCode == 405) {
      // Fallback to POST if server proxies or environments restrict PATCH
      response = await _httpClient
          .post(
            uri,
            headers: _headers,
            body: jsonEncode(payload),
          )
          .timeout(ApiConfig.connectTimeout);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return _extractData(decoded);
    }
    throw Exception('Failed to review overtime record: ${response.body}');
  }

  @override
  Future<Map<String, dynamic>> approveOvertimeRecord({
    required String id,
    required bool isApproved,
    String? approvedByUserId,
    String? decisionReason,
  }) async {
    final payload = <String, dynamic>{
      'isApproved': isApproved,
      'status': isApproved ? 'approved' : 'rejected',
      if (approvedByUserId != null) 'approvedByUserId': approvedByUserId,
      if (decisionReason != null) 'decisionReason': decisionReason,
    };

    if (_apiClient != null) {
      final res = await _apiClient.patch('/overtime/$id/approve', body: payload);
      if (res.success && res.data != null) {
        return _extractData(res.data);
      }
      throw Exception(res.error ?? 'فشل اعتماد/رفض طلب الساعات الإضافية');
    }

    final uri = _buildUri('/overtime/$id/approve');
    http.Response response = await _httpClient
        .patch(
          uri,
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.connectTimeout);

    if (response.statusCode == 405) {
      // Fallback to POST if needed
      response = await _httpClient
          .post(
            uri,
            headers: _headers,
            body: jsonEncode(payload),
          )
          .timeout(ApiConfig.connectTimeout);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return _extractData(decoded);
    }
    throw Exception('Failed to approve/reject overtime record: ${response.body}');
  }
}
