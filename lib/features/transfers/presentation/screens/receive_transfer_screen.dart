import 'package:flutter/material.dart';

import '../../../../core/widgets/rms_operations.dart';
import '../../../../core/widgets/rms_primary_button.dart';

class ReceiveTransferScreen extends StatefulWidget {
  const ReceiveTransferScreen({super.key, required this.transferId});
  final String transferId;
  @override
  State<ReceiveTransferScreen> createState() => _ReceiveTransferScreenState();
}

class _ReceiveTransferScreenState extends State<ReceiveTransferScreen> {
  int _accepted = 24;
  bool _acknowledged = false;
  bool _hasDamage = true;

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
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
        label: 'تأكيد الاستلام وإيداع المخزون ($_accepted كجم)',
        icon: Icons.check_circle_outline,
        onPressed: _receive,
      ),
      OutlinedButton.icon(
        onPressed: () => _notify('تم تجهيز محضر عدم المطابقة محلياً'),
        icon: const Icon(Icons.report_gmailerrorred_outlined),
        label: const Text('محضر عدم مطابقة'),
      ),
    ],
  );

  Widget _transferHeader() => RmsOpsSection(
    title: '${widget.transferId} • شحنة واردة نشطة',
    child: const Text(
      'المصدر: فرع وسط البلد (#01)\nالاستلام: فرع المعادي (#03) • الوصول 01:10 م • حرارة 4.0° مئوية',
    ),
  );

  Widget _itemInspection() => RmsOpsSection(
    title: 'فحص صدور دجاج فيليه متبلة',
    icon: Icons.inventory_2_outlined,
    child: Column(
      children: [
        const RmsOpsMetric(label: 'الكمية المرسلة', value: '25 كجم'),
        Row(
          children: [
            IconButton(
              onPressed: () => setState(
                () => _accepted = (_accepted - 1).clamp(0, 25).toInt(),
              ),
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: Text(
                '$_accepted كجم مقبول',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(
                () => _accepted = (_accepted + 1).clamp(0, 25).toInt(),
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
          const TextField(
            maxLines: 3,
            decoration: InputDecoration(labelText: 'وصف التلف والتوثيق'),
          ),
      ],
    ),
  );

  Widget _inventoryImpact() => RmsOpsSection(
    title: 'الأثر المخزني الفوري بالفرع المستلم',
    child: Text(
      'الرصيد قبل الاستلام: 6 كجم • الكمية المقبولة: $_accepted كجم • الرصيد بعد الإيداع: ${6 + _accepted} كجم',
    ),
  );

  void _receive() {
    if (!_acknowledged) return _notify('أكد مطابقة الاستلام قبل إيداع المخزون');
    _notify('تم التحقق من استلام التحويل محلياً');
  }

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
