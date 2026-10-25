import '../entities/stock_item.dart';
import '../entities/stock_movement.dart';

class StockAdjustmentResult {
  const StockAdjustmentResult({
    required this.item,
    required this.movement,
    required this.previousBalance,
    required this.adjustedQuantity,
    required this.newBalance,
    required this.financialImpact,
  });

  final StockItem item;
  final StockMovement movement;
  final double previousBalance;
  final double adjustedQuantity;
  final double newBalance;
  final double financialImpact;
}

class CategoryValuation {
  const CategoryValuation({
    required this.category,
    required this.totalValue,
    required this.itemCount,
    required this.totalQuantity,
    required this.percentage,
  });

  final String category;
  final double totalValue;
  final int itemCount;
  final double totalQuantity;
  final double percentage;
}

class StockValuation {
  const StockValuation({
    required this.branchId,
    required this.branchName,
    required this.totalValuation,
    required this.totalItems,
    required this.criticalCount,
    required this.lowCount,
    required this.availableCount,
    required this.byCategory,
    required this.topItems,
  });

  final String branchId;
  final String branchName;
  final double totalValuation;
  final int totalItems;
  final int criticalCount;
  final int lowCount;
  final int availableCount;
  final List<CategoryValuation> byCategory;
  final List<StockItem> topItems;
}

abstract class InventoryRepository {
  /// استرجاع أرصدة وجرد المخزون لفرع محدد مع الفلاتر والبحث
  Future<List<StockItem>> getInventoryItems({
    String branchId = 'br_01',
    String? category,
    String? stockLevel,
    String? query,
  });

  /// جلب تفاصيل صنف مخزون محدد بمعرفه
  Future<StockItem?> getInventoryItemById(
    String id, {
    String? branchId,
  });

  /// تنفيذ تسوية مخزنية (عجز/هالك، فائض، تعديل رصيد) مع ترحيل فوري وحركة موثقة
  Future<StockAdjustmentResult> adjustStock({
    required String itemId,
    required double quantity,
    required String reason,
    String? branchId,
    String mode = 'deficit',
    String? notes,
    String? userId,
  });

  /// استعراض سجل الحركات المخزنية للفرع
  Future<List<StockMovement>> getStockMovements({
    String branchId = 'br_01',
    String? stockItemId,
    String? movementType,
    int limit = 50,
    int offset = 0,
  });

  /// استرجاع تقرير التقييم المالي للمخزون
  Future<StockValuation> getValuation({
    String branchId = 'br_01',
  });

  /// استرجاع قائمة الفروع النشطة للنظام عبر الخادم
  Future<List<Map<String, dynamic>>> getBranches();
}
