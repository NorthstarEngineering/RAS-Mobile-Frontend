import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../../../core/widgets/rms_primary_button.dart';

class SendTransferScreen extends StatefulWidget {
  const SendTransferScreen({super.key, required this.transferId});
  final String transferId;
  @override
  State<SendTransferScreen> createState() => _SendTransferScreenState();
}

class _SendTransferScreenState extends State<SendTransferScreen> {
  bool _acknowledged = false;
  String _vehicle = 'سيارة نقل تبريد رقم 02';

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
        onPressed: _send,
      ),
      OutlinedButton.icon(
        onPressed: () => _notify('تم تجهيز معاينة الإذن للطباعة'),
        icon: const Icon(Icons.print_outlined),
        label: const Text('طباعة إذن الصرف'),
      ),
    ],
  );

  Widget _goods() => RmsOpsSection(
    title: 'تفاصيل الشحنة المصرح بإرسالها',
    child: const Column(
      children: [
        RmsOpsRecord(
          title: 'صدور دجاج فيليه متبلة',
          subtitle: '25 كجم • دفعة مجهزة باردة • الرصيد قبل الصرف 70 كجم',
        ),
        SizedBox(height: 8),
        RmsOpsRecord(
          title: 'الفرع المستلم',
          subtitle: 'فرع المعادي (#03) • وجهة الإرسال معتمدة',
        ),
      ],
    ),
  );

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
        const TextField(
          decoration: InputDecoration(
            labelText: 'اسم السائق',
            hintText: 'أحمد رشوان',
          ),
        ),
        const TextField(
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: 'رقم هاتف السائق'),
        ),
        const ListTile(
          leading: Icon(Icons.thermostat),
          title: Text('درجة الحرارة الحالية'),
          trailing: Text('3.5° مئوية'),
        ),
      ],
    ),
  );

  void _send() {
    if (!_acknowledged) return _notify('أكمل إقرار أمانة الصرف أولاً');
    _notify('تم التحقق من إذن الإرسال محلياً');
  }

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
