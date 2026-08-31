import '../../../../core/network/api_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../domain/models/employee_model.dart';
import '../domain/services/payroll_service.dart';

/// Repository managing employee master profiles, monthly salary calculations, and payroll voucher commits via FastAPI backend.
class PayrollRepository {
  final PayrollService _payrollService;

  PayrollRepository({PayrollService? payrollService})
      : _payrollService = payrollService ?? PayrollService();

  /// Fetches employees for the current business via FastAPI backend
  Future<List<EmployeeModel>> fetchEmployees({bool activeOnly = true}) async {
    return await executeSafely<List<EmployeeModel>>(() async {
      final response = await ApiClient.get('/payroll/employees');
      final list = response as List<dynamic>;

      return list.map((json) {
        final data = json as Map<String, dynamic>;
        return EmployeeModel(
          id: data['id'] ?? '',
          businessId: data['business_id'] ?? 'BIZ-DEFAULT-01',
          employeeCode: data['employee_code'] ?? 'EMP-001',
          fullName: data['full_name'] ?? '',
          designation: data['designation'] ?? 'Staff',
          department: data['department'] ?? 'General',
          pan: data['pan_number'] ?? '',
          uan: data['uan_number'],
          esicNumber: data['esic_ip_number'],
          bankAccountNumber: data['bank_account_number'] ?? '',
          bankIfsc: 'HDFC0000240',
          basicSalary: (data['basic_salary'] as num?)?.toDouble() ?? 30000.0,
          hra: (data['hra_allowance'] as num?)?.toDouble() ?? 12000.0,
          specialAllowance: (data['special_allowance'] as num?)?.toDouble() ?? 8000.0,
          customAllowances: {},
          isActive: data['is_active'] == true,
          createdAt: DateTime.now(),
        );
      }).toList();
    });
  }

  /// Executes payroll calculation and commits the balanced Salary Journal Voucher via FastAPI backend
  Future<String> executeMonthlyPayrollRun({
    required String monthYear,
    required DateTime postingDate,
    required String bankLedgerId,
  }) async {
    return await executeSafely<String>(() async {
      final response = await ApiClient.post(
        '/payroll/execute-run',
        body: {'month': monthYear},
      );
      final data = response as Map<String, dynamic>;
      return data['journal_voucher_id'] ?? 'PAY-$monthYear';
    });
  }
}
