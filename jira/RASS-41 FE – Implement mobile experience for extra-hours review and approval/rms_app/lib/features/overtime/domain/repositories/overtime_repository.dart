import '../entities/overtime_record.dart';

/// ميثاق مستودع الساعات الإضافية (OT Domain Repository Contract)
abstract class OvertimeRepository {
  /// جلب قائمة سجلات وطلبات الساعات الإضافية مع دعم الفلترة حسب الحالة والفرع والموظف
  Future<List<OvertimeRecord>> getOvertimeRecords({
    OvertimeStatus? status,
    String? employeeId,
    String? branchId,
  });

  /// استرجاع تفاصيل سجل ساعات إضافية محدد بواسطة المعرف الفريد
  Future<OvertimeRecord?> getOvertimeRecordById(String id);

  /// تسجيل طلب ساعات إضافية جديد في الخادم الموحد وقاعدة بيانات SQLite
  Future<OvertimeRecord> createOvertimeRecord({
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
    OvertimeTrigger trigger = OvertimeTrigger.managerRequest,
    String? employeeName,
    String? role,
  });

  /// مراجعة طلب الساعات الإضافية وتعديل الساعات أو إضافة ملاحظات المشرف
  Future<OvertimeRecord> reviewOvertimeRecord({
    required String id,
    String? reviewerId,
    String? notes,
    double? hours,
    double? rateMultiplier,
  });

  /// اعتماد أو رفض الساعات الإضافية وترحيل الأثر المالي لسجل الرواتب في SQLite
  Future<OvertimeRecord> approveOvertimeRecord({
    required String id,
    required bool isApproved,
    String? approvedByUserId,
    String? decisionReason,
  });
}
