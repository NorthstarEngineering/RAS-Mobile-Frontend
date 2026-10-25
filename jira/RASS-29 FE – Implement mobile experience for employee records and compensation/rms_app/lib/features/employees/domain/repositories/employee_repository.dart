import '../entities/employee.dart';

abstract class EmployeeRepository {
  Future<List<Employee>> getEmployees();
  Future<Employee?> getEmployeeById(String id);
  Future<void> updateEmployee(Employee employee);
  Future<Employee> createEmployee(Employee employee);
  Future<Map<String, dynamic>?> getCompensation(String employeeId);
  Future<List<Map<String, dynamic>>> getPayHistory(String employeeId);
  Future<void> deleteEmployee(String id);
}
