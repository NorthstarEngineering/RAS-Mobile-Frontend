import '../../domain/repositories/sales_repository.dart';
import '../datasources/sales_remote_data_source.dart';

class HttpSalesRepository implements SalesRepository {
  HttpSalesRepository({SalesRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? SalesRemoteDataSourceImpl();

  static final HttpSalesRepository instance = HttpSalesRepository();

  final SalesRemoteDataSource _remoteDataSource;

  // Real database dynamic state without hardcoded fallback numbers
  String? _shiftId;
  String? _branchId = 'br_01';
  String _branchName = 'فرع وسط البلد (#01)';
  String _managerName = 'م. ألفاريز';
  bool _isShiftClosed = false;

  double _totalSales = 0.0;
  double _totalDiscounts = 0.0;
  int _totalOrders = 0;
  double _dineInSales = 0.0;
  double _takeawaySales = 0.0;
  double _deliveryAppsSales = 0.0;
  double _selfDeliverySales = 0.0;

  final List<DiscountItemData> _cachedDiscounts = [];

  String? get activeShiftId => _shiftId;
  String get branchName => _branchName;
  String get managerName => _managerName;
  bool get isShiftClosed => _isShiftClosed;

  double get totalSales => _totalSales;
  double get totalDiscounts => _totalDiscounts;
  int get totalOrders => _totalOrders;
  double get dineInSales => _dineInSales;
  double get takeawaySales => _takeawaySales;
  double get deliveryAppsSales => _deliveryAppsSales;
  double get selfDeliverySales => _selfDeliverySales;
  double get netSales => _totalSales - _totalDiscounts;

  void setActiveShift({String? shiftId, String? branchId, String? branchName, String? managerName}) {
    if (shiftId != null) _shiftId = shiftId;
    if (branchId != null) _branchId = branchId;
    if (branchName != null) _branchName = branchName;
    if (managerName != null) _managerName = managerName;
  }

  @override
  Future<SalesDashboardData> getSalesDashboard({
    String? branchId,
    String? shiftId,
  }) async {
    final targetBranch = branchId ?? _branchId;
    final targetShift = shiftId ?? _shiftId;

    final json = await _remoteDataSource.getSalesDashboard(
      branchId: targetBranch,
      shiftId: targetShift,
    );
    final dashboard = SalesDashboardData.fromJson(json);

    // Synchronize internal state with server truth
    _totalSales = dashboard.totalSales;
    _totalDiscounts = dashboard.totalDiscounts;
    _totalOrders = dashboard.totalOrders;
    _dineInSales = dashboard.channels.where((c) => c.channelKey == 'dine_in').fold(0.0, (s, c) => s + c.totalAmount);
    _takeawaySales = dashboard.channels.where((c) => c.channelKey == 'takeaway').fold(0.0, (s, c) => s + c.totalAmount);
    _deliveryAppsSales = dashboard.channels.where((c) => c.channelKey == 'delivery_apps').fold(0.0, (s, c) => s + c.totalAmount);
    _selfDeliverySales = dashboard.channels.where((c) => c.channelKey == 'direct_delivery').fold(0.0, (s, c) => s + c.totalAmount);
    _isShiftClosed = !dashboard.shiftStatus.isOpen;
    if (dashboard.shiftStatus.branchName.isNotEmpty) {
      _branchName = dashboard.shiftStatus.branchName;
    }
    if (dashboard.activeShiftId != null && dashboard.activeShiftId!.isNotEmpty) {
      _shiftId = dashboard.activeShiftId;
    }
    return dashboard;
  }

  @override
  Future<RestaurantSalesData> getRestaurantSales({
    String? branchId,
    String? shiftId,
    String? category,
    String? query,
  }) async {
    final json = await _remoteDataSource.getRestaurantSales(
      branchId: branchId ?? _branchId,
      shiftId: shiftId ?? _shiftId,
      category: category,
      query: query,
    );
    return RestaurantSalesData.fromJson(json);
  }

  @override
  Future<DeliverySalesData> getDeliverySales({
    String? branchId,
    String? shiftId,
    String? channel,
  }) async {
    final json = await _remoteDataSource.getDeliverySales(
      branchId: branchId ?? _branchId,
      shiftId: shiftId ?? _shiftId,
      channel: channel,
    );
    return DeliverySalesData.fromJson(json);
  }

  @override
  Future<List<DiscountItemData>> getDiscounts({
    String? shiftId,
    String? branchId,
    String? status,
  }) async {
    final list = await _remoteDataSource.getDiscounts(
      shiftId: shiftId ?? _shiftId,
      branchId: branchId ?? _branchId,
      status: status,
    );
    final discounts = list.map(DiscountItemData.fromJson).toList();
    _cachedDiscounts
      ..clear()
      ..addAll(discounts);
    _totalDiscounts = discounts.where((d) => d.status == 'applied').fold(0.0, (s, d) => s + d.amount);
    return discounts;
  }

  @override
  Future<DiscountItemData> cancelDiscount({
    required String discountId,
    required String reason,
    String? note,
    String? cancelledByUserId,
  }) async {
    // Propagate backend errors transparently; never fake success
    final json = await _remoteDataSource.cancelDiscount(
      discountId: discountId,
      reason: reason,
      note: note,
      cancelledByUserId: cancelledByUserId,
    );
    final updated = DiscountItemData.fromJson(json);
    _updateDiscountInCache(updated);
    return updated;
  }

  void _updateDiscountInCache(DiscountItemData updated) {
    final idx = _cachedDiscounts.indexWhere((d) => d.id == updated.id);
    if (idx >= 0) {
      final prev = _cachedDiscounts[idx];
      _cachedDiscounts[idx] = updated;
      if (prev.status != 'cancelled' && updated.status == 'cancelled') {
        _totalDiscounts = (_totalDiscounts - updated.amount).clamp(0.0, double.infinity);
      }
    } else {
      _cachedDiscounts.add(updated);
    }
  }

  @override
  Future<Map<String, dynamic>> recordShiftEntry(ShiftSalesEntryInput entry) async {
    // Direct backend persistence; never fake in-memory success on error
    final res = await _remoteDataSource.recordShiftEntry(entry.toJson());
    _totalSales += entry.grossAmount;
    _totalOrders += entry.orderCount;
    if (entry.channel == 'dine_in') {
      _dineInSales += entry.grossAmount;
    } else if (entry.channel == 'takeaway') {
      _takeawaySales += entry.grossAmount;
    } else {
      _deliveryAppsSales += entry.grossAmount;
    }
    return res;
  }

  @override
  Future<ShiftCloseReviewData> getShiftReview({String? shiftId}) async {
    final targetId = shiftId ?? _shiftId;
    final json = await _remoteDataSource.getShiftReview(shiftId: targetId);
    return ShiftCloseReviewData.fromJson(json);
  }

  @override
  Future<Map<String, dynamic>> closeShift({
    required String shiftId,
    required double closingCashActual,
    String? supervisorUserId,
    String? notes,
    String? branchId,
  }) async {
    final payload = <String, dynamic>{
      'shiftId': shiftId,
      'closingCashActual': closingCashActual,
      if (supervisorUserId != null) 'supervisorUserId': supervisorUserId,
      if (notes != null) 'notes': notes,
      if (branchId != null) 'branchId': branchId,
    };

    // Propagate backend error without swallowing or setting _isShiftClosed
    final res = await _remoteDataSource.closeShift(payload);
    _isShiftClosed = true;
    return res;
  }

  @override
  Future<ShiftCloseReviewData> getClosedShiftSummary({String? shiftId}) async {
    final targetId = shiftId ?? _shiftId;
    final json = await _remoteDataSource.getClosedShiftSummary(shiftId: targetId);
    return ShiftCloseReviewData.fromJson(json);
  }

  String formatAmount(double amount) {
    final parts = amount.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return parts.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }
}
