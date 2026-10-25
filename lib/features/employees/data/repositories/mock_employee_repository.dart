import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';

class MockEmployeeRepository implements EmployeeRepository {
  final List<Employee> _employees = [
    const Employee(
      id: '1',
      code: '1048',
      name: 'كريم عبد العزيز سالم',
      role: 'مشرف صالة وكاشير أول',
      branchName: 'الفرع الرئيسي - وسط البلد',
      branchCode: '#01',
      status: EmployeeStatus.active,
      wageType: WageType.monthly,
      baseSalary: 4500,
      overtimeRate: 35,
      phone: '01098234112',
      managerName: 'م. ألفاريز (مدير فرع)',
      totalHoursThisMonth: 172.5,
      department: 'FOH',
    ),
    const Employee(
      id: '2',
      code: '1052',
      name: 'مصطفى خالد عثمان',
      role: 'طاهي خط ساخن (Line Cook)',
      branchName: 'الفرع الرئيسي - وسط البلد',
      branchCode: '#01',
      status: EmployeeStatus.activeOnShift,
      wageType: WageType.monthly,
      baseSalary: 5200,
      overtimeRate: 40,
      phone: '01155443219',
      managerName: 'م. ألفاريز (مدير فرع)',
      totalHoursThisMonth: 184.0,
      department: 'BOH',
    ),
    const Employee(
      id: '3',
      code: '1060',
      name: 'سارة محمود إبراهيم',
      role: 'مساعد بار ومشروبات (Barista)',
      branchName: 'الفرع الرئيسي - وسط البلد',
      branchCode: '#01',
      status: EmployeeStatus.active,
      wageType: WageType.hourly,
      baseSalary: 30, // hourly rate
      overtimeRate: 45,
      phone: '01288776655',
      managerName: 'م. ألفاريز (مدير فرع)',
      totalHoursThisMonth: 140.0,
      department: 'FOH',
    ),
    const Employee(
      id: '4',
      code: '1074',
      name: 'أحمد نبيل رضوان',
      role: 'كابتن صالة (Head Waiter)',
      branchName: 'الفرع الرئيسي - وسط البلد',
      branchCode: '#01',
      status: EmployeeStatus.activeOnShift,
      wageType: WageType.monthly,
      baseSalary: 4800,
      overtimeRate: 38,
      phone: '01011223344',
      managerName: 'م. ألفاريز (مدير فرع)',
      totalHoursThisMonth: 160.0,
      department: 'FOH',
    ),
  ];

  @override
  Future<List<Employee>> getEmployees() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_employees);
  }

  @override
  Future<Employee?> getEmployeeById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    try {
      return _employees.firstWhere((e) => e.id == id || e.code == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateEmployee(Employee employee) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final index = _employees.indexWhere((e) => e.id == employee.id);
    if (index != -1) {
      _employees[index] = employee;
    }
  }
}
