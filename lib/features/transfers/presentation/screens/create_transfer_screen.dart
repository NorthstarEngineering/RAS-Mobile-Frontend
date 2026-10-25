import 'package:flutter/material.dart';

import '../../../../core/widgets/rms_operations.dart';
import '../../../../core/widgets/rms_primary_button.dart';

class CreateTransferScreen extends StatefulWidget {
  const CreateTransferScreen({super.key});
  @override
  State<CreateTransferScreen> createState() => _CreateTransferScreenState();
}

class _CreateTransferScreenState extends State<CreateTransferScreen> {
  String _destination = 'فرع المعادي (#03)';
  String _item = 'لحم بقري مفروم (خام)';
  int _quantity = 15;
  bool _urgent = true;

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'إنشاء تحويل',
    showProfile: false,
    children: [
      const RmsOpsBanner(
        title: 'سياسة التحويلات اللحظية',
        message:
            'التحويلات بين الفروع تخضع لموازنة المخزون وتغطية الحد الأدنى، مع موافقة مدير الفرع المصدر.',
      ),
      const SizedBox(height: 12),
      _routeSection(),
      const SizedBox(height: 12),
      _itemSection(),
      const SizedBox(height: 12),
      _prioritySection(),
      const SizedBox(height: 12),
      _impactPreview(),
      const SizedBox(height: 12),
      RmsPrimaryButton(
        label: 'إرسال طلب التحويل للمراجعة والاعتماد',
        icon: Icons.send_outlined,
        onPressed: _submit,
      ),
      TextButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Text('إلغاء وتراجع'),
      ),
    ],
  );

  Widget _routeSection() => RmsOpsSection(
    title: 'تحديد مسار التحويل',
    icon: Icons.swap_horiz,
    child: Column(
      children: [
        const ListTile(
          title: Text('الفرع المصدر (المحول منه)'),
          subtitle: Text('فرع وسط البلد (#01) • المخزون الرئيسي'),
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _destination,
          decoration: const InputDecoration(
            labelText: 'الفرع المستلم (المحول إليه)',
          ),
          items:
              const [
                    'فرع المعادي (#03)',
                    'فرع التجمع الخامس (#02)',
                    'فرع الشيخ زايد (#04)',
                  ]
                  .map(
                    (branch) => DropdownMenuItem(
                      value: branch,
                      child: Text(
                        branch,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
          onChanged: (branch) => setState(() => _destination = branch!),
        ),
      ],
    ),
  );

  Widget _itemSection() => RmsOpsSection(
    title: 'الصنف والكمية المنقولة',
    icon: Icons.inventory_2_outlined,
    child: Column(
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _item,
          decoration: const InputDecoration(labelText: 'الصنف المطلوب تحويله'),
          items:
              const ['لحم بقري مفروم (خام)', 'صدور دجاج فيليه', 'زيت قلي نباتي']
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
          onChanged: (item) => setState(() => _item = item!),
        ),
        const SizedBox(height: 8),
        const RmsOpsMetric(
          label: 'رصيد المصدر',
          value: '45 كجم • حد الأمان 20 كجم',
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => setState(
                () => _quantity = (_quantity - 5).clamp(5, 100).toInt(),
              ),
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: Text(
                '$_quantity كجم',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _quantity += 5),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _prioritySection() => RmsOpsSection(
    title: 'أولوية التحويل ومبرره',
    child: Column(
      children: [
        SwitchListTile(
          value: _urgent,
          onChanged: (value) => setState(() => _urgent = value),
          title: const Text('أولوية قصوى (عاجل)'),
        ),
        const TextField(
          maxLines: 3,
          decoration: InputDecoration(labelText: 'سبب التحويل التشغيلي'),
        ),
      ],
    ),
  );

  Widget _impactPreview() => RmsOpsBanner(
    title: 'الأثر التقديري بعد الاعتماد',
    message:
        'رصيد المصدر بعد التحويل: ${45 - _quantity} كجم • المستلم: $_quantity كجم',
  );

  void _submit() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('تم التحقق من طلب التحويل محلياً')),
  );
}
