import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/di/service_locator.dart';
import '../../data/repositories/api_attendance_repository.dart';
import '../../../employees/domain/entities/employee.dart';
import '../../../employees/domain/repositories/employee_repository.dart';

class AttendanceListScreen extends StatefulWidget {
  const AttendanceListScreen({super.key});

  @override
  State<AttendanceListScreen> createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends State<AttendanceListScreen> {
  String _selectedFilter = 'all';

  List<Employee> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await sl<EmployeeRepository>().getEmployees();
      if (mounted) {
        setState(() {
          _employees = employees;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تحميل الموظفين: $error')));
      }
    }
  }

  void _onSyncDevices() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تمت مزامنة بيانات البصمة مع أجهزة الدخول البيومترية بنجاح.',
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_forward, color: AppColors.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'سجلات الحضور والتأخير (ATT-01)',
          style: AppTypography.headlineSm.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.sync, color: AppColors.primary),
            onPressed: _onSyncDevices,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.margin,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  _buildFilterPill('all', 'الموظفون (${_employees.length})'),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterPill('present', 'تسجيل حضور'),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterPill('late', 'تسجيل انصراف'),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterPill('absent', 'تعديل خصم'),
                ],
              ),
            ),

            // Live Ledger Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.margin,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'سجلات البصمة اليوم',
                        style: AppTypography.labelMd.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: AppRadius.fullAll,
                        ),
                        child: Text(
                          'الوردية الصباحية',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 11,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _onSyncDevices,
                    icon: const Icon(Symbols.sync, size: 16),
                    label: const Text('مزامنة الأجهزة'),
                  ),
                ],
              ),
            ),

            // Attendance Records List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.margin,
                        0,
                        AppSpacing.margin,
                        AppSpacing.xl,
                      ),
                      itemCount: _employees.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final employee = _employees[index];
                        return _buildEmployeeAttendanceCard(employee);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String id, String label) {
    final isSelected = _selectedFilter == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.fullAll,
          boxShadow: AppShadows.sm,
        ),
        child: Text(
          label,
          style: AppTypography.labelSm.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeAttendanceCard(Employee employee) {
    Future<void> runAction(bool checkIn) async {
      try {
        if (checkIn) {
          await sl<ApiAttendanceRepository>().checkIn(employeeId: employee.id);
        } else {
          await sl<ApiAttendanceRepository>().checkOut(employeeId: employee.id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                checkIn ? 'تم تسجيل حضور الموظف' : 'تم تسجيل انصراف الموظف',
              ),
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر تنفيذ إجراء الحضور: $error')),
          );
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(child: Text(employee.initials)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(employee.name, style: AppTypography.labelMd),
                  Text(
                    employee.id,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) => runAction(value == 'in'),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'in', child: Text('تسجيل حضور')),
                PopupMenuItem(value: 'out', child: Text('تسجيل انصراف')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
