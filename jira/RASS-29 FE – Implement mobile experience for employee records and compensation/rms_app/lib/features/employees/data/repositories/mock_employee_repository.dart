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

  @override
  Future<Employee> createEmployee(Employee employee) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final newId = employee.id.isNotEmpty ? employee.id : '${_employees.length + 1}';
    final created = Employee(
      id: newId,
      code: employee.code.isNotEmpty ? employee.code : '10${90 + _employees.length}',
      name: employee.name,
      role: employee.role,
      branchName: employee.branchName,
      branchCode: employee.branchCode,
      status: employee.status,
      wageType: employee.wageType,
      baseSalary: employee.baseSalary,
      overtimeRate: employee.overtimeRate,
      phone: employee.phone,
      managerName: employee.managerName,
      totalHoursThisMonth: employee.totalHoursThisMonth,
      department: employee.department,
    );
    _employees.add(created);
    return created;
  }

  @override
  Future<Map<String, dynamic>?> getCompensation(String employeeId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final emp = await getEmployeeById(employeeId);
    if (emp == null) return null;
    final totalAllowances = emp.wageType == WageType.monthly ? 600.0 : 150.0;
    final totalDeductions = 150.0;
    final gross = emp.baseSalary + totalAllowances;
    return {
      'employeeId': emp.id,
      'employeeName': emp.name,
      'employeeCode': emp.code,
      'jobTitle': emp.role,
      'branchName': emp.branchName,
      'wageType': emp.wageType.name,
      'baseSalary': emp.baseSalary,
      'hourlyRate': emp.wageType == WageType.hourly ? emp.baseSalary : 0.0,
      'overtimeRate': emp.overtimeRate,
      'housingAllowance': 400.0,
      'transportAllowance': 200.0,
      'insuranceDeduction': totalDeductions,
      'totalAllowances': totalAllowances,
      'totalDeductions': totalDeductions,
      'grossPay': gross,
      'netEstimatedPay': gross - totalDeductions,
      'effectiveDate': '2023-01-15',
      'reviewDate': '01 مايو 2024',
      'status': 'نشط بالخدمة',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getPayHistory(String employeeId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final emp = await getEmployeeById(employeeId);
    if (emp == null) return [];
    return [
      {
        'id': 'pay_01',
        'employeeId': emp.id,
        'periodMonth': 3,
        'periodYear': 2024,
        'monthLabel': 'مارس 2024',
        'dateLabel': '31 مارس 2024',
        'baseAmount': emp.baseSalary,
        'allowances': 400.0,
        'deductions': 250.0,
        'overtime': 0.0,
        'netPayout': emp.baseSalary + 400.0 - 250.0,
        'status': 'مسدد عبر البنك',
        'referenceNo': 'PAY-2024-03-${emp.code}',
        'paymentDate': '2024-03-31',
      },
    ];
  }

  @override
  Future<void> deleteEmployee(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _employees.removeWhere((e) => e.id == id || e.code == id);
  }
}
