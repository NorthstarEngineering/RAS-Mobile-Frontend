import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../../../core/widgets/rms_primary_button.dart';
import '../../data/repositories/http_transfers_repository.dart';
import '../../domain/repositories/transfers_repository.dart';

class ReceiveTransferScreen extends StatefulWidget {
  const ReceiveTransferScreen({super.key, required this.transferId});
  final String transferId;
  @override
  State<ReceiveTransferScreen> createState() => _ReceiveTransferScreenState();
}

class _ReceiveTransferScreenState extends State<ReceiveTransferScreen> {
  int _accepted = 0;
  int _sentQuantity = 0;
  bool _acknowledged = false;
  bool _hasDamage = false;
  bool _isSubmitting = false;
  TransferOrder? _order;
  final TextEditingController _damageNotesController = TextEditingController();

  TransfersRepository get _repository {
    if (sl.isRegistered<TransfersRepository>()) {
      return sl<TransfersRepository>();
    }
    return HttpTransfersRepository.instance;
  }

  @override
  void initState() {
    super.initState();
    _loadTransfer();
  }

  @override
  void dispose() {
    _damageNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadTransfer() async {
    try {
      final order = await _repository.getTransferById(widget.transferId);
      if (mounted && order is TransferOrder) {
        setState(() {
          _order = order;
          final q = (order.rawQuantity ?? 0.0).toInt();
          _sentQuantity = q;
          _accepted = q;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final unit = _order?.unit ?? 'كجم';
    return RmsOpsScaffold(
      title: 'استلام التحويل',
      showProfile: false,
      children: [
        _transferHeader(),
        const SizedBox(height: 12),
        _itemInspection(),
        const SizedBox(height: 12),
        _inventoryImpact(),
        CheckboxListTile(
          value: _acknowledged,
          onChanged: (value) => setState(() => _acknowledged = value ?? false),
          title: const Text('أقر باستلام الكميات السليمة وفحصها حسياً'),
        ),
        const SizedBox(height: 10),
        RmsPrimaryButton(
          label: 'تأكيد الاستلام وإيداع المخزون ($_accepted $unit)',
          icon: Icons.check_circle_outline,
          onPressed: _isSubmitting ? () {} : _receive,
        ),
        OutlinedButton.icon(
          onPressed: () => _notify('تم تجهيز محضر عدم المطابقة محلياً'),
          icon: const Icon(Icons.report_gmailerrorred_outlined),
          label: const Text('محضر عدم مطابقة'),
        ),
      ],
    );
  }

  Widget _transferHeader() => RmsOpsSection(
    title: '${_order?.transferCode ?? widget.transferId} • شحنة واردة نشطة',
    child: Text(
      'المصدر: ${_order?.source ?? ""}\nالاستلام: ${_order?.destination ?? ""} • الوصول ${_order?.arrivalTime ?? "11:30 ص"}',
    ),
  );

  Widget _itemInspection() {
    final unit = _order?.unit ?? 'كجم';
    return RmsOpsSection(
      title: 'فحص ${_order?.item ?? "صنف التحويل"}',
      icon: Icons.inventory_2_outlined,
      child: Column(
        children: [
          RmsOpsMetric(label: 'الكمية المرسلة', value: '$_sentQuantity $unit'),
          Row(
            children: [
              IconButton(
                onPressed: () => setState(
                  () => _accepted = (_accepted - 1).clamp(0, _sentQuantity).toInt(),
                ),
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  '$_accepted $unit مقبول',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(
                  () => _accepted = (_accepted + 1).clamp(0, _sentQuantity).toInt(),
                ),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          SwitchListTile(
            value: _hasDamage,
            onChanged: (value) => setState(() => _hasDamage = value),
            title: const Text('وجود تلف / عجز أثناء النقل'),
          ),
          if (_hasDamage)
            TextField(
              controller: _damageNotesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'وصف التلف والتوثيق'),
            ),
        ],
      ),
    );
  }

  Widget _inventoryImpact() {
    final beforeBalance = _order?.destinationBalance ?? 0.0;
    final unit = _order?.unit ?? 'كجم';
    final afterBalance = beforeBalance + _accepted;
    return RmsOpsSection(
      title: 'الأثر المخزني الفوري بالفرع المستلم',
      child: Text(
        'الرصيد قبل الاستلام: $beforeBalance $unit • الكمية المقبولة: $_accepted $unit • الرصيد بعد الإيداع: $afterBalance $unit',
      ),
    );
  }

  Future<void> _receive() async {
    if (!_acknowledged) return _notify('أكد مطابقة الاستلام قبل إيداع المخزون');
    setState(() => _isSubmitting = true);

    try {
      await _repository.receiveTransfer(
        transferId: widget.transferId,
        acceptedQuantity: _accepted.toDouble(),
        hasDamage: _hasDamage,
        damageNotes: _hasDamage ? _damageNotesController.text.trim() : null,
        acknowledged: true,
      );
      if (!mounted) return;
      _notify('تم تأكيد استلام الشحنة ${_order?.transferCode ?? widget.transferId} وإيداع الأرصدة بنجاح');
      context.go('/transfers');
    } catch (e) {
      if (!mounted) return;
      _notify('خطأ في تأكيد الاستلام: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
