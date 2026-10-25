enum StockMovementType { issue, receipt, transfer, adjustment }

class StockMovement {
  const StockMovement({
    required this.code,
    required this.itemName,
    required this.sku,
    required this.quantityLabel,
    required this.time,
    required this.description,
    required this.type,
    this.id,
    this.stockItemId,
    this.branchId,
    this.quantity,
    this.balanceAfter,
    this.createdAt,
    this.createdByUserId,
  });

  final String code;
  final String itemName;
  final String sku;
  final String quantityLabel;
  final String time;
  final String description;
  final StockMovementType type;
  final String? id;
  final String? stockItemId;
  final String? branchId;
  final double? quantity;
  final double? balanceAfter;
  final String? createdAt;
  final String? createdByUserId;
}
