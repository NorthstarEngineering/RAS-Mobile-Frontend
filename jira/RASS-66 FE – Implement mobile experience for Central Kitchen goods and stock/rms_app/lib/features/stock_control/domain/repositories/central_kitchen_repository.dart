import '../entities/stock_item.dart';
import '../entities/stock_movement.dart';

class CentralKitchenDashboardData {
  const CentralKitchenDashboardData({
    required this.totalStockValue,
    required this.totalItemsCount,
    required this.criticalItems,
    required this.recentMovements,
    this.depotCode = 'Depot-01',
    this.depotStatus = 'تشغيل نشط',
    this.depotName = 'موقع التصنيع والتوريد المركزي',
    this.depotSubtitle = 'مخزون وتشغيل فقط • لا توجد مبيعات مباشرة',
    this.lastAuditTime = 'اليوم • 06:00 ص',
  });

  final double totalStockValue;
  final int totalItemsCount;
  final List<StockItem> criticalItems;
  final List<StockMovement> recentMovements;
  final String depotCode;
  final String depotStatus;
  final String depotName;
  final String depotSubtitle;
  final String lastAuditTime;
}

abstract class CentralKitchenRepository {
  Future<CentralKitchenDashboardData> getDashboardData();

  Future<List<StockItem>> getItems({
    String? category,
    String? status,
    String? query,
  });

  Future<StockItem?> getItemById(String id);

  Future<StockItem> createItem(StockItem item);

  Future<StockItem> updateItem(String id, StockItem item);

  Future<List<StockMovement>> getMovements({
    String? filter,
    String? query,
    int? limit,
    int? offset,
  });
}
