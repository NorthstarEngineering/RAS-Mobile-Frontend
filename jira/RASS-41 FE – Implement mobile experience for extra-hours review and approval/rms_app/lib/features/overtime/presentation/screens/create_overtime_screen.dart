import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/repositories/http_overtime_repository.dart';
import '../../domain/repositories/overtime_repository.dart';

class _EmployeeChoice {
  const _EmployeeChoice({
    required this.id,
    required this.code,
    required this.name,
    required this.role,
    required this.hourlyRate,
    this.branchId,
  });

  final String id;
  final String code;
  final String name;
  final String role;
  final double hourlyRate;
  final String? branchId;
}

class _BranchChoice {
  const _BranchChoice({
    required this.id,
    required this.code,
    required this.name,
  });

  final String id;
  final String code;
  final String name;
}

class CreateOvertimeScreen extends StatefulWidget {
  const CreateOvertimeScreen({super.key, this.repository});

  final OvertimeRepository? repository;

  @override
  State<CreateOvertimeScreen> createState() => _CreateOvertimeScreenState();
}

class _CreateOvertimeScreenState extends State<CreateOvertimeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController(
    text: 'ضغط تشغيلي في تجهيز وجبات الغداء وتغطية عجز الوردية',
  );
  double _hours = 2.0;
  String _multiplier = '1.5x (عمل إضافي معتاد)';
  double _baseHourlyRate = 42.0;
  bool _isSubmitting = false;
  bool _isLoadingChoices = true;

  List<_EmployeeChoice> _employeeChoices = [];
  List<_BranchChoice> _branchChoices = [];
  String? _selectedEmployeeId;
  String? _selectedBranchId;

  double get _multiplierValue => _multiplier.startsWith('2') ? 2.0 : 1.5;

  double get _calculatedAmount => _hours * _baseHourlyRate * _multiplierValue;

  @override
  void initState() {
    super.initState();
    _loadChoices();
  }

  Future<void> _loadChoices() async {
    setState(() => _isLoadingChoices = true);
    final List<_EmployeeChoice> emps = [];
    final List<_BranchChoice> branches = [];

    final apiClient = sl.isRegistered<ApiClient>() ? sl<ApiClient>() : null;
    if (apiClient != null) {
      try {
        final empRes = await apiClient.get('/employees');
        if (empRes.success && empRes.data is List) {
          for (final item in (empRes.data as List).whereType<Map>()) {
            final id = item['id']?.toString() ?? '';
            final code = item['national_id']?.toString() ?? item['code']?.toString() ?? id;
            final fName = item['first_name_ar']?.toString() ?? item['name']?.toString() ?? '';
            final lName = item['last_name_ar']?.toString() ?? '';
            final fullName = '$fName $lName'.trim();
            final role = item['job_title']?.toString() ?? item['role']?.toString() ?? 'موظف';
            final rate = ((item['hourly_rate'] ?? item['overtimeRate'] ?? 42.0) as num).toDouble();
            final bId = item['branch_id']?.toString();
            if (id.isNotEmpty) {
              emps.add(_EmployeeChoice(
                id: id,
                code: code,
                name: fullName.isNotEmpty ? fullName : id,
                role: role,
                hourlyRate: rate > 0 ? rate : 42.0,
                branchId: bId,
              ));
            }
          }
        }
      } catch (_) {}

      try {
        final brRes = await apiClient.get('/branches');
        if (brRes.success && brRes.data is List) {
          for (final item in (brRes.data as List).whereType<Map>()) {
            final id = item['id']?.toString() ?? '';
            final code = item['code']?.toString() ?? id;
            final name = item['name_ar']?.toString() ?? item['name']?.toString() ?? id;
            if (id.isNotEmpty) {
              branches.add(_BranchChoice(id: id, code: code, name: name));
            }
          }
        }
      } catch (_) {}
    }

    if (emps.isEmpty) {
      emps.addAll([
        const _EmployeeChoice(
          id: 'emp_02',
          code: '1052',
          name: 'مصطفى خالد عثمان',
          role: 'طاهي خط ساخن • المطبخ الساخن',
          hourlyRate: 42.0,
          branchId: 'br_01',
        ),
        const _EmployeeChoice(
          id: 'emp_01',
          code: '1084',
          name: 'أحمد محمود سالم',
          role: 'مشرف صالة • محطة الخدمة 1',
          hourlyRate: 45.0,
          branchId: 'br_01',
        ),
        const _EmployeeChoice(
          id: 'emp_03',
          code: '1060',
          name: 'سارة محمود إبراهيم',
          role: 'مساعد بار ومشروبات',
          hourlyRate: 35.0,
          branchId: 'br_01',
        ),
      ]);
    }

    if (branches.isEmpty) {
      branches.add(const _BranchChoice(
        id: 'br_01',
        code: 'BR-01',
        name: 'الفرع الرئيسي - وسط البلد',
      ));
    }

    if (mounted) {
      setState(() {
        _employeeChoices = emps;
        _branchChoices = branches;
        _selectedEmployeeId = emps.first.id;
        _baseHourlyRate = emps.first.hourlyRate;
        _selectedBranchId = emps.first.branchId ?? branches.first.id;
        _isLoadingChoices = false;
      });
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final repo = widget.repository ??
          (sl.isRegistered<OvertimeRepository>()
              ? sl<OvertimeRepository>()
              : HttpOvertimeRepository());

      final selectedEmp = _employeeChoices.firstWhere(
        (e) => e.id == _selectedEmployeeId,
        orElse: () => _employeeChoices.first,
      );

      final newRecord = await repo.createOvertimeRecord(
        employeeId: selectedEmp.id,
        hours: _hours,
        reason: _reasonController.text.trim(),
        branchId: _selectedBranchId,
        rateMultiplier: _multiplierValue,
        hourlyRate: _baseHourlyRate,
        calculatedAmount: _calculatedAmount,
        employeeName: selectedEmp.name,
        role: selectedEmp.role,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تسجيل وإرسال طلب الساعات الإضافية للاعتماد وحفظه بقاعدة البيانات',
          ),
          backgroundColor: Color(0xFF2E8B2E),
        ),
      );
      context.pop(newRecord);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل تسجيل طلب الساعات الإضافية: ${e.toString().replaceAll("Exception: ", "")}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('إضافة ساعات عمل إضافية')),
      body: _isLoadingChoices
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.paddingMd),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              // Operational Source Banner
              Container(
                padding: const EdgeInsets.all(AppDimens.paddingMd),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'مصدر التسجيل:',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimens.paddingSm),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 225),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusFull,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'إدخال يدوي بإشراف المشرف',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSm.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.paddingMd),

              // Employee Selection Card
              Container(
                padding: const EdgeInsets.all(AppDimens.paddingLg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الموظف المستحق *',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedEmployeeId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: _employeeChoices.map((emp) {
                        return DropdownMenuItem<String>(
                          value: emp.id,
                          child: Text(
                            '${emp.name} (#${emp.code}) - ${emp.role}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final chosen = _employeeChoices.firstWhere((e) => e.id == val);
                          setState(() {
                            _selectedEmployeeId = val;
                            _baseHourlyRate = chosen.hourlyRate;
                            if (chosen.branchId != null) {
                              _selectedBranchId = chosen.branchId;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'فرع العمل *',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedBranchId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      items: _branchChoices.map((br) {
                        return DropdownMenuItem<String>(
                          value: br.id,
                          child: Text(
                            '${br.name} (${br.code})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedBranchId = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.paddingMd),

              // Overtime Hours & Multiplier
              Container(
                padding: const EdgeInsets.all(AppDimens.paddingLg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'عدد الساعات الإضافية',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '$_hours ساعة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.headlineSm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _hours,
                      min: 0.5,
                      max: 8.0,
                      divisions: 15,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _hours = val),
                    ),
                    const SizedBox(height: AppDimens.paddingSm),

                    // Multiplier
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _multiplier,
                      decoration: const InputDecoration(
                        labelText: 'معامل احتساب الأجر الإضافي',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calculate_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '1.5x (عمل إضافي معتاد)',
                          child: Text(
                            '1.5x (أيام العمل العادية)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: '2.0x (عطلات ومواسم رسمية)',
                          child: Text(
                            '2.0x (العطلات الرسمية والمواسم)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _multiplier = val ?? _multiplier),
                    ),
                    const SizedBox(height: AppDimens.paddingMd),

                    // Amount Preview Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF5EA),
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'المبلغ المستحق التقديري للموظف',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSm.copyWith(
                                color: const Color(0xFF2E8B2E),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${_calculatedAmount.toStringAsFixed(2)} ج.م',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMd.copyWith(
                              color: const Color(0xFF2E8B2E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.paddingMd),

              // Operational Justification
              Container(
                padding: const EdgeInsets.all(AppDimens.paddingLg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المبرر التشغيلي *',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'اذكر سبب طلب العمل الإضافي وموافقة الإشراف',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'مطلوب' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.paddingLg),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('إرسال طلب الساعات الإضافية للاعتماد'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
