import '../entities/employee.dart';

abstract class EmployeeRepository {
  Future<List<Employee>> getEmployees();
  Future<Employee?> getEmployeeById(String id);
  Future<void> updateEmployee(Employee employee);
}
