import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../../../core/widgets/rms_primary_button.dart';
import '../../data/repositories/http_supply_repository.dart';
import '../../domain/repositories/supply_repository.dart';

class ReceiveSupplyOrderScreen extends StatefulWidget {
  const ReceiveSupplyOrderScreen({
    super.key,
    required this.orderId,
    this.repository,
  });

  final String orderId;
  final SupplyRepository? repository;

  @override
  State<ReceiveSupplyOrderScreen> createState() =>
      _ReceiveSupplyOrderScreenState();
}

class _ReceiveSupplyOrderScreenState extends State<ReceiveSupplyOrderScreen> {
  late final SupplyRepository _repository;
  SupplyOrder? _order;
  final TextEditingController _shortageController = TextEditingController();

  bool _checked = false;
  bool _hasShortage = false;
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

  @override
  void dispose() {
    _shortageController.dispose();
    super.dispose();
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
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'استلام التوريد',
    showProfile: false,
    children: [
      RmsOpsBanner(
        title: 'استلام شحنة ${widget.orderId}',
        message:
            'افحص الجودة ودرجة الحرارة والكميات قبل إيداع الرصيد في مخزن الفرع.',
      ),
      const SizedBox(height: 12),
      _deliveryInfo(),
      const SizedBox(height: 12),
      _inspectionRows(),
      const SizedBox(height: 12),
      SwitchListTile(
        value: _hasShortage,
        onChanged: (value) => setState(() => _hasShortage = value),
        title: const Text('يوجد فرق في الكمية أو تلف'),
      ),
      if (_hasShortage)
        TextField(
          controller: _shortageController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'تفاصيل الفرق والتلف',
            hintText: 'اكتب تفاصيل التلف أو العجز ومحضر عدم المطابقة لدعم التدقيق',
          ),
        ),
      CheckboxListTile(
        value: _checked,
        onChanged: (value) => setState(() => _checked = value ?? false),
        title: const Text('أقر بفحص الكمية والجودة وسلامة الشحنة'),
      ),
      const SizedBox(height: 12),
      RmsPrimaryButton(
        label: 'تأكيد الاستلام وإيداع المخزون',
        icon: Icons.inventory_2_outlined,
        onPressed: _receive,
      ),
      OutlinedButton.icon(
        onPressed: () {
          setState(() => _hasShortage = true);
          _showMessage('تم فتح خانة تسجيل عدم المطابقة');
        },
        icon: const Icon(Icons.warning_amber),
        label: const Text('تحرير محضر عدم مطابقة'),
      ),
    ],
  );

  Widget _deliveryInfo() {
    final source = _order?.sourceKitchenName.isNotEmpty == true
        ? _order!.sourceKitchenName
        : 'المطبخ المركزي ومستودع الإمداد';
    final branch = _order?.branch.isNotEmpty == true
        ? _order!.branch
        : 'فرع الاستلام';
    final driver = _order?.driverName?.isNotEmpty == true
        ? _order!.driverName!
        : 'سائق الشحنة';
    final time = _order?.time.isNotEmpty == true ? _order!.time : 'اليوم';
    final temp = _order?.temperature?.isNotEmpty == true
        ? _order!.temperature!
        : 'فحص التبريد معتمد';

    return RmsOpsSection(
      title: 'بيانات الشحنة',
      child: Text(
        'المصدر: $source • فرع الاستلام: $branch\nالسائق: $driver • الوصول $time • حرارة $temp',
      ),
    );
  }

  Widget _inspectionRows() {
    if (_isLoading) {
      return const RmsOpsSection(
        title: 'فحص الكميات والجودة',
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
        title: 'فحص الكميات والجودة',
        child: Column(
          children: items
              .map(
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RmsOpsRecord(
                    title: i.name,
                    subtitle:
                        '${(i.dispatchedQuantity ?? i.requestedQuantity).toStringAsFixed(0)} ${i.unit} مرسلة • ${(i.receivedQuantity ?? i.dispatchedQuantity ?? i.requestedQuantity).toStringAsFixed(0)} ${i.unit} مقبولة',
                  ),
                ),
              )
              .toList(),
        ),
      );
    }

    return const RmsOpsSection(
      title: 'فحص الكميات والجودة',
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'لا توجد أصناف مسجلة للفحص في هذا الطلب',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Future<void> _receive() async {
    if (!_checked) return _showMessage('أكمل إقرار الفحص قبل الاستلام');
    if (_hasShortage && _shortageController.text.trim().isEmpty) {
      return _showMessage('يرجى توثيق سبب الفرق أو التلف في تفاصيل المحضر');
    }

    try {
      final ok = await _repository.receiveSupplyOrder(
        widget.orderId,
        checked: _checked,
        hasShortage: _hasShortage,
        shortageDetails: _hasShortage ? _shortageController.text.trim() : null,
        items: _order?.items,
      );
      if (ok && mounted) {
        _showMessage(
          _hasShortage
              ? 'تم تأكيد الاستلام وتسجيل ملاحظات العجز بنجاح'
              : 'تم تأكيد الاستلام وإيداع الأرصدة في المخزن بنجاح',
        );
        Navigator.of(context).maybePop(true);
      }
    } catch (e) {
      if (mounted) _showMessage('فشل تأكيد الاستلام: $e');
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
