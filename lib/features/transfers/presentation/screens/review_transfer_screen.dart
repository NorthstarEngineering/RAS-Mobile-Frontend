import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/rms_operations.dart';
import '../../../../core/widgets/rms_primary_button.dart';

class ReviewTransferScreen extends StatefulWidget {
  const ReviewTransferScreen({super.key, required this.transferId});
  final String transferId;
  @override
  State<ReviewTransferScreen> createState() => _ReviewTransferScreenState();
}

class _ReviewTransferScreenState extends State<ReviewTransferScreen> {
  int _approvedQuantity = 25;
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) => RmsOpsScaffold(
    title: 'مراجعة التحويل',
    showProfile: false,
    children: [
      _routeSummary(),
      const SizedBox(height: 12),
      _logisticsStage(),
      const SizedBox(height: 12),
      _quantityReview(),
      CheckboxListTile(
        value: _acknowledged,
        onChanged: (value) => setState(() => _acknowledged = value ?? false),
        title: const Text('أقر بصحة الخصم المخزني وجاهزية الكمية المعتمدة'),
      ),
      const SizedBox(height: 10),
      RmsPrimaryButton(
        label: 'اعتماد التحويل والمتابعة للإرسال (TR-04)',
        icon: Icons.verified_outlined,
        onPressed: _approve,
      ),
      OutlinedButton(
        onPressed: () => _notify('تم تسجيل الرفض محلياً'),
        child: const Text('رفض طلب التحويل'),
      ),
    ],
  );

  Widget _routeSummary() => RmsOpsSection(
    title: '${widget.transferId} • قيد المراجعة والاعتماد',
    icon: Icons.swap_horiz,
    child: const Text(
      'الفرع المصدر: وسط البلد (#01)\nالفرع المستلم: المعادي (#03) • الأولوية تشغيلية عاجلة',
    ),
  );

  Widget _logisticsStage() => const RmsOpsSection(
    title: 'دورة التحويل اللوجستية',
    child: Text(
      '1. الطلب • مكتمل\n2. الاعتماد • المرحلة الحالية\n3. الإرسال (TR-04) • 4. الفحص والاستلام (TR-05)',
    ),
  );

  Widget _quantityReview() => RmsOpsSection(
    title: 'صدور دجاج فيليه متبلة • RAW-POULT-204',
    icon: Icons.inventory_2_outlined,
    child: Column(
      children: [
        const RmsOpsMetric(label: 'الكمية المطلوبة', value: '30 كجم'),
        Row(
          children: [
            IconButton(
              onPressed: () => setState(
                () => _approvedQuantity = (_approvedQuantity - 1)
                    .clamp(1, 30)
                    .toInt(),
              ),
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: Text(
                '$_approvedQuantity كجم معتمدة',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(
                () => _approvedQuantity = (_approvedQuantity + 1)
                    .clamp(1, 30)
                    .toInt(),
              ),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const Text(
          'رصيد المصدر 70 كجم • المتبقي بعد الخصم يحافظ على حد الأمان.',
        ),
        const TextField(
          maxLines: 2,
          decoration: InputDecoration(labelText: 'سبب تعديل الكمية المعتمدة'),
        ),
      ],
    ),
  );

  void _approve() {
    if (!_acknowledged) return _notify('أكد إقرار الاعتماد قبل المتابعة');
    context.push('/transfers/${widget.transferId}/send');
  }

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
