import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/rms_operations.dart';
import '../../../../core/widgets/rms_primary_button.dart';
import '../../data/repositories/http_overtime_repository.dart';
import '../../domain/entities/overtime_record.dart';
import '../../domain/repositories/overtime_repository.dart';

class OvertimeApprovalScreen extends StatefulWidget {
  const OvertimeApprovalScreen({
    super.key,
    this.initialRecord,
    this.recordId,
    this.repository,
  });

  final OvertimeRecord? initialRecord;
  final String? recordId;
  final OvertimeRepository? repository;

  @override
  State<OvertimeApprovalScreen> createState() => _OvertimeApprovalScreenState();
}

class _OvertimeApprovalScreenState extends State<OvertimeApprovalScreen> {
  OvertimeRecord? _record;
  bool _isLoading = true;
  bool _isOperating = false;
  bool _noRecordsFound = false;
  String? _errorMessage;

  OvertimeRepository get _repo =>
      widget.repository ??
      (sl.isRegistered<OvertimeRepository>()
          ? sl<OvertimeRepository>()
          : HttpOvertimeRepository());

  @override
  void initState() {
    super.initState();
    if (widget.initialRecord != null) {
      _record = widget.initialRecord;
      _isLoading = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_record == null) {
      final extra = GoRouterState.of(context).extra;
      if (extra is OvertimeRecord) {
        _record = extra;
        _isLoading = false;
      } else if (extra is String) {
        _loadRecord(extra);
      } else if (widget.recordId != null) {
        _loadRecord(widget.recordId!);
      } else {
        _loadFirstPendingRecord();
      }
    }
  }

  Future<void> _loadRecord(String id) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _noRecordsFound = false;
    });
    try {
      final rec = await _repo.getOvertimeRecordById(id);
      if (mounted) {
        if (rec != null) {
          setState(() {
            _record = rec;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _noRecordsFound = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFirstPendingRecord() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _noRecordsFound = false;
    });
    try {
      final list = await _repo.getOvertimeRecords(status: OvertimeStatus.pendingReview);
      if (mounted) {
        if (list.isNotEmpty) {
          setState(() {
            _record = list.first;
            _isLoading = false;
          });
        } else {
          // If no pending, check all
          final all = await _repo.getOvertimeRecords();
          if (mounted) {
            if (all.isNotEmpty) {
              setState(() {
                _record = all.first;
                _isLoading = false;
              });
            } else {
              setState(() {
                _isLoading = false;
                _noRecordsFound = true;
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_noRecordsFound || _record == null) {
      return RmsOpsScaffold(
        title: 'اعتماد الساعات الإضافية',
        showProfile: false,
        children: [
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'لا توجد معاملات ساعات إضافية تتطلب الاعتماد حالياً',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ],
      );
    }

    final isApproved = _record!.status == OvertimeStatus.approved;
    final isRejected = _record!.status == OvertimeStatus.rejected;
    final isPending = _record!.status == OvertimeStatus.pendingReview;

    final statusText = isApproved
        ? 'معاملة معتمدة رسمياً ومرحلة للرواتب'
        : (isRejected ? 'معاملة مرفوضة وغير مرحلة للرواتب' : 'معاملة معلقة للمراجعة النهائية');
    final statusColor = isApproved
        ? AppColors.success
        : (isRejected ? AppColors.error : AppColors.warning);

    return RmsOpsScaffold(
      title: 'اعتماد الساعات الإضافية',
      showProfile: false,
      children: [
        RmsOpsStatus(
          statusText,
          color: statusColor,
        ),
        const SizedBox(height: 12),
        _employeeSummary(_record!),
        const SizedBox(height: 12),
        const RmsOpsBanner(
          title: 'تنبيه قانوني وتشغيلي صارم',
          message:
              'لا يتم إدراج أي مبالغ إضافية في كشف الرواتب إلا بعد موافقة المدير المباشر والاعتماد الرسمي.',
          color: AppColors.errorContainer,
        ),
        const SizedBox(height: 12),
        _decisionCard(_record!, isPending, isApproved, isRejected),
        const SizedBox(height: 12),
        _approvalSignature(_record!, isApproved, isRejected),
      ],
    );
  }

  Widget _employeeSummary(OvertimeRecord record) {
    final estimatedHourly = record.hours > 0
        ? (record.overtimePay / (record.hours * record.rateMultiplier)).toStringAsFixed(2)
        : '42.00';

    return RmsOpsSection(
      title: '${record.employeeName} • ${record.role}',
      icon: Icons.soup_kitchen_outlined,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: RmsOpsMetric(
                  label: 'تاريخ الوردية',
                  value: record.date,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RmsOpsMetric(
                  label: 'مسؤول المراجعة',
                  value: record.approvedByName ??
                      (record.trigger == OvertimeTrigger.fingerprint
                          ? 'بصمة بيومترية'
                          : 'إشراف الفرع'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: RmsOpsMetric(
                  label: 'الساعات الإضافية',
                  value: '${record.hours.toStringAsFixed(1)} ساعات',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RmsOpsMetric(
                  label: 'إجمالي المستحق',
                  value: '${record.overtimePay.toStringAsFixed(2)} ج.م',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('معدل الأجر: $estimatedHourly ج.م / ساعة (${record.rateMultiplier.toStringAsFixed(1)}x)'),
        ],
      ),
    );
  }

  Widget _decisionCard(
    OvertimeRecord record,
    bool isPending,
    bool isApproved,
    bool isRejected,
  ) {
    final cardStatus = isApproved
        ? 'تم الاعتماد رسمياً ومحفوظ بقاعدة البيانات'
        : (isRejected ? 'تم الرفض ومسجل بسجل التدقيق' : 'الطلب #${record.id}');
    final cardColor = isApproved
        ? AppColors.success
        : (isRejected ? AppColors.error : AppColors.secondary);

    return RmsOpsSection(
      title: 'اتخاذ الإجراء التشغيلي',
      icon: Icons.tune,
      child: Column(
        children: [
          RmsOpsStatus(
            cardStatus,
            color: cardColor,
          ),
          const SizedBox(height: 12),
          RmsPrimaryButton(
            label: 'الموافقة واعتماد الصرف في الرواتب',
            icon: Icons.check_circle_outline,
            isLoading: _isOperating,
            onPressed: (isPending && !_isOperating) ? _approve : null,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (isPending && !_isOperating) ? _reject : null,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('رفض طلب الساعات الإضافية'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _approvalSignature(
    OvertimeRecord record,
    bool isApproved,
    bool isRejected,
  ) {
    final approver = record.approvedByName ?? 'المدير التنفيذي • اعتماد وتوقيع رقمي نشط';
    final stateSub = isApproved
        ? 'معتمد ومرحل لمسير الرواتب في SQLite'
        : (isRejected ? 'مرفوض ومحفوظ بسجل التدقيق' : 'بانتظار توقيع الاعتماد النهائي');

    return ListTile(
      leading: const Icon(Icons.verified_outlined, color: AppColors.primary),
      title: Text(approver),
      subtitle: Text(stateSub),
    );
  }

  void _approve() async {
    if (_record == null) return;
    setState(() => _isOperating = true);

    try {
      final updated = await _repo.approveOvertimeRecord(
        id: _record!.id,
        isApproved: true,
        decisionReason: 'معتمد للصرف النهائي من الإدارة التنفيذية وترحيل الأثر المالي للرواتب',
      );
      if (!mounted) return;
      setState(() {
        _record = updated;
        _isOperating = false;
      });
      _showDecision('تم اعتماد الساعات الإضافية وترحيل الأثر المالي لسجل الرواتب بنجاح');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOperating = false);
      _showDecision('فشل اعتماد الساعات الإضافية: ${e.toString().replaceAll("Exception: ", "")}');
    }
  }

  void _reject() async {
    if (_record == null) return;

    final reasonController = TextEditingController(
      text: 'مرفوض لعدم استيفاء الشروط التشغيلية وموافقة الإدارة',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سبب رفض الساعات الإضافية'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'سبب الرفض المسجل في سجل التدقيق',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الرفض', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isOperating = true);

    try {
      final updated = await _repo.approveOvertimeRecord(
        id: _record!.id,
        isApproved: false,
        decisionReason: reasonController.text.trim().isNotEmpty
            ? reasonController.text.trim()
            : 'مرفوض لعدم استيفاء الشروط التشغيلية',
      );
      if (!mounted) return;
      setState(() {
        _record = updated;
        _isOperating = false;
      });
      _showDecision('تم تسجيل قرار رفض الساعات الإضافية في سجل التدقيق بنجاح');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOperating = false);
      _showDecision('فشل رفض الساعات الإضافية: ${e.toString().replaceAll("Exception: ", "")}');
    }
  }

  void _showDecision(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
