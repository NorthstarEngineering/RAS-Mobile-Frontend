import '../../../../core/network/api_client.dart';
import '../../domain/repositories/transfers_repository.dart';
import '../datasources/transfers_remote_data_source.dart';

class HttpTransfersRepository implements TransfersRepository {
  HttpTransfersRepository({
    TransfersRemoteDataSource? remoteDataSource,
    ApiClient? apiClient,
  }) : _remoteDataSource = remoteDataSource ??
            TransfersRemoteDataSourceImpl(apiClient: apiClient);

  final TransfersRemoteDataSource _remoteDataSource;

  static final HttpTransfersRepository instance = HttpTransfersRepository();

  // Dynamic operational cache populated exclusively from backend/SQLite
  final List<TransferOrder> _cachedOrders = [];

  List<TransferOrder> get cachedOrders => List.unmodifiable(_cachedOrders);

  static String _mapStatusToDisplay(String status) {
    switch (status.toLowerCase()) {
      case 'pending_review':
      case 'pending':
        return 'قيد المراجعة';
      case 'approved':
        return 'طلب وارد';
      case 'in_transit':
      case 'ready_to_receive':
        return 'جاهز للاستلام';
      case 'received':
      case 'completed':
        return 'مكتمل';
      case 'rejected':
        return 'مرفوض';
      default:
        return status;
    }
  }

  static String _mapBranchName(String branch) {
    if (branch.contains('(#')) return branch;
    switch (branch.toLowerCase()) {
      case 'br_01':
      case 'branch_01':
      case 'downtown':
        return 'وسط البلد (#01)';
      case 'br_02':
      case 'branch_02':
      case 'tagamoa':
        return 'التجمع الخامس (#02)';
      case 'br_03':
      case 'branch_03':
      case 'maadi':
        return 'المعادي (#03)';
      case 'br_04':
      case 'branch_04':
      case 'sheikh_zayed':
      case 'zayed':
        return 'الشيخ زايد (#04)';
      default:
        return branch;
    }
  }

  static TransferOrder _orderFromMap(Map<String, dynamic> map) {
    final transferCode = (map['transferCode'] ?? map['transfer_code'] ?? map['id'] ?? map['code'] ?? '').toString();
    final id = (map['id'] ?? map['transferCode'] ?? map['transfer_code'] ?? '').toString();

    final sourceRaw =
        map['sourceBranchName'] ?? map['source_branch_name'] ?? map['source'] ?? map['sourceBranchId'] ?? map['source_branch_id'] ?? '';
    final destRaw = map['destinationBranchName'] ??
        map['destination_branch_name'] ??
        map['destination'] ??
        map['destinationBranchId'] ??
        map['destination_branch_id'] ??
        '';

    final source = _mapBranchName(sourceRaw.toString());
    final destination = _mapBranchName(destRaw.toString());

    String item = 'صنف غير محدد';
    double qtyNum = 0.0;
    String unit = 'كجم';
    String? stockItemId;

    if (map['items'] is List && (map['items'] as List).isNotEmpty) {
      final firstItem = (map['items'] as List)[0];
      if (firstItem is Map) {
        item = (firstItem['name'] ?? firstItem['itemName'] ?? firstItem['item_name'] ?? 'صنف غير محدد').toString();
        final rawQ = firstItem['quantity'];
        qtyNum = (rawQ is num) ? rawQ.toDouble() : double.tryParse(rawQ.toString()) ?? 0.0;
        unit = (firstItem['unit'] ?? 'كجم').toString();
        stockItemId = (firstItem['stockItemId'] ?? firstItem['stock_item_id'])?.toString();
      }
    } else {
      item = (map['item_name'] ?? map['itemName'] ?? map['item'] ?? map['stock_item_name'] ?? 'صنف غير محدد').toString();
      final rawQ = map['quantity'] ?? map['totalQuantity'] ?? map['total_quantity'] ?? 0;
      qtyNum = (rawQ is num) ? rawQ.toDouble() : double.tryParse(rawQ.toString()) ?? 0.0;
      unit = (map['unit'] ?? 'كجم').toString();
      stockItemId = (map['stockItemId'] ?? map['stock_item_id'])?.toString();
    }

    final quantity = map['quantity_display']?.toString() ?? '$qtyNum $unit';

    final statusRaw = (map['status'] ?? 'pending_review').toString();
    final status = _mapStatusToDisplay(statusRaw);

    double? srcBal;
    double? destBal;
    final sb = map['sourceBalance'] ?? map['source_balance'];
    if (sb is num) srcBal = sb.toDouble();
    final db = map['destinationBalance'] ?? map['destination_balance'];
    if (db is num) destBal = db.toDouble();

    if (map['items'] is List && (map['items'] as List).isNotEmpty) {
      final firstItem = (map['items'] as List)[0];
      if (firstItem is Map) {
        if (srcBal == null) {
          final s = firstItem['availableQuantityAtSource'] ?? firstItem['available_quantity_at_source'];
          if (s is num) srcBal = s.toDouble();
        }
        if (destBal == null) {
          final d = firstItem['availableQuantityAtDestination'] ?? firstItem['available_quantity_at_destination'];
          if (d is num) destBal = d.toDouble();
        }
      }
    }

    return TransferOrder(
      id: transferCode.isNotEmpty ? transferCode : id,
      source: source,
      destination: destination,
      item: item,
      quantity: quantity,
      status: status,
      transferCode: transferCode,
      sourceBranchId: (map['sourceBranchId'] ?? map['source_branch_id'])?.toString(),
      destinationBranchId: (map['destinationBranchId'] ?? map['destination_branch_id'])?.toString(),
      stockItemId: stockItemId,
      driverName: (map['driverName'] ?? map['driver_name'])?.toString(),
      driverPhone: (map['driverPhone'] ?? map['driver_phone'])?.toString(),
      departureTime: (map['departureTime'] ?? map['departure_time'])?.toString(),
      arrivalTime: (map['arrivalTime'] ?? map['arrival_time'])?.toString(),
      notes: map['notes']?.toString(),
      createdAt: (map['createdAt'] ?? map['created_at'])?.toString(),
      updatedAt: (map['updatedAt'] ?? map['updated_at'])?.toString(),
      rawQuantity: qtyNum,
      receivedQuantity: ((map['receivedQuantity'] ?? map['received_quantity']) as num?)?.toDouble(),
      sourceBalance: srcBal,
      destinationBalance: destBal,
      unit: unit,
    );
  }

  @override
  Future<List<TransferPreviewOrder>> getTransfers({
    String? branchId,
    String? status,
    String? query,
  }) async {
    try {
      final remoteList = await _remoteDataSource.getTransfers(
        branchId: branchId,
        status: status,
        query: query,
      );
      if (remoteList.isNotEmpty) {
        final parsed = remoteList.map(_orderFromMap).toList();
        final existingIds = parsed.map((e) => e.id).toSet();
        final localOnly =
            _cachedOrders.where((e) => !existingIds.contains(e.id)).toList();
        _cachedOrders.clear();
        _cachedOrders.addAll([...parsed, ...localOnly]);
        return List.unmodifiable(_cachedOrders);
      }
    } catch (_) {
      // Graceful offline fallback
    }
    return List.unmodifiable(_cachedOrders);
  }

  @override
  Future<Map<String, int>> getTransferMetrics({String? branchId}) async {
    try {
      final remote = await _remoteDataSource.getTransferMetrics(branchId: branchId);
      if (remote.isNotEmpty) {
        return {
          'pendingReviewCount': ((remote['pendingReviewCount'] ?? remote['pending_review_count'] ?? 0) as num).toInt(),
          'inTransitCount': ((remote['inTransitCount'] ?? remote['in_transit_count'] ?? 0) as num).toInt(),
          'receivedCount': ((remote['receivedCount'] ?? remote['received_count'] ?? 0) as num).toInt(),
          'totalTransfers': ((remote['totalTransfers'] ?? remote['total_transfers'] ?? 0) as num).toInt(),
        };
      }
    } catch (_) {
      // Fallback
    }
    final pending = _cachedOrders.where((e) => e.status == 'قيد المراجعة' || e.status == 'طلب وارد').length;
    final inTransit = _cachedOrders.where((e) => e.status == 'جاهز للاستلام').length;
    final received = _cachedOrders.where((e) => e.status == 'مكتمل').length;
    return {
      'pendingReviewCount': pending,
      'inTransitCount': inTransit,
      'receivedCount': received,
      'totalTransfers': _cachedOrders.length,
    };
  }

  @override
  Future<TransferPreviewOrder?> getTransferById(String id) async {
    try {
      final remote = await _remoteDataSource.getTransferById(id);
      if (remote != null) {
        final order = _orderFromMap(remote);
        final index = _cachedOrders.indexWhere((e) => e.id == id || e.transferCode == id);
        if (index >= 0) {
          _cachedOrders[index] = order;
        } else {
          _cachedOrders.add(order);
        }
        return order;
      }
    } catch (_) {
      // Fallback
    }
    final match = _cachedOrders.where((e) => e.id == id || e.transferCode == id);
    return match.isNotEmpty ? match.first : null;
  }

  @override
  Future<TransferPreviewOrder> createTransfer({
    required String sourceBranch,
    required String destinationBranch,
    required String item,
    required double quantity,
    bool isUrgent = false,
    String? notes,
    String? sourceBranchId,
    String? destinationBranchId,
    String? stockItemId,
  }) async {
    final remote = await _remoteDataSource.createTransfer(
      sourceBranch: sourceBranch,
      destinationBranch: destinationBranch,
      item: item,
      quantity: quantity,
      isUrgent: isUrgent,
      notes: notes,
      sourceBranchId: sourceBranchId,
      destinationBranchId: destinationBranchId,
      stockItemId: stockItemId,
    );
    final remoteOrder = _orderFromMap(remote);
    _cachedOrders.insert(0, remoteOrder);
    return remoteOrder;
  }

  @override
  Future<TransferPreviewOrder> reviewTransfer({
    required String transferId,
    double? approvedQuantity,
    bool? approved,
    bool? approve,
    String? reason,
    String? notes,
    bool acknowledged = true,
  }) async {
    final effectiveApproved = approved ?? approve ?? true;
    final effectiveReason = reason ?? notes;
    final effectiveQty = approvedQuantity ?? 0.0;

    final remote = await _remoteDataSource.reviewTransfer(
      transferId: transferId,
      approvedQuantity: effectiveQty,
      approved: effectiveApproved,
      reason: effectiveReason,
      acknowledged: acknowledged,
    );
    final order = _orderFromMap(remote);
    final idx = _cachedOrders.indexWhere((e) => e.id == transferId || e.transferCode == transferId);
    if (idx >= 0) _cachedOrders[idx] = order;
    return order;
  }

  @override
  Future<TransferPreviewOrder> sendTransfer({
    required String transferId,
    String? vehicle,
    String? driverName,
    String? driverPhone,
    String? departureTime,
    double? temperature,
    String? notes,
  }) async {
    final effectiveVehicle = vehicle ?? 'سيارة نقل تبريد رقم 02';

    final remote = await _remoteDataSource.sendTransfer(
      transferId: transferId,
      vehicle: effectiveVehicle,
      driverName: driverName,
      driverPhone: driverPhone,
      temperature: temperature,
      notes: notes,
    );
    final order = _orderFromMap(remote);
    final idx = _cachedOrders.indexWhere((e) => e.id == transferId || e.transferCode == transferId);
    if (idx >= 0) _cachedOrders[idx] = order;
    return order;
  }

  @override
  Future<TransferPreviewOrder> receiveTransfer({
    required String transferId,
    double? acceptedQuantity,
    double? receivedQuantity,
    bool hasDamage = false,
    String? damageNotes,
    String? receivingNotes,
    bool acknowledged = true,
  }) async {
    final effectiveQty = acceptedQuantity ?? receivedQuantity ?? 0.0;
    final effectiveNotes = damageNotes ?? receivingNotes;

    final remote = await _remoteDataSource.receiveTransfer(
      transferId: transferId,
      acceptedQuantity: effectiveQty,
      hasDamage: hasDamage,
      damageNotes: effectiveNotes,
      acknowledged: acknowledged,
    );
    final order = _orderFromMap(remote);
    final idx = _cachedOrders.indexWhere((e) => e.id == transferId || e.transferCode == transferId);
    if (idx >= 0) _cachedOrders[idx] = order;
    return order;
  }

  @override
  Future<List<TransferPreviewOrder>> getTransferHistory({
    String? branchId,
    String? query,
  }) async {
    try {
      final remote = await _remoteDataSource.getTransferHistory(
        branchId: branchId,
        query: query,
      );
      if (remote.isNotEmpty) {
        return remote.map(_orderFromMap).toList();
      }
    } catch (_) {
      // Do not return synthetic dummy data
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getBranches() => _remoteDataSource.getBranches();

  @override
  Future<List<Map<String, dynamic>>> getAvailableItems({required String branchId}) =>
      _remoteDataSource.getAvailableItems(branchId: branchId);
}
