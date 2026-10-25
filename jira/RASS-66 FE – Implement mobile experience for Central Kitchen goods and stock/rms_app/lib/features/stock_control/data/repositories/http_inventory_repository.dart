import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_remote_data_source.dart';

class HttpInventoryRepository implements InventoryRepository {
  HttpInventoryRepository({
    InventoryRemoteDataSource? remoteDataSource,
    ApiClient? apiClient,
  }) : _remoteDataSource = remoteDataSource ??
            InventoryRemoteDataSourceImpl(
              apiClient: apiClient ??
                  (sl.isRegistered<ApiClient>() ? sl<ApiClient>() : null),
            );

  final InventoryRemoteDataSource _remoteDataSource;

  final List<StockItem> _cachedItems = [];
  final List<StockMovement> _cachedMovements = [];

  @override
  Future<List<StockItem>> getInventoryItems({
    String branchId = 'br_01',
    String? category,
    String? stockLevel,
    String? query,
  }) async {
    try {
      final remoteList = await _remoteDataSource.getInventory(
        branchId: branchId,
        category: category,
        stockLevel: stockLevel,
        query: query,
      );
      final parsed = remoteList.map(_itemFromMap).toList();
      _cachedItems.removeWhere((i) => i.branchId == branchId);
      _cachedItems.addAll(parsed);
      return List.unmodifiable(parsed);
    } catch (_) {
      // Graceful offline fallback from local cache
    }

    var filtered = List<StockItem>.from(_cachedItems);
    if (branchId.isNotEmpty && branchId != 'all') {
      filtered = filtered
          .where((item) => item.branchId == branchId)
          .toList();
    }
    if (category != null && category != 'الكل' && category.isNotEmpty) {
      filtered = filtered.where((item) => item.category == category).toList();
    }
    if (stockLevel != null && stockLevel != 'الكل' && stockLevel.isNotEmpty) {
      final targetLevel = _parseStockLevel(stockLevel);
      filtered = filtered.where((item) => item.level == targetLevel).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      filtered = filtered
          .where((item) =>
              item.name.toLowerCase().contains(q) ||
              item.sku.toLowerCase().contains(q))
          .toList();
    }
    return List.unmodifiable(filtered);
  }

  @override
  Future<StockItem?> getInventoryItemById(
    String id, {
    String? branchId,
  }) async {
    try {
      final remote = await _remoteDataSource.getInventoryItem(
        id,
        branchId: branchId,
      );
      if (remote != null) {
        final item = _itemFromMap(remote);
        final idx = _cachedItems.indexWhere((i) => i.id == id);
        if (idx >= 0) {
          _cachedItems[idx] = item;
        } else {
          _cachedItems.add(item);
        }
        return item;
      }
    } catch (_) {
      // Offline fallback
    }

    final idx = _cachedItems.indexWhere((i) => i.id == id);
    if (idx >= 0) {
      return _cachedItems[idx];
    }
    return null;
  }

  @override
  Future<StockAdjustmentResult> adjustStock({
    required String itemId,
    required double quantity,
    required String reason,
    String? branchId,
    String mode = 'deficit',
    String? notes,
    String? userId,
  }) async {
    // Resolve branchId without defaulting kitchen items to br_01
    final effectiveBranch = branchId ??
        (itemId.startsWith('ck')
            ? 'br_04'
            : (_cachedItems.any((i) => i.id == itemId)
                ? _cachedItems.firstWhere((i) => i.id == itemId).branchId
                : null));

    final payload = <String, dynamic>{
      'itemId': itemId,
      if (effectiveBranch != null && effectiveBranch.isNotEmpty)
        'branchId': effectiveBranch,
      'mode': mode,
      'quantity': quantity,
      'reason': reason,
      'notes': notes ?? '',
      'userId': userId ?? 'usr_bm1',
    };

    final res = await _remoteDataSource.adjustStock(payload);
    final itemMap = Map<String, dynamic>.from(res['item'] as Map);
    final movMap = Map<String, dynamic>.from(res['movement'] as Map);
    final updatedItem = _itemFromMap(itemMap);
    final movement = _movementFromMap(movMap);

    final idx = _cachedItems.indexWhere((i) => i.id == updatedItem.id);
    if (idx >= 0) {
      _cachedItems[idx] = updatedItem;
    } else {
      _cachedItems.add(updatedItem);
    }
    _cachedMovements.insert(0, movement);

    return StockAdjustmentResult(
      item: updatedItem,
      movement: movement,
      previousBalance:
          ((res['previousBalance'] ?? res['previous_balance'] ?? 0) as num)
              .toDouble(),
      adjustedQuantity:
          ((res['adjustedQuantity'] ?? res['adjusted_quantity'] ?? 0) as num)
              .toDouble(),
      newBalance: ((res['newBalance'] ?? res['new_balance'] ?? 0) as num)
          .toDouble(),
      financialImpact:
          ((res['financialImpact'] ?? res['financial_impact'] ?? 0) as num)
              .toDouble(),
    );
  }

  @override
  Future<List<StockMovement>> getStockMovements({
    String branchId = 'br_01',
    String? stockItemId,
    String? movementType,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final remoteList = await _remoteDataSource.getStockMovements(
        branchId: branchId,
        stockItemId: stockItemId,
        movementType: movementType,
        limit: limit,
        offset: offset,
      );
      final parsed = remoteList.map(_movementFromMap).toList();
      _cachedMovements.removeWhere((m) => m.branchId == branchId);
      _cachedMovements.addAll(parsed);
      return List.unmodifiable(parsed);
    } catch (_) {
      // Offline fallback
    }

    var filtered = List<StockMovement>.from(_cachedMovements);
    if (stockItemId != null && stockItemId.isNotEmpty) {
      filtered = filtered
          .where((m) => m.stockItemId == stockItemId || m.sku.contains(stockItemId))
          .toList();
    }
    if (movementType != null &&
        movementType != 'الكل' &&
        movementType.isNotEmpty) {
      final targetType = _parseMovementType(movementType);
      filtered = filtered.where((m) => m.type == targetType).toList();
    }
    return List.unmodifiable(filtered);
  }

  @override
  Future<StockValuation> getValuation({
    String branchId = 'br_01',
  }) async {
    try {
      final remote = await _remoteDataSource.getValuation(branchId: branchId);
      if (remote.isNotEmpty) {
        final totalVal = ((remote['totalValuation'] ??
                remote['total_valuation'] ??
                remote['totalValue'] ??
                0) as num)
            .toDouble();
        final totalItems = ((remote['totalItems'] ??
                remote['total_items'] ??
                remote['itemsCount'] ??
                0) as num)
            .toInt();
        final critCount = ((remote['criticalCount'] ??
                remote['critical_count'] ??
                0) as num)
            .toInt();
        final lowCount =
            ((remote['lowCount'] ?? remote['low_count'] ?? 0) as num).toInt();
        final availCount = ((remote['availableCount'] ??
                remote['available_count'] ??
                0) as num)
            .toInt();

        final branchName = (remote['branchName'] ??
                remote['branch_name'] ??
                'الفرع ($branchId)')
            .toString();

        List<CategoryValuation> categories = [];
        if (remote['byCategory'] is List) {
          categories = (remote['byCategory'] as List)
              .whereType<Map>()
              .map((c) => CategoryValuation(
                    category: c['category']?.toString() ?? '',
                    totalValue:
                        ((c['totalValue'] ?? c['total_val'] ?? 0) as num)
                            .toDouble(),
                    itemCount:
                        ((c['itemCount'] ?? c['cat_items'] ?? 0) as num).toInt(),
                    totalQuantity:
                        ((c['totalQuantity'] ?? c['cat_qty'] ?? 0) as num)
                            .toDouble(),
                    percentage:
                        ((c['percentage'] ?? c['pct'] ?? 0) as num).toDouble(),
                  ))
              .toList();
        }

        List<StockItem> topItems = [];
        if (remote['topItems'] is List) {
          topItems = (remote['topItems'] as List)
              .whereType<Map>()
              .map((it) => _itemFromMap(Map<String, dynamic>.from(it)))
              .toList();
        }

        return StockValuation(
          branchId: branchId,
          branchName: branchName,
          totalValuation: totalVal,
          totalItems: totalItems,
          criticalCount: critCount,
          lowCount: lowCount,
          availableCount: availCount,
          byCategory: categories,
          topItems: topItems,
        );
      }
    } catch (_) {
      // Offline fallback calculation from cached items
    }

    final branchItems = _cachedItems
        .where((i) => i.branchId == branchId)
        .toList();

    double total = 0.0;
    int crit = 0;
    int low = 0;
    int avail = 0;
    final Map<String, List<StockItem>> grouped = {};

    for (final it in branchItems) {
      total += it.totalValue;
      if (it.level == StockLevel.critical) crit++;
      if (it.level == StockLevel.low) low++;
      if (it.level == StockLevel.available) avail++;
      grouped.putIfAbsent(it.category, () => []).add(it);
    }

    final catVals = grouped.entries.map((e) {
      final catTotal = e.value.fold<double>(0.0, (acc, x) => acc + x.totalValue);
      final catQty = e.value.fold<double>(0.0, (acc, x) => acc + x.quantity);
      final pct = total > 0 ? (catTotal / total) * 100.0 : 0.0;
      return CategoryValuation(
        category: e.key,
        totalValue: catTotal,
        itemCount: e.value.length,
        totalQuantity: catQty,
        percentage: pct,
      );
    }).toList();

    final sortedItems = List<StockItem>.from(branchItems)
      ..sort((a, b) => b.totalValue.compareTo(a.totalValue));

    return StockValuation(
      branchId: branchId,
      branchName: 'الفرع ($branchId)',
      totalValuation: total,
      totalItems: branchItems.length,
      criticalCount: crit,
      lowCount: low,
      availableCount: avail,
      byCategory: catVals,
      topItems: sortedItems.take(5).toList(),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getBranches() async {
    return _remoteDataSource.getBranches();
  }

  static StockLevel _parseStockLevel(dynamic val) {
    final s = val?.toString().toLowerCase().trim() ?? '';
    if (s == 'critical' || s == 'حرج') return StockLevel.critical;
    if (s == 'low' || s == 'منخفض' || s == 'مخزون منخفض') {
      return StockLevel.low;
    }
    return StockLevel.available;
  }

  static StockMovementType _parseMovementType(dynamic val) {
    final s = val?.toString().toLowerCase().trim() ?? '';
    if (s == 'issue' || s == 'صرف') return StockMovementType.issue;
    if (s == 'receipt' || s == 'توريد' || s == 'استلام') {
      return StockMovementType.receipt;
    }
    if (s == 'transfer' || s == 'تحويل' || s == 'نقل') {
      return StockMovementType.transfer;
    }
    return StockMovementType.adjustment;
  }

  static StockItem _itemFromMap(Map<String, dynamic> map) => StockItem(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        sku: map['sku']?.toString() ?? '',
        category: map['category']?.toString() ?? '',
        quantity: ((map['quantity'] ?? 0) as num).toDouble(),
        unit: map['unit']?.toString() ?? 'كجم',
        unitCost:
            ((map['unitCost'] ?? map['unit_cost'] ?? 0) as num).toDouble(),
        safetyStock:
            ((map['safetyStock'] ?? map['safety_stock'] ?? 0) as num)
                .toDouble(),
        capacity: ((map['capacity'] ?? 0) as num).toDouble(),
        location: map['location']?.toString() ?? '',
        level: _parseStockLevel(
            map['level'] ?? map['stockLevel'] ?? map['stock_level']),
        branchId: map['branchId']?.toString() ??
            map['branch_id']?.toString() ??
            'br_01',
        updatedAt: (map['updatedAt'] ?? map['updated_at'])?.toString(),
      );

  static StockMovement _movementFromMap(Map<String, dynamic> map) =>
      StockMovement(
        code: map['code']?.toString() ?? '',
        itemName: (map['itemName'] ?? map['item_name'] ?? map['name'])
                ?.toString() ??
            '',
        sku: map['sku']?.toString() ?? '',
        quantityLabel: (map['quantityLabel'] ?? map['quantity_label'])
                ?.toString() ??
            '${map['quantity'] ?? 0} ${map['unit'] ?? ''}',
        time: (map['time'] ?? map['created_at'])?.toString() ?? '',
        description: map['description']?.toString() ?? '',
        type: _parseMovementType(
            map['type'] ?? map['movementType'] ?? map['movement_type']),
        id: map['id']?.toString(),
        stockItemId: (map['stockItemId'] ?? map['stock_item_id'])?.toString(),
        branchId: (map['branchId'] ?? map['branch_id'])?.toString(),
        quantity: map['quantity'] != null
            ? ((map['quantity'] as num).toDouble())
            : null,
        balanceAfter: (map['balanceAfter'] ?? map['balance_after']) != null
            ? ((map['balanceAfter'] ?? map['balance_after']) as num).toDouble()
            : null,
        createdAt: (map['createdAt'] ?? map['created_at'])?.toString(),
        createdByUserId: (map['createdByUserId'] ?? map['created_by_user_id'])
            ?.toString(),
      );
}
