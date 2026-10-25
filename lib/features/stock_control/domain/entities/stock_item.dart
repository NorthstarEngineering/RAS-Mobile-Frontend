enum StockLevel { critical, low, available }

class StockItem {
  const StockItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.unitCost,
    required this.safetyStock,
    required this.capacity,
    required this.location,
    required this.level,
  });

  final String id;
  final String name;
  final String sku;
  final String category;
  final double quantity;
  final String unit;
  final double unitCost;
  final double safetyStock;
  final double capacity;
  final String location;
  final StockLevel level;

  double get totalValue => quantity * unitCost;
}
