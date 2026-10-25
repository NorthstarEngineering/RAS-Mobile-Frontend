import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../../../core/widgets/rms_primary_button.dart';
import '../../data/repositories/http_transfers_repository.dart';
import '../../domain/repositories/transfers_repository.dart';

class SendTransferScreen extends StatefulWidget {
  const SendTransferScreen({super.key, required this.transferId});
  final String transferId;
  @override
  State<SendTransferScreen> createState() => _SendTransferScreenState();
}

class _SendTransferScreenState extends State<SendTransferScreen> {
  bool _acknowledged = false;
  bool _isSubmitting = false;
  String _vehicle = 'سيارة نقل تبريد رقم 02';
  TransferOrder? _order;
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _driverPhoneController = TextEditingController();

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
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadTransfer() async {
    try {
      final order = await _repository.getTransferById(widget.transferId);
      if (mounted && order is TransferOrder) {
        setState(() {
          _order = order;
          if (order.driverName != null && order.driverName!.isNotEmpty) {
            _driverNameController.text = order.driverName!;
          }
          if (order.driverPhone != null && order.driverPhone!.isNotEmpty) {
            _driverPhoneController.text = order.driverPhone!;
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'إرسال التحويل',
    showProfile: false,
    children: [
      const RmsOpsBanner(
        title: 'تنبيه خصم فوري',
        message:
            'تأكيد الإرسال يسجل حركة إخراج من مخزون الفرع المصدر ويحدث رصيد المخزون.',
        color: AppColors.errorContainer,
      ),
      const SizedBox(height: 12),
      _goods(),
      const SizedBox(height: 12),
      _transport(),
      CheckboxListTile(
        value: _acknowledged,
        onChanged: (value) => setState(() => _acknowledged = value ?? false),
        title: const Text('أقر بوزن الشحنة ومطابقة البيانات قبل خروجها'),
      ),
      const SizedBox(height: 12),
      RmsPrimaryButton(
        label: 'تأكيد إرسال التحويل وخصم المخزون',
        icon: Icons.local_shipping_outlined,
        onPressed: _isSubmitting ? () {} : _send,
      ),
      OutlinedButton.icon(
        onPressed: () => _notify('تم تجهيز معاينة الإذن للطباعة'),
        icon: const Icon(Icons.print_outlined),
        label: const Text('طباعة إذن الصرف'),
      ),
    ],
  );

  Widget _goods() {
    final itemTitle = _order?.item ?? 'صنف التحويل';
    final qty = _order?.quantity ?? '';
    final srcBal = _order?.sourceBalance != null
        ? '${_order!.sourceBalance} ${_order?.unit ?? "كجم"}'
        : 'حسب الجرد';

    return RmsOpsSection(
      title: 'تفاصيل الشحنة المصرح بإرسالها',
      child: Column(
        children: [
          RmsOpsRecord(
            title: itemTitle,
            subtitle: '$qty • دفعة مجهزة باردة • الرصيد قبل الصرف $srcBal',
          ),
          const SizedBox(height: 8),
          RmsOpsRecord(
            title: 'الفرع المستلم',
            subtitle: '${_order?.destination ?? ""} • وجهة الإرسال معتمدة',
          ),
        ],
      ),
    );
  }

  Widget _transport() => RmsOpsSection(
    title: 'بيانات النقل والوسيلة اللوجستية',
    icon: Icons.local_shipping_outlined,
    child: Column(
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _vehicle,
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
        ),
        TextField(
          controller: _driverNameController,
          decoration: const InputDecoration(
            labelText: 'اسم السائق',
            hintText: 'أدخل اسم السائق',
          ),
        ),
        TextField(
          controller: _driverPhoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'رقم هاتف السائق'),
        ),
        const ListTile(
          leading: Icon(Icons.thermostat),
          title: Text('درجة الحرارة الحالية'),
          trailing: Text('3.5° مئوية'),
        ),
      ],
    ),
  );

  Future<void> _send() async {
    if (!_acknowledged) return _notify('أكمل إقرار أمانة الصرف أولاً');
    setState(() => _isSubmitting = true);

    try {
      await _repository.sendTransfer(
        transferId: widget.transferId,
        vehicle: _vehicle,
        driverName: _driverNameController.text.trim(),
        driverPhone: _driverPhoneController.text.trim(),
        temperature: 3.5,
        notes: 'تم فحص الشحنة ومطابقة الأوزان والتبريد',
      );
      if (!mounted) return;
      _notify('تم تأكيد إرسال الشحنة ${_order?.transferCode ?? widget.transferId} وخصم المخزون بنجاح');
      context.go('/transfers/${widget.transferId}/receive');
    } catch (e) {
      if (!mounted) return;
      _notify('خطأ في إرسال الشحنة: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
