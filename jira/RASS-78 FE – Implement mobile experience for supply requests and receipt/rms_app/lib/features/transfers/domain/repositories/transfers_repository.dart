export '../../presentation/screens/transfer_preview_data.dart';
import '../../presentation/screens/transfer_preview_data.dart';

class TransferOrder extends TransferPreviewOrder {
  const TransferOrder({
    required String id,
    required String source,
    required String destination,
    required String item,
    required String quantity,
    required String status,
    this.transferCode,
    this.sourceBranchId,
    this.destinationBranchId,
    this.stockItemId,
    this.driverName,
    this.driverPhone,
    this.departureTime,
    this.arrivalTime,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.rawQuantity,
    this.receivedQuantity,
    this.sourceBalance,
    this.destinationBalance,
    this.unit,
  }) : super(id, source, destination, item, quantity, status);

  final String? transferCode;
  final String? sourceBranchId;
  final String? destinationBranchId;
  final String? stockItemId;
  final String? driverName;
  final String? driverPhone;
  final String? departureTime;
  final String? arrivalTime;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;
  final double? rawQuantity;
  final double? receivedQuantity;
  final double? sourceBalance;
  final double? destinationBalance;
  final String? unit;

  TransferOrder copyWith({
    String? id,
    String? source,
    String? destination,
    String? item,
    String? quantity,
    String? status,
    String? transferCode,
    String? sourceBranchId,
    String? destinationBranchId,
    String? stockItemId,
    String? driverName,
    String? driverPhone,
    String? departureTime,
    String? arrivalTime,
    String? notes,
    String? createdAt,
    String? updatedAt,
    double? rawQuantity,
    double? receivedQuantity,
    double? sourceBalance,
    double? destinationBalance,
    String? unit,
  }) {
    return TransferOrder(
      id: id ?? this.id,
      source: source ?? this.source,
      destination: destination ?? this.destination,
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      transferCode: transferCode ?? this.transferCode,
      sourceBranchId: sourceBranchId ?? this.sourceBranchId,
      destinationBranchId: destinationBranchId ?? this.destinationBranchId,
      stockItemId: stockItemId ?? this.stockItemId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rawQuantity: rawQuantity ?? this.rawQuantity,
      receivedQuantity: receivedQuantity ?? this.receivedQuantity,
      sourceBalance: sourceBalance ?? this.sourceBalance,
      destinationBalance: destinationBalance ?? this.destinationBalance,
      unit: unit ?? this.unit,
    );
  }
}

abstract class TransfersRepository {
  /// جلب كافة أذونات التحويل مع إمكانية التصفية
  Future<List<TransferPreviewOrder>> getTransfers({
    String? branchId,
    String? status,
    String? query,
  });

  /// جلب مؤشرات وإحصائيات لوحة التحويلات
  Future<Map<String, int>> getTransferMetrics({
    String? branchId,
  });

  /// جلب تفاصيل تحويل محدد بواسطة المعرف
  Future<TransferPreviewOrder?> getTransferById(String id);

  /// إنشاء إذن تحويل جديد بين فرعين
  Future<TransferPreviewOrder> createTransfer({
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

  /// اعتماد ومراجعة إذن التحويل
  Future<TransferPreviewOrder> reviewTransfer({
    required String transferId,
    double? approvedQuantity,
    bool? approved,
    bool? approve,
    String? reason,
    String? notes,
    bool acknowledged = true,
  });

  /// إرسال وشحن التحويل وتسجيل بيانات السائق والوسيلة اللوجستية
  Future<TransferPreviewOrder> sendTransfer({
    required String transferId,
    String? vehicle,
    String? driverName,
    String? driverPhone,
    String? departureTime,
    double? temperature,
    String? notes,
  });

  /// تأكيد استلام الشحنة وإيداع المخزون في الفرع المستلم
  Future<TransferPreviewOrder> receiveTransfer({
    required String transferId,
    double? acceptedQuantity,
    double? receivedQuantity,
    bool hasDamage = false,
    String? damageNotes,
    String? receivingNotes,
    bool acknowledged = true,
  });

  /// جلب سجل التحويلات المنتهية والأرشيف اللوجستي
  Future<List<TransferPreviewOrder>> getTransferHistory({
    String? branchId,
    String? query,
  });

  /// جلب قائمة الفروع النشطة ديناميكياً
  Future<List<Map<String, dynamic>>> getBranches();

  /// جلب الأصناف المتاحة للفرع بأرصدتها الحقيقية من المخزون
  Future<List<Map<String, dynamic>>> getAvailableItems({
    required String branchId,
  });
}
