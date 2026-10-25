import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/repositories/supply_repository.dart';
import '../datasources/supply_remote_data_source.dart';

class HttpSupplyRepository implements SupplyRepository {
  HttpSupplyRepository({
    SupplyRemoteDataSource? remoteDataSource,
    ApiClient? apiClient,
  }) : _remoteDataSource = remoteDataSource ??
            SupplyRemoteDataSourceImpl(
              apiClient: apiClient ??
                  (sl.isRegistered<ApiClient>() ? sl<ApiClient>() : ApiClient()),
            );

  final SupplyRemoteDataSource _remoteDataSource;

  // Active orders cache populated dynamically from Backend/SQLite
  final List<SupplyOrder> _cachedOrders = [];

  static String resolveStockItemId(String itemName) {
    final lower = itemName.toLowerCase();
    if (lower.contains('لحم') || lower.contains('beef')) return 'stock_ck_01';
    if (lower.contains('دجاج') || lower.contains('chicken') || lower.contains('فيليه')) return 'stock_ck_chick';
    if (lower.contains('زيت') || lower.contains('oil')) return 'stock_ck_02';
    if (lower.contains('خبز') || lower.contains('بريوش') || lower.contains('bun')) return 'stock_ck_06';
    if (lower.contains('بطاطس') || lower.contains('fries')) return 'stock_ck_05';
    if (lower.contains('شيدر') || lower.contains('جبن') || lower.contains('ched')) return 'stock_ck_04';
    if (lower.contains('صوص') || lower.contains('صلصة') || lower.contains('sauce')) return 'stock_ck_03';
    return 'stock_ck_01';
  }

  static String resolveBranchId(String branchName) {
    // Canonical branch lookup: match branch name first, then fallback to branch code
    if (branchName.contains('المعادي')) return 'br_02';
    if (branchName.contains('التجمع')) return 'br_03';
    if (branchName.contains('وسط البلد')) return 'br_01';
    if (branchName.contains('الشيخ زايد') || branchName.contains('المطبخ المركزي')) return 'br_04';
    if (branchName.contains('01')) return 'br_01';
    if (branchName.contains('02')) return 'br_02';
    if (branchName.contains('03')) return 'br_03';
    if (branchName.contains('04')) return 'br_04';
    return 'br_01';
  }

  @override
  Future<List<SupplyOrder>> getSupplyOrders({
    String? branchId,
    String? status,
    String? search,
  }) async {
    final remoteList = await _remoteDataSource.getSupplyOrders(
      branchId: branchId,
      status: status != null && status != 'الكل' ? SupplyOrder.toServerStatus(status) : null,
      search: search,
    );

    _cachedOrders.clear();
    if (remoteList.isNotEmpty) {
      final parsed = remoteList.map((m) => SupplyOrder.fromJson(m)).toList();
      _cachedOrders.addAll(parsed);
    }

    var result = List<SupplyOrder>.from(_cachedOrders);
    if (status != null && status.isNotEmpty && status != 'الكل') {
      final norm = SupplyOrder.normalizeStatus(status);
      result = result.where((o) => o.status == norm).toList();
    }
    if (branchId != null && branchId.isNotEmpty) {
      result = result
          .where((o) =>
              o.destinationBranchId == branchId ||
              o.branch.contains(branchId))
          .toList();
    }
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      result = result
          .where((o) =>
              o.id.toLowerCase().contains(q) ||
              o.orderNumber.toLowerCase().contains(q) ||
              o.branch.toLowerCase().contains(q) ||
              o.summary.toLowerCase().contains(q))
          .toList();
    }
    return List.unmodifiable(result);
  }

  @override
  Future<SupplyOrder?> getSupplyOrderById(String id) async {
    final remote = await _remoteDataSource.getSupplyOrderById(id);
    if (remote != null) {
      final order = SupplyOrder.fromJson(remote);
      final index = _cachedOrders.indexWhere((o) => o.id == id || o.orderNumber == id);
      if (index >= 0) {
        _cachedOrders[index] = order;
      } else {
        _cachedOrders.add(order);
      }
      return order;
    }
    return null;
  }

  @override
  Future<SupplyOrder> createSupplyOrder({
    required String branch,
    required String item,
    required int quantity,
    bool urgent = true,
    String? reason,
    String? destinationBranchId,
    String? sourceKitchenId,
    String? requestedDeliveryDate,
    List<SupplyOrderItem>? items,
  }) async {
    final destId = destinationBranchId ?? resolveBranchId(branch);
    final kitchenId = sourceKitchenId ?? 'br_04';
    final targetDeliveryDate = requestedDeliveryDate ??
        DateTime.now().add(const Duration(days: 1)).toIso8601String().substring(0, 10);
    final resolvedStockId = resolveStockItemId(item);

    final requestItems = items != null && items.isNotEmpty
        ? items
            .map((i) => {
                  'stockItemId': i.stockItemId.isNotEmpty && !i.stockItemId.startsWith('si_')
                      ? i.stockItemId
                      : resolveStockItemId(i.name),
                  'requestedQuantity': i.requestedQuantity,
                  if (i.unitCost > 0) 'unitCost': i.unitCost,
                  if (i.notes != null) 'notes': i.notes,
                })
            .toList()
        : [
            {
              'stockItemId': resolvedStockId,
              'requestedQuantity': quantity.toDouble(),
              'unitCost': 100.0,
              if (reason != null && reason.isNotEmpty) 'notes': reason,
            }
          ];

    final payload = {
      'destinationBranchId': destId,
      'destination_branch_id': destId,
      'sourceKitchenId': kitchenId,
      'source_kitchen_id': kitchenId,
      'requestedDeliveryDate': targetDeliveryDate,
      'requested_delivery_date': targetDeliveryDate,
      'status': 'pending',
      'urgent': urgent,
      'priority': urgent ? 'urgent' : 'normal',
      'notes': reason ?? '',
      'items': requestItems,
    };

    final remote = await _remoteDataSource.createSupplyOrder(payload);
    if (remote.isNotEmpty && remote['id'] != null) {
      final newOrder = SupplyOrder.fromJson(remote);
      _cachedOrders.insert(0, newOrder);
      return newOrder;
    }
    throw Exception('استجابة غير صحيحة من الخادم عند إنشاء طلب التوريد');
  }

  @override
  Future<bool> executeSupplyOrder(
    String orderId, {
    required String vehicle,
    required bool confirmed,
    String? driverName,
    String? driverPhone,
    String? notes,
    bool allowOverdraw = false,
    List<SupplyOrderItem>? items,
  }) async {
    final payload = {
      'order_id': orderId,
      'orderId': orderId,
      'vehicle': vehicle,
      'vehicle_info': vehicle,
      'vehicleInfo': vehicle,
      'confirmed': confirmed,
      'driver_name': driverName ?? 'أحمد رشوان',
      'driverName': driverName ?? 'أحمد رشوان',
      if (driverPhone != null) 'driver_phone': driverPhone,
      if (driverPhone != null) 'driverPhone': driverPhone,
      'notes': notes ?? '',
      'allow_overdraw': allowOverdraw,
      'allowOverdraw': allowOverdraw,
      'status': 'in_transit',
      if (items != null && items.isNotEmpty)
        'items': items
            .map((i) => {
                  if (i.id.isNotEmpty && !i.id.startsWith('item_')) 'itemId': i.id,
                  'stockItemId': i.stockItemId.isNotEmpty && !i.stockItemId.startsWith('si_')
                      ? i.stockItemId
                      : resolveStockItemId(i.name),
                  'dispatchedQuantity':
                      i.dispatchedQuantity ?? i.requestedQuantity,
                })
            .toList(),
    };

    final remote = await _remoteDataSource.executeSupplyOrder(orderId, payload);
    if (remote.isNotEmpty && remote['id'] != null) {
      final updated = SupplyOrder.fromJson(remote);
      final index = _cachedOrders.indexWhere(
        (o) => o.id == orderId || o.orderNumber == orderId,
      );
      if (index >= 0) {
        _cachedOrders[index] = updated;
      } else {
        _cachedOrders.insert(0, updated);
      }
      return true;
    }
    throw Exception('فشل صرف وتنفيذ طلب التوريد');
  }

  @override
  Future<bool> receiveSupplyOrder(
    String orderId, {
    required bool checked,
    bool hasShortage = false,
    String? shortageDetails,
    String? notes,
    double? temperatureCelsius,
    List<SupplyOrderItem>? items,
  }) async {
    final payload = {
      'order_id': orderId,
      'orderId': orderId,
      'checked': checked,
      'confirmed': checked,
      'has_shortage': hasShortage,
      'hasShortage': hasShortage,
      'shortage_details': shortageDetails ?? '',
      'shortageDetails': shortageDetails ?? '',
      'shortageNotes': shortageDetails ?? '',
      if (notes != null) 'notes': notes,
      if (temperatureCelsius != null) 'temperature_celsius': temperatureCelsius,
      if (temperatureCelsius != null) 'temperatureCelsius': temperatureCelsius,
      'status': 'received',
      if (items != null && items.isNotEmpty)
        'items': items
            .map((i) => {
                  if (i.id.isNotEmpty && !i.id.startsWith('item_')) 'itemId': i.id,
                  'stockItemId': i.stockItemId.isNotEmpty && !i.stockItemId.startsWith('si_')
                      ? i.stockItemId
                      : resolveStockItemId(i.name),
                  'receivedQuantity':
                      i.receivedQuantity ?? i.dispatchedQuantity ?? i.requestedQuantity,
                  'damagedQuantity': hasShortage ? 1.0 : 0.0,
                })
            .toList(),
    };

    final remote = await _remoteDataSource.receiveSupplyOrder(orderId, payload);
    if (remote.isNotEmpty && remote['id'] != null) {
      final updated = SupplyOrder.fromJson(remote);
      final index = _cachedOrders.indexWhere(
        (o) => o.id == orderId || o.orderNumber == orderId,
      );
      if (index >= 0) {
        _cachedOrders[index] = updated;
      } else {
        _cachedOrders.insert(0, updated);
      }
      return true;
    }
    throw Exception('فشل تأكيد استلام طلب التوريد');
  }

  @override
  Future<bool> rejectSupplyOrder(
    String orderId, {
    String? reason,
    String? userId,
  }) async {
    final remote = await _remoteDataSource.rejectSupplyOrder(
      orderId,
      reason: reason,
      userId: userId,
    );
    if (remote.isNotEmpty && remote['id'] != null) {
      final updated = SupplyOrder.fromJson(remote);
      final index = _cachedOrders.indexWhere(
        (o) => o.id == orderId || o.orderNumber == orderId,
      );
      if (index >= 0) {
        _cachedOrders[index] = updated;
      } else {
        _cachedOrders.insert(0, updated);
      }
      return true;
    }
    throw Exception('فشل رفض طلب التوريد');
  }
}
