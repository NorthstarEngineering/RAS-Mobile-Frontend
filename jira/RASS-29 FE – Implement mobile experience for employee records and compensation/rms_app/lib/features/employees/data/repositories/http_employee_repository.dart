import '../../../../core/network/api_client.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/employees_remote_data_source.dart';

class HttpEmployeeRepository implements EmployeeRepository {
  HttpEmployeeRepository({
    EmployeesRemoteDataSource? remoteDataSource,
    ApiClient? apiClient,
  }) : _remoteDataSource = remoteDataSource ??
            EmployeesRemoteDataSource(apiClient: apiClient ?? ApiClient());

  final EmployeesRemoteDataSource _remoteDataSource;

  // In-memory cache strictly reflecting authoritative server responses
  final List<Employee> _cachedEmployees = [];

  @override
  Future<List<Employee>> getEmployees() async {
    final data = await _remoteDataSource.getEmployees();
    final list = data.map(_mapJsonToEmployee).toList();
    _cachedEmployees.clear();
    _cachedEmployees.addAll(list);
    return List.unmodifiable(_cachedEmployees);
  }

  @override
  Future<Employee?> getEmployeeById(String id) async {
    final data = await _remoteDataSource.getEmployeeById(id);
    if (data != null) {
      final employee = _mapJsonToEmployee(data);
      final index = _cachedEmployees.indexWhere(
        (e) => e.id == employee.id || e.code == employee.code,
      );
      if (index >= 0) {
        _cachedEmployees[index] = employee;
      } else {
        _cachedEmployees.add(employee);
      }
      return employee;
    }
    return null;
  }

  @override
  Future<void> updateEmployee(Employee employee) async {
    final payload = _mapEmployeeToJson(employee);
    await _remoteDataSource.updateEmployee(employee.id, payload);

    final index = _cachedEmployees.indexWhere(
      (e) => e.id == employee.id || e.code == employee.code,
    );
    if (index >= 0) {
      _cachedEmployees[index] = employee;
    } else {
      _cachedEmployees.add(employee);
    }
  }

  @override
  Future<Employee> createEmployee(Employee employee) async {
    final payload = _mapEmployeeToJson(employee);
    final data = await _remoteDataSource.createEmployee(payload);
    final created = _mapJsonToEmployee(data);
    _cachedEmployees.add(created);
    return created;
  }

  @override
  Future<Map<String, dynamic>?> getCompensation(String employeeId) async {
    return await _remoteDataSource.getCompensation(employeeId);
  }

  @override
  Future<List<Map<String, dynamic>>> getPayHistory(String employeeId) async {
    return await _remoteDataSource.getPayHistory(employeeId);
  }

  @override
  Future<void> deleteEmployee(String id) async {
    await _remoteDataSource.deleteEmployee(id);
    _cachedEmployees.removeWhere((e) => e.id == id || e.code == id);
  }

  Employee _mapJsonToEmployee(Map<String, dynamic> json) {
    final statusStr = (json['status'] ?? 'active').toString();
    EmployeeStatus status;
    switch (statusStr) {
      case 'activeOnShift':
        status = EmployeeStatus.activeOnShift;
        break;
      case 'onLeave':
        status = EmployeeStatus.onLeave;
        break;
      case 'suspended':
        status = EmployeeStatus.suspended;
        break;
      case 'active':
      default:
        status = EmployeeStatus.active;
        break;
    }

    final wageTypeStr = (json['wageType'] ?? 'monthly').toString();
    final wageType =
        wageTypeStr == 'hourly' ? WageType.hourly : WageType.monthly;

    final id = (json['id'] ?? '').toString();
    final code = (json['code'] ?? id).toString();
    final firstName = (json['firstNameAr'] ?? '').toString();
    final lastName = (json['lastNameAr'] ?? '').toString();
    final fullName = (json['name'] ?? '$firstName $lastName').toString().trim();
    final role = (json['role'] ?? json['jobTitle'] ?? 'موظف تشغيل').toString();
    final branchName =
        (json['branchName'] ?? 'الفرع الرئيسي - وسط البلد').toString();
    final branchCode = (json['branchCode'] ?? '#01').toString();
    final managerName =
        (json['managerName'] ?? 'م. ألفاريز (مدير فرع)').toString();
    final phone = (json['phone'] ?? '').toString();
    final hourlyRate = (json['hourlyRate'] as num?)?.toDouble() ?? 0.0;
    final baseSalary = (json['baseSalary'] as num?)?.toDouble() ??
        (wageType == WageType.hourly && hourlyRate > 0 ? hourlyRate : 0.0);
    final effectiveSalary = wageType == WageType.hourly && baseSalary == 0.0 && hourlyRate > 0
        ? hourlyRate
        : baseSalary;
    final overtimeRate = (json['overtimeRate'] as num?)?.toDouble() ?? 35.0;
    final totalHours =
        (json['totalHoursThisMonth'] as num?)?.toDouble() ?? 0.0;
    final department = (json['department'] ?? 'FOH').toString();

    return Employee(
      id: id,
      code: code,
      name: fullName.isNotEmpty ? fullName : 'موظف',
      role: role,
      branchName: branchName,
      branchCode: branchCode,
      status: status,
      wageType: wageType,
      baseSalary: effectiveSalary,
      overtimeRate: overtimeRate,
      phone: phone,
      managerName: managerName,
      totalHoursThisMonth: totalHours,
      department: department,
    );
  }

  Map<String, dynamic> _mapEmployeeToJson(Employee employee) {
    return {
      'id': employee.id,
      'code': employee.code,
      'name': employee.name,
      'role': employee.role,
      'jobTitle': employee.role,
      'branchName': employee.branchName,
      'branchCode': employee.branchCode,
      'status': employee.status.name,
      'wageType': employee.wageType.name,
      'baseSalary': employee.baseSalary,
      'hourlyRate': employee.wageType == WageType.hourly
          ? employee.baseSalary
          : 0.0,
      'overtimeRate': employee.overtimeRate,
      'phone': employee.phone,
      'managerName': employee.managerName,
      'totalHoursThisMonth': employee.totalHoursThisMonth,
      'department': employee.department,
    };
  }
}
