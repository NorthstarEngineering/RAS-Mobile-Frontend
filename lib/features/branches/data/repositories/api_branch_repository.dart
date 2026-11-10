import '../../../../core/network/authenticated_api.dart';
import '../../domain/entities/branch.dart';
import '../../domain/repositories/branch_repository.dart';

class ApiBranchRepository implements BranchRepository {
  ApiBranchRepository(this.api);

  final AuthenticatedApi api;

  @override
  Future<List<Branch>> getBranches() async {
    final data = await api.get('/api/v1/branches');
    final values = data is List
        ? data
        : data is Map
        ? (data['branches'] ?? data['data'])
        : null;
    if (values is! List) return const [];
    return values.whereType<Map>().map(_fromJson).toList();
  }

  @override
  Future<Branch> createBranch({
    required String name,
    required String type,
    required String address,
    required String officialStartTime,
    required double lateRate,
  }) async {
    final data = await api.post('/api/v1/branches', {
      'name': name,
      'type': type,
      'address': address,
      'official_start_time': officialStartTime,
      'late_rate': lateRate,
    });
    return _fromJson(
      data is Map && data['branch'] is Map ? data['branch'] : data,
    );
  }

  @override
  Future<Branch> updateBranch(
    String id, {
    String? name,
    String? address,
    String? officialStartTime,
    double? lateRate,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (officialStartTime != null) 'official_start_time': officialStartTime,
      if (lateRate != null) 'late_rate': lateRate,
      if (isActive != null) 'is_active': isActive,
    };
    final data = await api.patch('/api/v1/branches/$id', body);
    return _fromJson(
      data is Map && data['branch'] is Map ? data['branch'] : data,
    );
  }

  Branch _fromJson(Map value) => Branch(
    id: '${value['id'] ?? ''}',
    code: '${value['id'] ?? ''}',
    name: '${value['name'] ?? ''}',
    address: '${value['address'] ?? ''}',
    phone: '',
    managerName: '',
    employeeCount: 0,
    efficiencyRate: 0,
    isActive: value['is_active'] == true,
    isMain: false,
    posTerminalsCount: 0,
    type: '${value['type']}' == 'central_kitchen'
        ? BranchType.kitchen
        : BranchType.dining,
  );
}
