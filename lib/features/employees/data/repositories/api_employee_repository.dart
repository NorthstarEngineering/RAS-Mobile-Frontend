import '../../../../core/network/authenticated_api.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';

class ApiEmployeeRepository implements EmployeeRepository {
  ApiEmployeeRepository(this.api);

  final AuthenticatedApi api;

  @override
  Future<List<Employee>> getEmployees() async {
    final data = await api.get('/api/v1/employees');
    final values = data is List ? data : data['employees'];
    if (values is! List) return const [];
    return values.whereType<Map>().map(_fromJson).toList();
  }

  @override
  Future<Employee?> getEmployeeById(String id) async {
    final data = await api.get('/api/v1/employees/$id');
    return _fromJson(
      data is Map && data['employee'] is Map ? data['employee'] : data,
    );
  }

  @override
  Future<void> updateEmployee(Employee employee) async {
    await api.patch('/api/v1/employees/${employee.id}', {
      'name': employee.name,
      'phone': employee.phone,
      'job_title': employee.role,
      'payment_type': employee.wageType == WageType.hourly
          ? 'daily'
          : 'monthly',
      'payment_amount': employee.baseSalary,
    });
  }

  Future<Employee> createEmployee({
    required String name,
    required String phone,
    required String nationalId,
    required String branchId,
    required String paymentType,
    required double paymentAmount,
    required String hireDate,
    String? jobTitle,
    String? email,
    String? address,
  }) async {
    final data = await api.post('/api/v1/employees', {
      'name': name,
      'phone': phone,
      'national_id': nationalId,
      'branch_id': branchId,
      'payment_type': paymentType,
      'payment_amount': paymentAmount,
      'hire_date': hireDate,
      if (jobTitle != null) 'job_title': jobTitle,
      if (email != null && email.isNotEmpty) 'email': email,
      if (address != null && address.isNotEmpty) 'address': address,
    });
    return _fromJson(
      data is Map && data['employee'] is Map ? data['employee'] : data,
    );
  }

  Employee _fromJson(Map value) {
    final active = value['active'] == true;
    final paymentType = '${value['payment_type']}';
    final amount = (value['payment_amount'] as num?)?.toDouble() ?? 0;
    return Employee(
      id: '${value['id'] ?? ''}',
      code: '${value['id'] ?? ''}',
      name: '${value['name'] ?? ''}',
      role: '${value['job_title'] ?? ''}',
      branchName: '${value['branch_id'] ?? ''}',
      branchCode: '${value['branch_id'] ?? ''}',
      status: active ? EmployeeStatus.active : EmployeeStatus.suspended,
      wageType: paymentType == 'daily' ? WageType.hourly : WageType.monthly,
      baseSalary: amount,
      overtimeRate: 0,
      phone: '${value['phone'] ?? ''}',
      managerName: '',
      totalHoursThisMonth: 0,
      department: '',
    );
  }
}
