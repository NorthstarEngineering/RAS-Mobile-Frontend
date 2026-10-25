import '../entities/branch.dart';

abstract class BranchRepository {
  /// جلب قائمة الفروع مع إمكانية البحث والتصفية حسب النوع والنشاط
  Future<List<Branch>> getBranches({
    String? search,
    BranchType? type,
    bool? isActive,
  });

  /// جلب تفاصيل فرع محدد بواسطة المعرف ID أو الكود
  Future<Branch?> getBranchById(String id);

  /// إنشاء فرع جديد وإدراجه في النظام
  Future<Branch> createBranch(Branch branch);

  /// تحديث بيانات فرع قائم
  Future<Branch> updateBranch(Branch branch);

  /// حذف أو أرشفة فرع
  Future<void> deleteBranch(String id);

  /// جلب ملخص وإحصائيات المطبخ المركزي
  Future<Map<String, dynamic>> getCentralKitchenSummary();
}
