enum MenuItemRequestStatus {
  pending,
  approved,
  rejected;

  String get labelArabic {
    switch (this) {
      case MenuItemRequestStatus.pending:
        return 'قيد المراجعة';
      case MenuItemRequestStatus.approved:
        return 'مقبول';
      case MenuItemRequestStatus.rejected:
        return 'مرفوض';
    }
  }
}

class MenuItemRequest {
  final String id;
  final String requestNumber;
  final String itemNameAr;
  final String itemNameEn;
  final String categoryName;
  final String? categoryId;
  final double proposedPrice;
  final double estimatedCost;
  final String branchName;
  final String? branchId;
  final String requestedByName;
  final DateTime requestDate;
  final MenuItemRequestStatus status;
  final String reason;
  final String notes;

  const MenuItemRequest({
    required this.id,
    required this.requestNumber,
    required this.itemNameAr,
    required this.itemNameEn,
    required this.categoryName,
    this.categoryId,
    required this.proposedPrice,
    required this.estimatedCost,
    required this.branchName,
    this.branchId,
    required this.requestedByName,
    required this.requestDate,
    this.status = MenuItemRequestStatus.pending,
    this.reason = '',
    this.notes = '',
  });

  MenuItemRequest copyWith({
    String? id,
    String? requestNumber,
    String? itemNameAr,
    String? itemNameEn,
    String? categoryName,
    String? categoryId,
    double? proposedPrice,
    double? estimatedCost,
    String? branchName,
    String? branchId,
    String? requestedByName,
    DateTime? requestDate,
    MenuItemRequestStatus? status,
    String? reason,
    String? notes,
  }) {
    return MenuItemRequest(
      id: id ?? this.id,
      requestNumber: requestNumber ?? this.requestNumber,
      itemNameAr: itemNameAr ?? this.itemNameAr,
      itemNameEn: itemNameEn ?? this.itemNameEn,
      categoryName: categoryName ?? this.categoryName,
      categoryId: categoryId ?? this.categoryId,
      proposedPrice: proposedPrice ?? this.proposedPrice,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      branchName: branchName ?? this.branchName,
      branchId: branchId ?? this.branchId,
      requestedByName: requestedByName ?? this.requestedByName,
      requestDate: requestDate ?? this.requestDate,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
    );
  }
}
