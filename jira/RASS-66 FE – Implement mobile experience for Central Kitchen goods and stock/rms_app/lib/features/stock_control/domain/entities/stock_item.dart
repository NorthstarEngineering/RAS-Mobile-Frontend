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
    this.branchId = 'br_01',
    this.updatedAt,
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
  final String branchId;
  final String? updatedAt;

  double get totalValue => quantity * unitCost;

  StockItem copyWith({
    String? id,
    String? name,
    String? sku,
    String? category,
    double? quantity,
    String? unit,
    double? unitCost,
    double? safetyStock,
    double? capacity,
    String? location,
    StockLevel? level,
    String? branchId,
    String? updatedAt,
  }) {
    return StockItem(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitCost: unitCost ?? this.unitCost,
      safetyStock: safetyStock ?? this.safetyStock,
      capacity: capacity ?? this.capacity,
      location: location ?? this.location,
      level: level ?? this.level,
      branchId: branchId ?? this.branchId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
