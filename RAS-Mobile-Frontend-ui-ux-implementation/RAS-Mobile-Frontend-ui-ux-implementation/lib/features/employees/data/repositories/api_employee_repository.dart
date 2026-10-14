import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';

class ApiEmployeeRepository implements EmployeeRepository {
  ApiEmployeeRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<Employee>> getEmployees() async {
    final body = await _api.get('/employees');
    if (body is! Map || body['employees'] is! List) {
      throw const ApiException(
        502,
        'invalid_response',
        'Invalid employee response',
      );
    }
    return (body['employees'] as List).whereType<Map>().map(_fromJson).toList();
  }

  @override
  Future<Employee?> getEmployeeById(String id) async {
    try {
      final body = await _api.get('/employees/$id');
      if (body is! Map) {
        throw const ApiException(
          502,
          'invalid_response',
          'Invalid employee response',
        );
      }
      return _fromJson(body);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Employee _fromJson(Map raw) {
    final json = Map<String, dynamic>.from(raw);
    final id = json['id']?.toString() ?? '';
    final active = json['active'] == true;
    final type = json['payment_type']?.toString() == 'monthly'
        ? WageType.monthly
        : WageType.daily;
    return Employee(
      id: id,
      code: id,
      name: json['name']?.toString() ?? '',
      role: json['job_title']?.toString() ?? 'موظف',
      branchName: json['branch_id']?.toString() ?? '',
      branchCode: '',
      status: active ? EmployeeStatus.active : EmployeeStatus.suspended,
      wageType: type,
      baseSalary: (json['payment_amount'] as num?)?.toDouble() ?? 0,
      overtimeRate: 0,
      phone: json['phone']?.toString() ?? '',
      managerName: '',
    );
  }

  @override
  Future<void> updateEmployee(Employee employee) async {
    await _api.patch('/employees/${employee.id}', {
      'name': employee.name,
      'phone': employee.phone,
      'job_title': employee.role,
      'payment_type': employee.wageType == WageType.monthly
          ? 'monthly'
          : 'daily',
      'payment_amount': employee.baseSalary,
    });
  }
}
