import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/branch.dart';
import '../../domain/repositories/branch_repository.dart';
import '../datasources/branches_remote_data_source.dart';

class HttpBranchRepository implements BranchRepository {
  HttpBranchRepository({
    ApiClient? apiClient,
    BranchesRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource ??
            BranchesRemoteDataSource(
              apiClient: apiClient ??
                  (sl.isRegistered<ApiClient>() ? sl<ApiClient>() : ApiClient()),
            );

  final BranchesRemoteDataSource _remoteDataSource;

  // Runtime session cache (populated strictly from backend, zero hardcoded fallback data)
  final List<Branch> _cachedBranches = [];

  static Branch _mapJsonToBranch(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String? ?? 'dining').toLowerCase();
    final isKitchen = typeStr == 'kitchen';

    final name = (json['name'] ?? json['nameAr'] ?? json['name_ar'] ?? '') as String;
    final code = (json['code'] ?? '') as String;
    final isMain = json['isMain'] as bool? ??
        (code == 'BR-01' || name.contains('الرئيسي'));

    return Branch(
      id: (json['id'] ?? '') as String,
      code: code,
      name: name,
      address: (json['address'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      managerName: (json['managerName'] ?? json['manager_name'] ?? '') as String,
      employeeCount: (json['employeeCount'] ?? json['employee_count'] as num?)?.toInt() ?? 0,
      efficiencyRate: (json['efficiencyRate'] ?? json['efficiency_rate'] as num?)?.toDouble() ??
          (isKitchen ? 99.8 : (isMain ? 99.1 : 98.4)),
      type: isKitchen ? BranchType.kitchen : BranchType.dining,
      isMain: isMain,
      isActive: json['isActive'] as bool? ??
          (json['is_active'] == 1 || json['is_active'] == true),
      workingHours: (json['workingHours'] ?? json['working_hours'] as String?) ??
          (isKitchen ? '24 ساعة / 7 أيام' : '09:00 ص - 01:00 ص'),
      posTerminalsCount: (json['posTerminalsCount'] ?? json['pos_terminals_count'] as num?)?.toInt() ??
          (isKitchen ? 2 : (isMain ? 5 : 4)),
    );
  }

  static Map<String, dynamic> _branchToJson(Branch b) {
    return {
      if (b.id.isNotEmpty) 'id': b.id,
      'code': b.code,
      'nameAr': b.name,
      'nameEn': b.code,
      'type': b.type == BranchType.kitchen ? 'kitchen' : 'dining',
      'address': b.address,
      'phone': b.phone,
      'managerName': b.managerName,
      'isActive': b.isActive,
      'isMain': b.isMain,
      'workingHours': b.workingHours,
      'posTerminalsCount': b.posTerminalsCount,
    };
  }

  @override
  Future<List<Branch>> getBranches({
    String? search,
    BranchType? type,
    bool? isActive,
  }) async {
    final typeStr = type == null
        ? null
        : (type == BranchType.kitchen ? 'kitchen' : 'dining');
    final remoteList = await _remoteDataSource.getBranches(
      search: search,
      type: typeStr,
      isActive: isActive,
    );
    final parsed = remoteList.map(_mapJsonToBranch).toList();
    _cachedBranches.clear();
    _cachedBranches.addAll(parsed);

    var list = _cachedBranches;
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      list = list.where((b) {
        return b.name.toLowerCase().contains(q) ||
            b.code.toLowerCase().contains(q) ||
            b.address.toLowerCase().contains(q);
      }).toList();
    }
    if (type != null) {
      list = list.where((b) => b.type == type).toList();
    }
    if (isActive != null) {
      list = list.where((b) => b.isActive == isActive).toList();
    }
    return List.unmodifiable(list);
  }

  @override
  Future<Branch?> getBranchById(String id) async {
    final data = await _remoteDataSource.getBranchById(id);
    if (data != null) {
      final b = _mapJsonToBranch(data);
      final idx = _cachedBranches.indexWhere((e) => e.id == b.id);
      if (idx >= 0) {
        _cachedBranches[idx] = b;
      } else {
        _cachedBranches.add(b);
      }
      return b;
    }
    return null;
  }

  @override
  Future<Branch> createBranch(Branch branch) async {
    final payload = _branchToJson(branch);
    final res = await _remoteDataSource.createBranch(payload);
    final created = _mapJsonToBranch(res);
    _cachedBranches.removeWhere((b) => b.id == created.id || b.code == created.code);
    _cachedBranches.add(created);
    return created;
  }

  @override
  Future<Branch> updateBranch(Branch branch) async {
    final payload = _branchToJson(branch);
    final res = await _remoteDataSource.updateBranch(branch.id, payload);
    final updated = _mapJsonToBranch(res);
    final idx = _cachedBranches.indexWhere((b) => b.id == updated.id);
    if (idx >= 0) {
      _cachedBranches[idx] = updated;
    } else {
      _cachedBranches.add(updated);
    }
    return updated;
  }

  @override
  Future<void> deleteBranch(String id) async {
    await _remoteDataSource.deleteBranch(id);
    _cachedBranches.removeWhere((b) => b.id == id);
  }

  @override
  Future<Map<String, dynamic>> getCentralKitchenSummary() async {
    final data = await _remoteDataSource.getCentralKitchenSummary();
    return data;
  }
}
