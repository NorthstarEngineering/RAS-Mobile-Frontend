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
  });

  final String code;
  final String itemName;
  final String sku;
  final String quantityLabel;
  final String time;
  final String description;
  final StockMovementType type;
}
