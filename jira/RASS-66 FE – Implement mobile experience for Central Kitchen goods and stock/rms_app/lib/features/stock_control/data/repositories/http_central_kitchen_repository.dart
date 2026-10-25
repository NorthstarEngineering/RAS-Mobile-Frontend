import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/central_kitchen_repository.dart';
import '../datasources/central_kitchen_remote_data_source.dart';

class HttpCentralKitchenRepository implements CentralKitchenRepository {
  HttpCentralKitchenRepository({
    CentralKitchenRemoteDataSource? remoteDataSource,
    ApiClient? apiClient,
  }) : _remoteDataSource = remoteDataSource ??
            CentralKitchenRemoteDataSourceImpl(
              apiClient: apiClient ??
                  (sl.isRegistered<ApiClient>() ? sl<ApiClient>() : null),
            );

  final CentralKitchenRemoteDataSource _remoteDataSource;

  final List<StockItem> _cachedItems = [];
  final List<StockMovement> _cachedMovements = [];

  @override
  Future<CentralKitchenDashboardData> getDashboardData() async {
    try {
      final remote = await _remoteDataSource.getDashboardData();
      if (remote.isNotEmpty) {
        double totalValue = 0.0;
        if (remote['totalStockValue'] != null) {
          totalValue = (remote['totalStockValue'] as num).toDouble();
        } else if (remote['total_stock_value'] != null) {
          totalValue = (remote['total_stock_value'] as num).toDouble();
        } else if (remote['stockValue'] != null) {
          totalValue = (remote['stockValue'] as num).toDouble();
        }

        int totalItemsCount = 0;
        if (remote['totalItemsCount'] != null) {
          totalItemsCount = (remote['totalItemsCount'] as num).toInt();
        } else if (remote['total_items_count'] != null) {
          totalItemsCount = (remote['total_items_count'] as num).toInt();
        } else if (remote['totalItems'] != null) {
          totalItemsCount = (remote['totalItems'] as num).toInt();
        }

        List<StockItem> critical = [];
        if (remote['criticalItems'] is List) {
          critical = (remote['criticalItems'] as List)
              .whereType<Map>()
              .map((e) => _itemFromMap(Map<String, dynamic>.from(e)))
              .toList();
        } else if (remote['critical_items'] is List) {
          critical = (remote['critical_items'] as List)
              .whereType<Map>()
              .map((e) => _itemFromMap(Map<String, dynamic>.from(e)))
              .toList();
        }

        List<StockMovement> recent = [];
        if (remote['recentMovements'] is List) {
          recent = (remote['recentMovements'] as List)
              .whereType<Map>()
              .map((e) => _movementFromMap(Map<String, dynamic>.from(e)))
              .toList();
        } else if (remote['recent_movements'] is List) {
          recent = (remote['recent_movements'] as List)
              .whereType<Map>()
              .map((e) => _movementFromMap(Map<String, dynamic>.from(e)))
              .toList();
        }

        if (critical.isNotEmpty) {
          for (final item in critical) {
            final idx = _cachedItems.indexWhere((i) => i.id == item.id);
            if (idx >= 0) {
              _cachedItems[idx] = item;
            } else {
              _cachedItems.add(item);
            }
          }
        }

        if (recent.isNotEmpty) {
          for (final m in recent) {
            final idx = _cachedMovements.indexWhere((x) => x.code == m.code);
            if (idx >= 0) {
              _cachedMovements[idx] = m;
            } else {
              _cachedMovements.insert(0, m);
            }
          }
        }

        return CentralKitchenDashboardData(
          totalStockValue: totalValue,
          totalItemsCount: totalItemsCount,
          criticalItems: critical,
          recentMovements: recent,
          depotCode: remote['depotCode']?.toString() ??
              remote['depot_code']?.toString() ??
              'CK-01',
          depotStatus: remote['depotStatus']?.toString() ??
              remote['depot_status']?.toString() ??
              'تشغيل نشط',
          depotName: remote['depotName']?.toString() ??
              remote['depot_name']?.toString() ??
              'موقع التصنيع والتوريد المركزي',
          depotSubtitle: remote['depotSubtitle']?.toString() ??
              remote['depot_subtitle']?.toString() ??
              'مخزون وتشغيل فقط • لا توجد مبيعات مباشرة',
          lastAuditTime: remote['lastAuditTime']?.toString() ??
              remote['last_audit_time']?.toString() ??
              'اليوم • 06:00 ص',
        );
      }
    } catch (_) {
      // Graceful offline fallback with true cached numbers
    }

    final double cachedTotal =
        _cachedItems.fold<double>(0.0, (acc, item) => acc + item.totalValue);
    return CentralKitchenDashboardData(
      totalStockValue: cachedTotal,
      totalItemsCount: _cachedItems.length,
      criticalItems:
          _cachedItems.where((i) => i.level == StockLevel.critical).toList(),
      recentMovements: _cachedMovements.take(3).toList(),
      depotCode: 'CK-01',
      depotStatus: 'تشغيل نشط',
      depotName: 'موقع التصنيع والتوريد المركزي',
      depotSubtitle: 'مخزون وتشغيل فقط • لا توجد مبيعات مباشرة',
      lastAuditTime: 'اليوم • 06:00 ص',
    );
  }

  @override
  Future<List<StockItem>> getItems({
    String? category,
    String? status,
    String? query,
  }) async {
    try {
      final remoteList = await _remoteDataSource.getItems(
        category: category,
        status: status,
        query: query,
      );
      final parsed = remoteList.map(_itemFromMap).toList();
      _cachedItems.clear();
      _cachedItems.addAll(parsed);
      return List.unmodifiable(parsed);
    } catch (_) {
      // Offline fallback
    }

    var filtered = List<StockItem>.from(_cachedItems);
    if (category != null && category != 'الكل' && category.isNotEmpty) {
      filtered = filtered.where((item) => item.category == category).toList();
    }
    if (status != null && status != 'الكل' && status.isNotEmpty) {
      final targetLevel = _parseStockLevel(status);
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
  Future<StockItem?> getItemById(String id) async {
    try {
      final remote = await _remoteDataSource.getItemById(id);
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
  Future<StockItem> createItem(StockItem item) async {
    final payload = <String, dynamic>{
      'id': item.id,
      'name': item.name,
      'sku': item.sku,
      'category': item.category,
      'quantity': item.quantity,
      'unit': item.unit,
      'unit_cost': item.unitCost,
      'unitCost': item.unitCost,
      'safety_stock': item.safetyStock,
      'safetyStock': item.safetyStock,
      'capacity': item.capacity,
      'location': item.location,
      'stock_level': item.level.name,
      'stockLevel': item.level.name,
      'branch_id': item.branchId == 'br_01' ? 'br_04' : item.branchId,
    };

    final remote = await _remoteDataSource.createItem(payload);
    final created = _itemFromMap(remote);
    _cachedItems.add(created);
    return created;
  }

  @override
  Future<StockItem> updateItem(String id, StockItem item) async {
    final payload = <String, dynamic>{
      'name': item.name,
      'sku': item.sku,
      'category': item.category,
      'quantity': item.quantity,
      'unit': item.unit,
      'unit_cost': item.unitCost,
      'unitCost': item.unitCost,
      'safety_stock': item.safetyStock,
      'safetyStock': item.safetyStock,
      'capacity': item.capacity,
      'location': item.location,
      'stock_level': item.level.name,
      'stockLevel': item.level.name,
      'branch_id': item.branchId == 'br_01' ? 'br_04' : item.branchId,
    };

    final remote = await _remoteDataSource.updateItem(id, payload);
    final updated = _itemFromMap(remote);
    final idx = _cachedItems.indexWhere((i) => i.id == id);
    if (idx >= 0) {
      _cachedItems[idx] = updated;
    } else {
      _cachedItems.add(updated);
    }
    return updated;
  }

  @override
  Future<List<StockMovement>> getMovements({
    String? filter,
    String? query,
    int? limit,
    int? offset,
  }) async {
    try {
      final remoteList = await _remoteDataSource.getMovements(
        filter: filter,
        query: query,
        limit: limit,
        offset: offset,
      );
      final parsed = remoteList.map(_movementFromMap).toList();
      _cachedMovements.clear();
      _cachedMovements.addAll(parsed);
      return List.unmodifiable(parsed);
    } catch (_) {
      // Offline fallback
    }

    var filtered = List<StockMovement>.from(_cachedMovements);
    if (filter != null && filter != 'الكل' && filter.isNotEmpty) {
      final targetType = _parseMovementType(filter);
      filtered = filtered.where((m) => m.type == targetType).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      filtered = filtered
          .where((m) =>
              m.code.toLowerCase().contains(q) ||
              m.itemName.toLowerCase().contains(q) ||
              m.sku.toLowerCase().contains(q))
          .toList();
    }
    return List.unmodifiable(filtered);
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
        branchId: map['branchId']?.toString() ??
            map['branch_id']?.toString() ??
            'br_04',
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
        quantity: ((map['quantity'] ?? 0) as num).toDouble(),
        balanceAfter: ((map['balanceAfter'] ?? map['balance_after'] ?? 0) as num)
            .toDouble(),
        branchId: (map['branchId'] ?? map['branch_id'])?.toString(),
        stockItemId: (map['stockItemId'] ?? map['stock_item_id'])?.toString(),
      );
}
