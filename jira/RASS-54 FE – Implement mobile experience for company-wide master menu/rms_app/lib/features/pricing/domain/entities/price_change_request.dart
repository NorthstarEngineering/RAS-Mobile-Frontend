enum PriceRequestStatus {
  pending,
  approved,
  rejected;

  String get labelArabic {
    switch (this) {
      case PriceRequestStatus.pending:
        return 'قيد الانتظار';
      case PriceRequestStatus.approved:
        return 'معتمدة';
      case PriceRequestStatus.rejected:
        return 'مرفوضة';
    }
  }
}

class PriceChangeRequest {
  final String id;
  final String requestNumber;
  final String itemId;
  final String itemNameAr;
  final String itemNameEn;
  final String itemSku;
  final String categoryName;
  final double currentPrice;
  final double proposedPrice;
  final double cost;
  final String branchName;
  final String requestedByName;
  final DateTime requestDate;
  final PriceRequestStatus status;
  final String reason;
  final DateTime? effectiveDate;
  final double? approvedPrice;

  const PriceChangeRequest({
    required this.id,
    required this.requestNumber,
    required this.itemId,
    required this.itemNameAr,
    required this.itemNameEn,
    required this.itemSku,
    required this.categoryName,
    required this.currentPrice,
    required this.proposedPrice,
    required this.cost,
    required this.branchName,
    required this.requestedByName,
    required this.requestDate,
    this.status = PriceRequestStatus.pending,
    this.reason = '',
    this.effectiveDate,
    this.approvedPrice,
  });

  double get difference => proposedPrice - currentPrice;
  double get percentageChange => ((proposedPrice - currentPrice) / currentPrice) * 100;

  PriceChangeRequest copyWith({
    String? id,
    String? requestNumber,
    String? itemId,
    String? itemNameAr,
    String? itemNameEn,
    String? itemSku,
    String? categoryName,
    double? currentPrice,
    double? proposedPrice,
    double? cost,
    String? branchName,
    String? requestedByName,
    DateTime? requestDate,
    PriceRequestStatus? status,
    String? reason,
    DateTime? effectiveDate,
    double? approvedPrice,
  }) {
    return PriceChangeRequest(
      id: id ?? this.id,
      requestNumber: requestNumber ?? this.requestNumber,
      itemId: itemId ?? this.itemId,
      itemNameAr: itemNameAr ?? this.itemNameAr,
      itemNameEn: itemNameEn ?? this.itemNameEn,
      itemSku: itemSku ?? this.itemSku,
      categoryName: categoryName ?? this.categoryName,
      currentPrice: currentPrice ?? this.currentPrice,
      proposedPrice: proposedPrice ?? this.proposedPrice,
      cost: cost ?? this.cost,
      branchName: branchName ?? this.branchName,
      requestedByName: requestedByName ?? this.requestedByName,
      requestDate: requestDate ?? this.requestDate,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      approvedPrice: approvedPrice ?? this.approvedPrice,
    );
  }
}
