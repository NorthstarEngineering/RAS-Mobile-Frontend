import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/ras_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../employees/domain/entities/employee.dart';
import '../../../employees/domain/repositories/employee_repository.dart';

class AttendanceListScreen extends StatefulWidget {
  const AttendanceListScreen({super.key});

  @override
  State<AttendanceListScreen> createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends State<AttendanceListScreen> {
  List<Employee> _employees = [];
  bool _loading = true;
  String? _error;
  String? _workingEmployee;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final employees = await sl<EmployeeRepository>().getEmployees();
      if (mounted) {
        setState(() {
          _employees = employees;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = arabicApiMessage(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _record(String employeeId, {required bool checkIn}) async {
    setState(() => _workingEmployee = employeeId);
    try {
      if (checkIn) {
        await sl<RasApi>().checkIn(employeeId);
      } else {
        await sl<RasApi>().checkOut(employeeId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            checkIn ? 'تم تسجيل الحضور بنجاح.' : 'تم تسجيل الانصراف بنجاح.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(arabicApiMessage(error)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _workingEmployee = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_forward),
          onPressed: () => context.pop(),
        ),
        title: Text('تسجيل الحضور والانصراف', style: AppTypography.headlineSm),
        actions: [
          IconButton(
            onPressed: _loadEmployees,
            icon: const Icon(Symbols.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.margin),
              child: Text(
                'سجّل الحضور أو الانصراف لموظفي الفرع. يعتمد الخادم على صلاحيات حسابك ونطاق الفرع.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.secondary,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          TextButton(
                            onPressed: _loadEmployees,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    )
                  : _employees.isEmpty
                  ? const Center(child: Text('لا يوجد موظفون نشطون'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.margin),
                      itemCount: _employees.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final employee = _employees[index];
                        final busy = _workingEmployee == employee.id;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  employee.name,
                                  style: AppTypography.bodyMd.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  employee.role,
                                  style: AppTypography.bodySm,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed:
                                            busy ||
                                                !employee.status.titleArabic
                                                    .startsWith('نشط')
                                            ? null
                                            : () => _record(
                                                employee.id,
                                                checkIn: true,
                                              ),
                                        icon: const Icon(Symbols.login),
                                        label: busy
                                            ? const Text('جارٍ التسجيل')
                                            : const Text('تسجيل حضور'),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed:
                                            busy ||
                                                !employee.status.titleArabic
                                                    .startsWith('نشط')
                                            ? null
                                            : () => _record(
                                                employee.id,
                                                checkIn: false,
                                              ),
                                        icon: const Icon(Symbols.logout),
                                        label: const Text('تسجيل انصراف'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                0,
                AppSpacing.margin,
                AppSpacing.md,
              ),
              child: Text(
                'سجل الحضور التاريخي غير متاح في واجهة الخادم الحالية.',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.secondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
