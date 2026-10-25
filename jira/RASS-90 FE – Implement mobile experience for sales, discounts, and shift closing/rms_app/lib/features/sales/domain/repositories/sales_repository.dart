import 'package:equatable/equatable.dart';

/// Domain entities and repository contract for RMS Sales, Shifts, and Discounts.

// ============================================================================
// Shift Status & Channel Metric Entities
// ============================================================================

class ShiftStatusData extends Equatable {
  const ShiftStatusData({
    required this.branchName,
    required this.shiftName,
    required this.timeRange,
    required this.managerName,
    required this.isOpen,
    required this.description,
  });

  factory ShiftStatusData.fromJson(Map<String, dynamic> json) => ShiftStatusData(
        branchName: json['branch_name'] as String? ?? json['branchName'] as String? ?? 'فرع وسط البلد (#01)',
        shiftName: json['shift_name'] as String? ?? json['shiftName'] as String? ?? json['title'] as String? ?? 'الوردية الصباحية',
        timeRange: json['time_range'] as String? ?? json['timeRange'] as String? ?? '08:00 ص — 04:00 م',
        managerName: json['manager_name'] as String? ?? json['managerName'] as String? ?? 'م. ألفاريز',
        isOpen: (json['is_open'] ?? json['isOpen'] ?? true) as bool,
        description: json['description'] as String? ?? json['subtitle'] as String? ??
            'فرع وسط البلد (#01) • الوردية الصباحية • بدأت اليوم 08:00 ص',
      );

  final String branchName;
  final String shiftName;
  final String timeRange;
  final String managerName;
  final bool isOpen;
  final String description;

  Map<String, dynamic> toJson() => {
        'branch_name': branchName,
        'shift_name': shiftName,
        'time_range': timeRange,
        'manager_name': managerName,
        'is_open': isOpen,
        'description': description,
      };

  @override
  List<Object?> get props => [
        branchName,
        shiftName,
        timeRange,
        managerName,
        isOpen,
        description,
      ];
}

class ChannelMetricData extends Equatable {
  const ChannelMetricData({
    required this.channelKey,
    required this.title,
    required this.orderCount,
    required this.totalAmount,
    required this.percentage,
    required this.subtitle,
  });

  factory ChannelMetricData.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as String? ?? '';
    final count = (json['order_count'] ?? json['orderCount'] ?? 0) as int;
    final total = ((json['total_amount'] ?? json['totalAmount'] ?? 0.0) as num).toDouble();
    final pct = ((json['percentage'] ?? 0.0) as num).toDouble();
    final sub = json['subtitle'] as String? ??
        '$count طلب • ${total.toStringAsFixed(0)} ج.م • ${pct.toStringAsFixed(1)}%';
    return ChannelMetricData(
      channelKey: json['channel_key'] as String? ?? json['channelKey'] as String? ?? '',
      title: title,
      orderCount: count,
      totalAmount: total,
      percentage: pct,
      subtitle: sub,
    );
  }

  final String channelKey;
  final String title;
  final int orderCount;
  final double totalAmount;
  final double percentage;
  final String subtitle;

  Map<String, dynamic> toJson() => {
        'channel_key': channelKey,
        'title': title,
        'order_count': orderCount,
        'total_amount': totalAmount,
        'percentage': percentage,
        'subtitle': subtitle,
      };

  @override
  List<Object?> get props => [
        channelKey,
        title,
        orderCount,
        totalAmount,
        percentage,
        subtitle,
      ];
}

// ============================================================================
// Sales Dashboard Data
// ============================================================================

class SalesDashboardData extends Equatable {
  const SalesDashboardData({
    required this.shiftStatus,
    required this.totalSales,
    required this.netSales,
    required this.totalDiscounts,
    required this.totalOrders,
    required this.dineInRatio,
    required this.deliveryRatio,
    required this.channels,
    this.activeShiftId,
  });

  factory SalesDashboardData.fromJson(Map<String, dynamic> json) {
    final statusRaw = json['shift_status'] ?? json['shiftStatus'];
    final ShiftStatusData status;
    if (statusRaw is Map<String, dynamic>) {
      status = ShiftStatusData.fromJson(statusRaw);
    } else if (statusRaw is String) {
      status = ShiftStatusData(
        branchName: 'فرع وسط البلد (#01)',
        shiftName: 'الوردية الصباحية',
        timeRange: '08:00 ص — 04:00 م',
        managerName: 'م. ألفاريز',
        isOpen: true,
        description: statusRaw,
      );
    } else {
      status = const ShiftStatusData(
        branchName: 'فرع وسط البلد (#01)',
        shiftName: 'الوردية الصباحية',
        timeRange: '08:00 ص — 04:00 م',
        managerName: 'م. ألفاريز',
        isOpen: true,
        description: 'فرع وسط البلد (#01) • الوردية الصباحية • بدأت اليوم 08:00 ص',
      );
    }

    final rawChannels = json['channels'] as List? ?? [];
    final parsedChannels = rawChannels
        .whereType<Map<String, dynamic>>()
        .map(ChannelMetricData.fromJson)
        .toList();

    return SalesDashboardData(
      shiftStatus: status,
      totalSales: ((json['total_sales'] ?? json['totalSales'] ?? 0.0) as num).toDouble(),
      netSales: ((json['net_sales'] ?? json['netSales'] ?? 0.0) as num).toDouble(),
      totalDiscounts: ((json['total_discounts'] ?? json['totalDiscounts'] ?? 0.0) as num).toDouble(),
      totalOrders: ((json['total_orders'] ?? json['totalOrders'] ?? 0) as num).toInt(),
      dineInRatio: ((json['dine_in_ratio'] ?? json['dineInRatio'] ?? 0.0) as num).toDouble(),
      deliveryRatio: ((json['delivery_ratio'] ?? json['deliveryRatio'] ?? 0.0) as num).toDouble(),
      channels: parsedChannels,
      activeShiftId: json['active_shift_id'] as String? ?? json['activeShiftId'] as String? ?? (statusRaw is Map ? statusRaw['shiftId'] as String? : null),
    );
  }

  final ShiftStatusData shiftStatus;
  final double totalSales;
  final double netSales;
  final double totalDiscounts;
  final int totalOrders;
  final double dineInRatio;
  final double deliveryRatio;
  final List<ChannelMetricData> channels;
  final String? activeShiftId;

  Map<String, dynamic> toJson() => {
        'shift_status': shiftStatus.toJson(),
        'total_sales': totalSales,
        'net_sales': netSales,
        'total_discounts': totalDiscounts,
        'total_orders': totalOrders,
        'dine_in_ratio': dineInRatio,
        'delivery_ratio': deliveryRatio,
        'channels': channels.map((c) => c.toJson()).toList(),
        'active_shift_id': activeShiftId,
      };

  @override
  List<Object?> get props => [
        shiftStatus,
        totalSales,
        netSales,
        totalDiscounts,
        totalOrders,
        dineInRatio,
        deliveryRatio,
        channels,
        activeShiftId,
      ];
}

// ============================================================================
// Restaurant Sales Entities
// ============================================================================

class RestaurantItemData extends Equatable {
  const RestaurantItemData({
    this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
  });

  factory RestaurantItemData.fromJson(Map<String, dynamic> json) => RestaurantItemData(
        id: json['id'] as String?,
        name: json['name'] as String? ?? json['name_ar'] as String? ?? '',
        sku: json['sku'] as String? ?? '',
        category: json['category'] as String? ?? '',
        quantity: ((json['quantity'] ?? 0) as num).toInt(),
        unitPrice: ((json['unit_price'] ?? json['unitPrice'] ?? 0.0) as num).toDouble(),
        totalAmount: ((json['total_amount'] ?? json['totalAmount'] ?? 0.0) as num).toDouble(),
      );

  final String? id;
  final String name;
  final String sku;
  final String category;
  final int quantity;
  final double unitPrice;
  final double totalAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sku': sku,
        'category': category,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_amount': totalAmount,
      };

  @override
  List<Object?> get props => [id, name, sku, category, quantity, unitPrice, totalAmount];
}

class RestaurantSalesData extends Equatable {
  const RestaurantSalesData({
    required this.totalSales,
    required this.totalOrders,
    required this.categories,
    required this.items,
  });

  factory RestaurantSalesData.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    final parsedItems = rawItems
        .whereType<Map<String, dynamic>>()
        .map(RestaurantItemData.fromJson)
        .toList();
    final rawCategories = json['categories'] as List? ?? [];
    final parsedCategories = rawCategories.map((c) => c.toString()).toList();

    return RestaurantSalesData(
      totalSales: ((json['total_sales'] ?? json['totalSales'] ?? 0.0) as num).toDouble(),
      totalOrders: ((json['total_orders'] ?? json['totalOrders'] ?? 0) as num).toInt(),
      categories: parsedCategories.isNotEmpty
          ? parsedCategories
          : const ['الكل', 'البرجر', 'الدجاج والمقبلات', 'المشروبات'],
      items: parsedItems,
    );
  }

  final double totalSales;
  final int totalOrders;
  final List<String> categories;
  final List<RestaurantItemData> items;

  @override
  List<Object?> get props => [totalSales, totalOrders, categories, items];
}

// ============================================================================
// Delivery Sales Entities
// ============================================================================

class DeliveryOrderItemData extends Equatable {
  const DeliveryOrderItemData({
    this.id,
    required this.title,
    required this.sku,
    required this.channel,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
  });

  factory DeliveryOrderItemData.fromJson(Map<String, dynamic> json) => DeliveryOrderItemData(
        id: json['id'] as String?,
        title: json['title'] as String? ?? json['name_ar'] as String? ?? '',
        sku: json['sku'] as String? ?? '',
        channel: json['channel'] as String? ?? '',
        quantity: ((json['quantity'] ?? 0) as num).toInt(),
        unitPrice: ((json['unit_price'] ?? json['unitPrice'] ?? 0.0) as num).toDouble(),
        totalAmount: ((json['total_amount'] ?? json['totalAmount'] ?? 0.0) as num).toDouble(),
      );

  final String? id;
  final String title;
  final String sku;
  final String channel;
  final int quantity;
  final double unitPrice;
  final double totalAmount;

  @override
  List<Object?> get props => [id, title, sku, channel, quantity, unitPrice, totalAmount];
}

class DeliverySalesData extends Equatable {
  const DeliverySalesData({
    required this.totalRevenue,
    required this.totalOrders,
    required this.channels,
    required this.orders,
    required this.reconciliation,
  });

  factory DeliverySalesData.fromJson(Map<String, dynamic> json) {
    final rawOrders = json['orders'] as List? ?? [];
    final parsedOrders = rawOrders
        .whereType<Map<String, dynamic>>()
        .map(DeliveryOrderItemData.fromJson)
        .toList();
    final rawChannels = json['channels'] as List? ?? [];
    final parsedChannels = rawChannels.map((c) => c.toString()).toList();

    return DeliverySalesData(
      totalRevenue: ((json['total_revenue'] ?? json['totalRevenue'] ?? 0.0) as num).toDouble(),
      totalOrders: ((json['total_orders'] ?? json['totalOrders'] ?? 0) as num).toInt(),
      channels: parsedChannels.isNotEmpty
          ? parsedChannels
          : const ['الكل', 'منصات التوصيل', 'توصيل مباشر', 'توصيل مشترك'],
      orders: parsedOrders,
      reconciliation: json['reconciliation'] as Map<String, dynamic>? ?? const {},
    );
  }

  final double totalRevenue;
  final int totalOrders;
  final List<String> channels;
  final List<DeliveryOrderItemData> orders;
  final Map<String, dynamic> reconciliation;

  @override
  List<Object?> get props => [totalRevenue, totalOrders, channels, orders, reconciliation];
}

// ============================================================================
// Discount Entities
// ============================================================================

class DiscountItemData extends Equatable {
  const DiscountItemData({
    required this.id,
    required this.invoiceRef,
    required this.title,
    required this.discountCode,
    required this.type,
    required this.amount,
    required this.grossAmount,
    required this.netAmount,
    required this.reason,
    required this.status,
    required this.authorizedByName,
    this.cancelledByName,
    this.cancelReason,
    this.createdAt,
  });

  factory DiscountItemData.fromJson(Map<String, dynamic> json) {
    final amt = ((json['amount'] ?? 0.0) as num).toDouble();
    final gross = ((json['gross_amount'] ?? json['grossAmount'] ?? (amt > 0 ? amt + 500.0 : 720.0)) as num).toDouble();
    final net = ((json['net_amount'] ?? json['netAmount'] ?? (gross - amt)) as num).toDouble();

    return DiscountItemData(
      id: json['id']?.toString() ?? '',
      invoiceRef: json['invoice_ref'] as String? ?? json['invoiceRef'] as String? ?? json['id']?.toString() ?? '',
      title: json['title'] as String? ?? json['reason'] as String? ?? 'خصم تجاري معتمد',
      discountCode: json['discount_code'] as String? ?? json['discountCode'] as String? ?? 'PROMO',
      type: json['type'] as String? ?? 'promotional',
      amount: amt,
      grossAmount: gross,
      netAmount: net,
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'applied',
      authorizedByName: json['authorized_by_name'] as String? ?? json['authorizedByName'] as String? ?? 'أحمد سالم • مدير الفرع',
      cancelledByName: json['cancelled_by_name'] as String? ?? json['cancelledByName'] as String?,
      cancelReason: json['cancel_reason'] as String? ?? json['cancelReason'] as String?,
      createdAt: json['created_at'] as String? ?? json['createdAt'] as String?,
    );
  }

  final String id;
  final String invoiceRef;
  final String title;
  final String discountCode;
  final String type;
  final double amount;
  final double grossAmount;
  final double netAmount;
  final String reason;
  final String status;
  final String authorizedByName;
  final String? cancelledByName;
  final String? cancelReason;
  final String? createdAt;

  DiscountItemData copyWith({
    String? status,
    String? cancelledByName,
    String? cancelReason,
  }) =>
      DiscountItemData(
        id: id,
        invoiceRef: invoiceRef,
        title: title,
        discountCode: discountCode,
        type: type,
        amount: amount,
        grossAmount: grossAmount,
        netAmount: netAmount,
        reason: reason,
        status: status ?? this.status,
        authorizedByName: authorizedByName,
        cancelledByName: cancelledByName ?? this.cancelledByName,
        cancelReason: cancelReason ?? this.cancelReason,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoice_ref': invoiceRef,
        'title': title,
        'discount_code': discountCode,
        'type': type,
        'amount': amount,
        'gross_amount': grossAmount,
        'net_amount': netAmount,
        'reason': reason,
        'status': status,
        'authorized_by_name': authorizedByName,
        'cancelled_by_name': cancelledByName,
        'cancel_reason': cancelReason,
        'created_at': createdAt,
      };

  @override
  List<Object?> get props => [
        id,
        invoiceRef,
        title,
        discountCode,
        type,
        amount,
        grossAmount,
        netAmount,
        reason,
        status,
        authorizedByName,
        cancelledByName,
        cancelReason,
        createdAt,
      ];
}

// ============================================================================
// Shift Sales Entry & Review Entities
// ============================================================================

class ShiftSalesEntryInput extends Equatable {
  const ShiftSalesEntryInput({
    this.shiftId,
    required this.channel,
    required this.grossAmount,
    this.discountAmount = 0.0,
    required this.netAmount,
    this.paymentMethod = 'cash',
    this.orderCount = 1,
    this.branchId,
    this.items,
  });

  final String? shiftId;
  final String channel;
  final double grossAmount;
  final double discountAmount;
  final double netAmount;
  final String paymentMethod;
  final int orderCount;
  final String? branchId;
  final List<Map<String, dynamic>>? items;

  Map<String, dynamic> toJson() => {
        if (shiftId != null) 'shiftId': shiftId,
        'channel': channel,
        'grossAmount': grossAmount,
        'discountAmount': discountAmount,
        'netAmount': netAmount,
        'paymentMethod': paymentMethod,
        'orderCount': orderCount,
        if (branchId != null) 'branchId': branchId,
        if (items != null) 'items': items,
      };

  @override
  List<Object?> get props => [
        shiftId,
        channel,
        grossAmount,
        discountAmount,
        netAmount,
        paymentMethod,
        orderCount,
        branchId,
        items,
      ];
}

class ShiftCloseReviewData extends Equatable {
  const ShiftCloseReviewData({
    required this.shiftId,
    required this.branchName,
    required this.managerName,
    required this.timeRange,
    required this.operatingDuration,
    required this.netSales,
    required this.grossSales,
    required this.dineInSales,
    required this.deliverySales,
    required this.discountsTotal,
    required this.discountsCount,
    required this.totalOrders,
    required this.averageOrder,
    required this.soldItemsSummary,
    required this.isClosed,
    required this.closingCashSystem,
    required this.openingCash,
  });

  factory ShiftCloseReviewData.fromJson(Map<String, dynamic> json) => ShiftCloseReviewData(
        shiftId: json['shift_id'] as String? ?? json['shiftId'] as String? ?? '',
        branchName: json['branch_name'] as String? ?? json['branchName'] as String? ?? '—',
        managerName: json['manager_name'] as String? ?? json['managerName'] as String? ?? '—',
        timeRange: json['time_range'] as String? ?? json['timeRange'] as String? ?? '—',
        operatingDuration: json['operating_duration'] as String? ?? json['operatingDuration'] as String? ?? '—',
        netSales: ((json['net_sales'] ?? json['netSales'] ?? 0.0) as num).toDouble(),
        grossSales: ((json['gross_sales'] ?? json['grossSales'] ?? 0.0) as num).toDouble(),
        dineInSales: ((json['dine_in_sales'] ?? json['dineInSales'] ?? 0.0) as num).toDouble(),
        deliverySales: ((json['delivery_sales'] ?? json['deliverySales'] ?? 0.0) as num).toDouble(),
        discountsTotal: ((json['discounts_total'] ?? json['discountsTotal'] ?? 0.0) as num).toDouble(),
        discountsCount: ((json['discounts_count'] ?? json['discountsCount'] ?? 0) as num).toInt(),
        totalOrders: ((json['total_orders'] ?? json['totalOrders'] ?? 0) as num).toInt(),
        averageOrder: ((json['average_order'] ?? json['averageOrder'] ?? 0.0) as num).toDouble(),
        soldItemsSummary: json['sold_items_summary'] as String? ??
            json['soldItemsSummary'] as String? ??
            'لا توجد أصناف مباعة مسجلة لهذا الإغلاق',
        isClosed: (json['is_closed'] ?? json['isClosed'] ?? false) as bool,
        closingCashSystem: ((json['closing_cash_system'] ?? json['closingCashSystem'] ?? 0.0) as num).toDouble(),
        openingCash: ((json['opening_cash'] ?? json['openingCash'] ?? 0.0) as num).toDouble(),
      );

  final String shiftId;
  final String branchName;
  final String managerName;
  final String timeRange;
  final String operatingDuration;
  final double netSales;
  final double grossSales;
  final double dineInSales;
  final double deliverySales;
  final double discountsTotal;
  final int discountsCount;
  final int totalOrders;
  final double averageOrder;
  final String soldItemsSummary;
  final bool isClosed;
  final double closingCashSystem;
  final double openingCash;

  Map<String, dynamic> toJson() => {
        'shift_id': shiftId,
        'branch_name': branchName,
        'manager_name': managerName,
        'time_range': timeRange,
        'operating_duration': operatingDuration,
        'net_sales': netSales,
        'gross_sales': grossSales,
        'dine_in_sales': dineInSales,
        'delivery_sales': deliverySales,
        'discounts_total': discountsTotal,
        'discounts_count': discountsCount,
        'total_orders': totalOrders,
        'average_order': averageOrder,
        'sold_items_summary': soldItemsSummary,
        'is_closed': isClosed,
        'closing_cash_system': closingCashSystem,
        'opening_cash': openingCash,
      };

  @override
  List<Object?> get props => [
        shiftId,
        branchName,
        managerName,
        timeRange,
        operatingDuration,
        netSales,
        grossSales,
        dineInSales,
        deliverySales,
        discountsTotal,
        discountsCount,
        totalOrders,
        averageOrder,
        soldItemsSummary,
        isClosed,
        closingCashSystem,
        openingCash,
      ];
}

// ============================================================================
// Sales Repository Contract
// ============================================================================

abstract class SalesRepository {
  Future<SalesDashboardData> getSalesDashboard({String? branchId, String? shiftId});
  Future<RestaurantSalesData> getRestaurantSales({
    String? branchId,
    String? shiftId,
    String? category,
    String? query,
  });
  Future<DeliverySalesData> getDeliverySales({
    String? branchId,
    String? shiftId,
    String? channel,
  });
  Future<List<DiscountItemData>> getDiscounts({
    String? shiftId,
    String? branchId,
    String? status,
  });
  Future<DiscountItemData> cancelDiscount({
    required String discountId,
    required String reason,
    String? note,
    String? cancelledByUserId,
  });
  Future<Map<String, dynamic>> recordShiftEntry(ShiftSalesEntryInput entry);
  Future<ShiftCloseReviewData> getShiftReview({String? shiftId});
  Future<Map<String, dynamic>> closeShift({
    required String shiftId,
    required double closingCashActual,
    String? supervisorUserId,
    String? notes,
    String? branchId,
  });
  Future<ShiftCloseReviewData> getClosedShiftSummary({String? shiftId});
}
