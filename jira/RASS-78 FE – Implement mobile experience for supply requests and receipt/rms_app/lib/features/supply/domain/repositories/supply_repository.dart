class SupplyOrderItem {
  final String id;
  final String stockItemId;
  final String name;
  final double requestedQuantity;
  final double? dispatchedQuantity;
  final double? receivedQuantity;
  final String unit;
  final double unitCost;
  final String? subtitle;
  final String? notes;

  const SupplyOrderItem({
    required this.id,
    required this.stockItemId,
    required this.name,
    required this.requestedQuantity,
    this.dispatchedQuantity,
    this.receivedQuantity,
    this.unit = 'كجم',
    this.unitCost = 0.0,
    this.subtitle,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'stock_item_id': stockItemId,
    'stockItemId': stockItemId,
    'name': name,
    'requested_quantity': requestedQuantity,
    'requestedQuantity': requestedQuantity,
    'dispatched_quantity': dispatchedQuantity,
    'dispatchedQuantity': dispatchedQuantity,
    'received_quantity': receivedQuantity,
    'receivedQuantity': receivedQuantity,
    'unit': unit,
    'unit_cost': unitCost,
    'unitCost': unitCost,
    'subtitle': subtitle,
    'notes': notes,
  };

  factory SupplyOrderItem.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ??
        json['item_name']?.toString() ??
        json['itemName']?.toString() ??
        json['stock_item_name']?.toString() ??
        '';
    final requested = (json['requested_quantity'] ??
        json['requestedQuantity'] ??
        json['quantity'] ??
        0) as num;
    final dispatched = (json['dispatched_quantity'] ??
        json['dispatchedQuantity']) as num?;
    final received = (json['received_quantity'] ??
        json['receivedQuantity']) as num?;
    final cost = (json['unit_cost'] ?? json['unitCost'] ?? 0) as num;

    return SupplyOrderItem(
      id: json['id']?.toString() ?? '',
      stockItemId: json['stock_item_id']?.toString() ??
          json['stockItemId']?.toString() ??
          '',
      name: name,
      requestedQuantity: requested.toDouble(),
      dispatchedQuantity: dispatched?.toDouble(),
      receivedQuantity: received?.toDouble(),
      unit: json['unit']?.toString() ?? 'كجم',
      unitCost: cost.toDouble(),
      subtitle: json['subtitle']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

class SupplyOrder {
  final String id;
  final String orderNumber;
  final String branch;
  final String sourceKitchenId;
  final String sourceKitchenName;
  final String destinationBranchId;
  final String status;
  final String summary;
  final String time;
  final double totalCost;
  final String requestedDeliveryDate;
  final String? vehicle;
  final String? driverName;
  final String? driverPhone;
  final String? temperature;
  final List<SupplyOrderItem> items;

  const SupplyOrder({
    required this.id,
    this.orderNumber = '',
    required this.branch,
    this.sourceKitchenId = 'br_04',
    this.sourceKitchenName = 'المطبخ المركزي ومستودع الإمداد',
    this.destinationBranchId = 'br_01',
    required this.status,
    required this.summary,
    required this.time,
    this.totalCost = 0.0,
    this.requestedDeliveryDate = '',
    this.vehicle,
    this.driverName,
    this.driverPhone,
    this.temperature,
    this.items = const [],
  });

  static String normalizeStatus(String? rawStatus) {
    if (rawStatus == null || rawStatus.isEmpty) return 'قيد المراجعة';
    final s = rawStatus.toLowerCase().trim();
    if (s == 'in_transit' ||
        s == 'intransit' ||
        s == 'shipped' ||
        s.contains('شحن')) {
      return 'قيد الشحن';
    }
    if (s == 'received' || s == 'completed' || s.contains('استلام')) {
      return 'تم الاستلام';
    }
    if (s == 'preparing' || s.contains('تجهيز')) {
      return 'قيد التجهيز';
    }
    if (s == 'rejected' || s.contains('مرفوض') || s.contains('رفض')) {
      return 'مرفوض';
    }
    if (s == 'pending' || s == 'draft' || s.contains('مراجعة')) {
      return 'قيد المراجعة';
    }
    return rawStatus;
  }

  static String toServerStatus(String status) {
    switch (status) {
      case 'قيد الشحن':
        return 'in_transit';
      case 'تم الاستلام':
        return 'received';
      case 'قيد التجهيز':
        return 'preparing';
      case 'مرفوض':
        return 'rejected';
      case 'قيد المراجعة':
      default:
        return 'pending';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_number': orderNumber,
    'orderNumber': orderNumber,
    'branch': branch,
    'source_kitchen_id': sourceKitchenId,
    'sourceKitchenId': sourceKitchenId,
    'source_kitchen_name': sourceKitchenName,
    'sourceKitchenName': sourceKitchenName,
    'destination_branch_id': destinationBranchId,
    'destinationBranchId': destinationBranchId,
    'status': status,
    'summary': summary,
    'time': time,
    'total_cost': totalCost,
    'totalCost': totalCost,
    'requested_delivery_date': requestedDeliveryDate,
    'requestedDeliveryDate': requestedDeliveryDate,
    'vehicle': vehicle,
    'driver_name': driverName,
    'driverName': driverName,
    'driver_phone': driverPhone,
    'driverPhone': driverPhone,
    'temperature': temperature,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory SupplyOrder.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ??
        json['order_number']?.toString() ??
        json['orderNumber']?.toString() ??
        '';
    final rawNumber = json['order_number']?.toString() ??
        json['orderNumber']?.toString() ??
        rawId;
    final branchName = json['branch_name']?.toString() ??
        json['branch']?.toString() ??
        json['destination_branch_name']?.toString() ??
        json['destinationBranchName']?.toString() ??
        'فرع وسط البلد (#01)';
    final status = normalizeStatus(
      json['status_ar']?.toString() ?? json['status']?.toString(),
    );
    final rawSummary = json['summary']?.toString();
    final rawTime = json['time']?.toString() ??
        json['created_at']?.toString() ??
        json['createdAt']?.toString() ??
        'اليوم 10:30 ص';
    final cost = (json['total_cost'] ?? json['totalCost'] ?? 0) as num;

    final rawItems = json['items'];
    List<SupplyOrderItem> items = [];
    if (rawItems is List) {
      items = rawItems
          .whereType<Map>()
          .map((m) => SupplyOrderItem.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    final summary = rawSummary ??
        (items.isNotEmpty
            ? items.map((i) => '${i.name} ${i.requestedQuantity.toStringAsFixed(0)} ${i.unit}').join(' • ')
            : 'مواد ومستلزمات غذائية');

    return SupplyOrder(
      id: rawId,
      orderNumber: rawNumber,
      branch: branchName,
      sourceKitchenId: json['source_kitchen_id']?.toString() ??
          json['sourceKitchenId']?.toString() ??
          'br_04',
      sourceKitchenName: json['source_kitchen_name']?.toString() ??
          json['sourceKitchenName']?.toString() ??
          'المطبخ المركزي ومستودع الإمداد',
      destinationBranchId: json['destination_branch_id']?.toString() ??
          json['destinationBranchId']?.toString() ??
          'br_01',
      status: status,
      summary: summary,
      time: rawTime,
      totalCost: cost.toDouble(),
      requestedDeliveryDate: json['requested_delivery_date']?.toString() ??
          json['requestedDeliveryDate']?.toString() ??
          '',
      vehicle: json['vehicle']?.toString() ??
          json['vehicle_number']?.toString() ??
          json['vehicle_info']?.toString() ??
          json['vehicleInfo']?.toString(),
      driverName: json['driver_name']?.toString() ?? json['driverName']?.toString(),
      driverPhone: json['driver_phone']?.toString() ?? json['driverPhone']?.toString(),
      temperature: json['temperature']?.toString(),
      items: items,
    );
  }

  SupplyOrder copyWith({
    String? id,
    String? orderNumber,
    String? branch,
    String? sourceKitchenId,
    String? sourceKitchenName,
    String? destinationBranchId,
    String? status,
    String? summary,
    String? time,
    double? totalCost,
    String? requestedDeliveryDate,
    String? vehicle,
    String? driverName,
    String? driverPhone,
    String? temperature,
    List<SupplyOrderItem>? items,
  }) =>
      SupplyOrder(
        id: id ?? this.id,
        orderNumber: orderNumber ?? this.orderNumber,
        branch: branch ?? this.branch,
        sourceKitchenId: sourceKitchenId ?? this.sourceKitchenId,
        sourceKitchenName: sourceKitchenName ?? this.sourceKitchenName,
        destinationBranchId: destinationBranchId ?? this.destinationBranchId,
        status: status ?? this.status,
        summary: summary ?? this.summary,
        time: time ?? this.time,
        totalCost: totalCost ?? this.totalCost,
        requestedDeliveryDate:
            requestedDeliveryDate ?? this.requestedDeliveryDate,
        vehicle: vehicle ?? this.vehicle,
        driverName: driverName ?? this.driverName,
        driverPhone: driverPhone ?? this.driverPhone,
        temperature: temperature ?? this.temperature,
        items: items ?? this.items,
      );
}

abstract class SupplyRepository {
  Future<List<SupplyOrder>> getSupplyOrders({
    String? branchId,
    String? status,
    String? search,
  });

  Future<SupplyOrder?> getSupplyOrderById(String id);

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
  });

  Future<bool> executeSupplyOrder(
    String orderId, {
    required String vehicle,
    required bool confirmed,
    String? driverName,
    String? driverPhone,
    String? notes,
    bool allowOverdraw = false,
    List<SupplyOrderItem>? items,
  });

  Future<bool> receiveSupplyOrder(
    String orderId, {
    required bool checked,
    bool hasShortage = false,
    String? shortageDetails,
    String? notes,
    double? temperatureCelsius,
    List<SupplyOrderItem>? items,
  });

  Future<bool> rejectSupplyOrder(
    String orderId, {
    String? reason,
    String? userId,
  });
}
