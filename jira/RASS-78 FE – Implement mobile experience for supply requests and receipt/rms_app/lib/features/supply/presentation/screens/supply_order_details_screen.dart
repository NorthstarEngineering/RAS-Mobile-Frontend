import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../../../core/widgets/rms_primary_button.dart';
import '../../data/repositories/http_supply_repository.dart';
import '../../domain/repositories/supply_repository.dart';

class SupplyOrderDetailsScreen extends StatefulWidget {
  const SupplyOrderDetailsScreen({
    super.key,
    required this.orderId,
    this.repository,
  });

  final String orderId;
  final SupplyRepository? repository;

  @override
  State<SupplyOrderDetailsScreen> createState() =>
      _SupplyOrderDetailsScreenState();
}

class _SupplyOrderDetailsScreenState extends State<SupplyOrderDetailsScreen> {
  late final SupplyRepository _repository;
  SupplyOrder? _order;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (sl.isRegistered<SupplyRepository>()
            ? sl<SupplyRepository>()
            : HttpSupplyRepository(
                apiClient:
                    sl.isRegistered<ApiClient>() ? sl<ApiClient>() : null,
              ));
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final order = await _repository.getSupplyOrderById(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderNum = _order?.orderNumber.isNotEmpty == true
        ? _order!.orderNumber
        : widget.orderId;
    final branchName = _order?.branch.isNotEmpty == true
        ? _order!.branch
        : 'فرع الاستلام';
    final status = _order?.status.isNotEmpty == true
        ? _order!.status
        : 'قيد المراجعة';
    final delivery = _order?.requestedDeliveryDate.isNotEmpty == true
        ? _order!.requestedDeliveryDate
        : 'اليوم';

    return RmsOpsScaffold(
      title: 'تفاصيل طلب التوريد',
      showProfile: false,
      children: [
        RmsOpsSection(
          title: '$orderNum • $branchName',
          icon: Icons.local_shipping_outlined,
          child: Text('الحالة: $status • موعد الوصول المتوقع $delivery'),
        ),
        const SizedBox(height: 12),
        _items(),
        const SizedBox(height: 12),
        _shipment(),
        const SizedBox(height: 12),
        _actions(context),
      ],
    );
  }

  Widget _items() {
    if (_isLoading) {
      return const RmsOpsSection(
        title: 'أصناف الطلبية',
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final items = _order?.items;
    if (items != null && items.isNotEmpty) {
      return RmsOpsSection(
        title: 'أصناف الطلبية',
        child: Column(
          children: items
              .map(
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RmsOpsRecord(
                    title: i.name,
                    subtitle:
                        '${i.requestedQuantity.toStringAsFixed(0)} ${i.unit} مطلوب • تم تجهيز ${(i.dispatchedQuantity ?? i.requestedQuantity).toStringAsFixed(0)} ${i.unit}',
                  ),
                ),
              )
              .toList(),
        ),
      );
    }

    return const RmsOpsSection(
      title: 'أصناف الطلبية',
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'لا توجد أصناف مسجلة في هذا الطلب',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _shipment() {
    final source = _order?.sourceKitchenName.isNotEmpty == true
        ? _order!.sourceKitchenName
        : 'المطبخ المركزي ومستودع الإمداد';
    final vehicle = _order?.vehicle?.isNotEmpty == true
        ? _order!.vehicle!
        : 'شاحنة نقل تبريد';
    final driver = _order?.driverName?.isNotEmpty == true
        ? _order!.driverName!
        : 'سائق الشحنة';
    final temp = _order?.temperature?.isNotEmpty == true
        ? _order!.temperature!
        : 'فحص التبريد معتمد';

    return RmsOpsSection(
      title: 'بيانات الإذن واللوجستيات',
      child: Text(
        '$source • $vehicle\nالسائق: $driver • درجة الحرارة $temp',
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final isReceived = _order?.status == 'تم الاستلام';

    return Column(
      children: [
        RmsPrimaryButton(
          label: isReceived
              ? 'الطلب مكتمل ومستلم'
              : 'تأكيد الاستلام وفحص الشحنة (SUP-05)',
          icon: Icons.fact_check_outlined,
          onPressed: isReceived
              ? () {}
              : () async {
                  await context.push('/supply/${widget.orderId}/receive');
                  _loadOrder();
                },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await context.push('/supply/${widget.orderId}/execute');
            _loadOrder();
          },
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('عرض تنفيذ الشحن (SUP-04)'),
        ),
      ],
    );
  }
}
