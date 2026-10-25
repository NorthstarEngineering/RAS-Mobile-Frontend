import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../../../core/widgets/rms_primary_button.dart';
import '../../data/repositories/http_supply_repository.dart';
import '../../domain/repositories/supply_repository.dart';

class ExecuteSupplyOrderScreen extends StatefulWidget {
  const ExecuteSupplyOrderScreen({
    super.key,
    required this.orderId,
    this.repository,
  });

  final String orderId;
  final SupplyRepository? repository;

  @override
  State<ExecuteSupplyOrderScreen> createState() =>
      _ExecuteSupplyOrderScreenState();
}

class _ExecuteSupplyOrderScreenState extends State<ExecuteSupplyOrderScreen> {
  late final SupplyRepository _repository;
  SupplyOrder? _order;
  bool _confirmed = false;
  String _vehicle = 'سيارة نقل تبريد رقم 02';
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
          if (order != null && order.vehicle != null && order.vehicle!.isNotEmpty) {
            _vehicle = order.vehicle!;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'تنفيذ طلب التوريد',
    showProfile: false,
    children: [
      RmsOpsBanner(
        title: 'طلب ${widget.orderId} • جاهز للتنفيذ',
        message: 'راجع الكميات المعدة قبل خصمها من مخزون المطبخ المركزي.',
        color: AppColors.errorContainer,
      ),
      const SizedBox(height: 12),
      _shipmentItems(),
      const SizedBox(height: 12),
      _vehicleField(),
      CheckboxListTile(
        value: _confirmed,
        onChanged: (value) => setState(() => _confirmed = value ?? false),
        title: const Text('أقر بمطابقة الأصناف والكميات قبل تحميل الشحنة'),
      ),
      const SizedBox(height: 12),
      RmsPrimaryButton(
        label: 'تأكيد الاعتماد وصرف الشحنة',
        icon: Icons.local_shipping_outlined,
        onPressed: _dispatch,
      ),
      TextButton(
        onPressed: _reject,
        child: const Text('رفض الطلب'),
      ),
    ],
  );

  Widget _shipmentItems() {
    if (_isLoading) {
      return const RmsOpsSection(
        title: 'أصناف الشحنة المجهزة',
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
        title: 'أصناف الشحنة المجهزة',
        child: Column(
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RmsOpsRecord(
                    title: item.name,
                    subtitle: item.subtitle ??
                        '${item.requestedQuantity.toStringAsFixed(0)} ${item.unit} • تكلفة معيارية ${item.unitCost.toStringAsFixed(0)} ج.م / ${item.unit}',
                  ),
                ),
              )
              .toList(),
        ),
      );
    }

    return const RmsOpsSection(
      title: 'أصناف الشحنة المجهزة',
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'لا توجد أصناف مجهزة مسجلة في هذا الطلب',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _vehicleField() => DropdownButtonFormField<String>(
    isExpanded: true,
    value: _vehicle,
    decoration: const InputDecoration(labelText: 'وسيلة النقل'),
    items:
        const [
              'سيارة نقل تبريد رقم 02',
              'سيارة نقل تبريد رقم 01',
              'صندوق توصيل سريع',
            ]
            .map(
              (vehicle) => DropdownMenuItem(
                value: vehicle,
                child: Text(
                  vehicle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
    onChanged: (value) => setState(() => _vehicle = value!),
  );

  Future<void> _dispatch() async {
    if (!_confirmed) return _showMessage('أكد مطابقة الشحنة قبل الصرف');
    try {
      final ok = await _repository.executeSupplyOrder(
        widget.orderId,
        vehicle: _vehicle,
        confirmed: _confirmed,
        items: _order?.items,
      );
      if (ok && mounted) {
        _showMessage('تم اعتماد وصرف شحنة طلب التوريد بنجاح');
        Navigator.of(context).maybePop(true);
      }
    } catch (e) {
      if (mounted) _showMessage('فشل تنفيذ طلب التوريد: $e');
    }
  }

  Future<void> _reject() async {
    try {
      final ok = await _repository.rejectSupplyOrder(widget.orderId);
      if (ok && mounted) {
        _showMessage('تم رفض طلب التوريد بنجاح');
        Navigator.of(context).maybePop(true);
      }
    } catch (e) {
      if (mounted) _showMessage('فشل رفض الطلب: $e');
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
