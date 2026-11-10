import '../entities/branch.dart';

abstract class BranchRepository {
  Future<List<Branch>> getBranches();
  Future<Branch> createBranch({
    required String name,
    required String type,
    required String address,
    required String officialStartTime,
    required double lateRate,
  });
  Future<Branch> updateBranch(
    String id, {
    String? name,
    String? address,
    String? officialStartTime,
    double? lateRate,
    bool? isActive,
  });
}
