import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../../../core/widgets/rms_primary_button.dart';
import '../../data/repositories/http_transfers_repository.dart';
import '../../domain/repositories/transfers_repository.dart';

class ReviewTransferScreen extends StatefulWidget {
  const ReviewTransferScreen({super.key, required this.transferId});
  final String transferId;
  @override
  State<ReviewTransferScreen> createState() => _ReviewTransferScreenState();
}

class _ReviewTransferScreenState extends State<ReviewTransferScreen> {
  int _approvedQuantity = 25;
  int _requestedQuantity = 30;
  bool _acknowledged = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  TransferOrder? _order;
  final TextEditingController _notesController = TextEditingController();

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
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadTransfer() async {
    try {
      final order = await _repository.getTransferById(widget.transferId);
      if (mounted) {
        setState(() {
          if (order is TransferOrder) {
            _order = order;
            final q = (order.rawQuantity ?? 0.0).toInt();
            _requestedQuantity = q;
            _approvedQuantity = q > 0 ? q : 1;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const RmsOpsScaffold(
        title: 'مراجعة التحويل',
        showProfile: false,
        children: [
          Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
        ],
      );
    }

    return RmsOpsScaffold(
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
          onPressed: _isSubmitting ? () {} : _approve,
        ),
        OutlinedButton(
          onPressed: _isSubmitting ? null : _reject,
          child: const Text('رفض طلب التحويل'),
        ),
      ],
    );
  }

  Widget _routeSummary() => RmsOpsSection(
    title: '${_order?.transferCode ?? widget.transferId} • ${_order?.status ?? "قيد المراجعة والاعتماد"}',
    icon: Icons.swap_horiz,
    child: Text(
      'الفرع المصدر: ${_order?.source ?? ""}\nالفرع المستلم: ${_order?.destination ?? ""} • ${_order?.notes ?? "الأولوية تشغيلية عاجلة"}',
    ),
  );

  Widget _logisticsStage() => const RmsOpsSection(
    title: 'دورة التحويل اللوجستية',
    child: Text(
      '1. الطلب • مكتمل\n2. الاعتماد • المرحلة الحالية\n3. الإرسال (TR-04) • 4. الفحص والاستلام (TR-05)',
    ),
  );

  Widget _quantityReview() {
    final itemTitle = _order?.item ?? 'صنف التحويل';
    final stockCode = _order?.stockItemId ?? '';
    final unit = _order?.unit ?? 'كجم';
    final sourceBal = _order?.sourceBalance ?? 0.0;
    final remain = (sourceBal - _approvedQuantity).clamp(0.0, 999999.0);

    return RmsOpsSection(
      title: stockCode.isNotEmpty ? '$itemTitle • $stockCode' : itemTitle,
      icon: Icons.inventory_2_outlined,
      child: Column(
        children: [
          RmsOpsMetric(
            label: 'الكمية المطلوبة',
            value: '$_requestedQuantity $unit',
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => setState(
                  () => _approvedQuantity = (_approvedQuantity - 1)
                      .clamp(1, _requestedQuantity > 0 ? _requestedQuantity : 100)
                      .toInt(),
                ),
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  '$_approvedQuantity $unit معتمدة',
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
                      .clamp(1, _requestedQuantity > 0 ? _requestedQuantity : 100)
                      .toInt(),
                ),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          Text(
            'رصيد المصدر $sourceBal $unit • المتبقي بعد الخصم: $remain $unit.',
          ),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'سبب تعديل الكمية المعتمدة'),
          ),
        ],
      ),
    );
  }

  Future<void> _approve() async {
    if (!_acknowledged) return _notify('أكد إقرار الاعتماد قبل المتابعة');
    setState(() => _isSubmitting = true);

    try {
      await _repository.reviewTransfer(
        transferId: widget.transferId,
        approvedQuantity: _approvedQuantity.toDouble(),
        reason: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : 'اعتماد تشغيلي معتمد',
        approved: true,
      );
      if (!mounted) return;
      _notify('تم اعتماد التحويل ${_order?.transferCode ?? widget.transferId} بنجاح');
      context.go('/transfers/${widget.transferId}/send');
    } catch (e) {
      if (!mounted) return;
      _notify('خطأ في الاعتماد: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _isSubmitting = true);
    try {
      await _repository.reviewTransfer(
        transferId: widget.transferId,
        approvedQuantity: 0,
        reason: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : 'تم الرفض بواسطة الإدارة',
        approved: false,
      );
      if (!mounted) return;
      _notify('تم تسجيل رفض طلب التحويل ${_order?.transferCode ?? widget.transferId}');
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      _notify('خطأ في الرفض: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
