import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/branch.dart';

class ApiBranchRepository {
  ApiBranchRepository(this._api);
  final ApiClient _api;

  Future<List<Branch>> getBranches() async {
    final data = await _api.get('/branches');
    if (data is! List) {
      throw const ApiException(
        502,
        'invalid_response',
        'Invalid branch response',
      );
    }
    return data.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      final id = item['id']?.toString() ?? '';
      return Branch(
        id: id,
        code: id.isEmpty ? '' : id.substring(0, id.length < 8 ? id.length : 8),
        name: item['name']?.toString() ?? '',
        address: item['address']?.toString() ?? '',
        phone: '',
        managerName: '',
        employeeCount: 0,
        efficiencyRate: 0,
        type: item['type'] == 'central_kitchen'
            ? BranchType.kitchen
            : BranchType.dining,
        isActive: item['is_active'] == true,
        workingHours: item['official_start_time']?.toString() ?? '',
        posTerminalsCount: 0,
      );
    }).toList();
  }

  Future<Branch> getBranch(String id) async {
    final data = await _api.get('/branches/$id');
    if (data is! Map) {
      throw const ApiException(
        502,
        'invalid_response',
        'Invalid branch response',
      );
    }
    final list = await _decodeSingle(data);
    return list;
  }

  Future<Branch> _decodeSingle(Map raw) async {
    final item = Map<String, dynamic>.from(raw);
    final id = item['id']?.toString() ?? '';
    return Branch(
      id: id,
      code: id.length > 8 ? id.substring(0, 8) : id,
      name: item['name']?.toString() ?? '',
      address: item['address']?.toString() ?? '',
      phone: '',
      managerName: '',
      employeeCount: 0,
      efficiencyRate: 0,
      type: item['type'] == 'central_kitchen'
          ? BranchType.kitchen
          : BranchType.dining,
      isActive: item['is_active'] == true,
      workingHours: item['official_start_time']?.toString() ?? '',
      posTerminalsCount: 0,
    );
  }
}
