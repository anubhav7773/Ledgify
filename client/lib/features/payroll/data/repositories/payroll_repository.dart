import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../domain/models/employee_model.dart';
import '../domain/services/payroll_service.dart';

/// Repository managing employee master profiles, monthly salary calculations, and payroll voucher commits.
class PayrollRepository {
  final SupabaseClient _client;
  final PayrollService _payrollService;

  PayrollRepository({
    SupabaseClient? client,
    PayrollService? payrollService,
  })  : _client = client ?? SupabaseClientService.client,
        _payrollService = payrollService ?? PayrollService();

  /// Fetches employees for the current business
  Future<List<EmployeeModel>> fetchEmployees({bool activeOnly = true}) async {
    return await executeSafely<List<EmployeeModel>>(() async {
      var query = _client.from('employees_payroll').select();

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.order('employee_code');
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) => EmployeeModel.fromJson(json as Map<String, dynamic>)).toList();
    });
  }

  /// Creates or updates an employee master record
  Future<EmployeeModel> createOrUpdateEmployee(EmployeeModel employee) async {
    return await executeSafely<EmployeeModel>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final Map<String, dynamic> payload = employee.toJson();
      payload['business_id'] = businessId;

      if (employee.id.isEmpty) {
        final response = await _client
            .from('employees_payroll')
            .insert(payload)
            .select()
            .single();
        return EmployeeModel.fromJson(response as Map<String, dynamic>);
      } else {
        final response = await _client
            .from('employees_payroll')
            .update(payload)
            .eq('id', employee.id)
            .select()
            .single();
        return EmployeeModel.fromJson(response as Map<String, dynamic>);
      }
    });
  }

  /// Dry-run preview of monthly payroll calculation
  Future<PayrollPreviewSummary> previewMonthlyPayroll(String monthYear) async {
    return await _payrollService.previewMonthlyPayroll(monthYear: monthYear);
  }

  /// Commits double-entry monthly payroll voucher
  Future<String> executePayrollRun(String monthYear, DateTime paymentDate) async {
    return await _payrollService.executePayrollRun(monthYear: monthYear, paymentDate: paymentDate);
  }

  /// Exports Form 24Q quarterly e-TDS return
  Future<Map<String, dynamic>> exportForm24Q(String financialYear, String quarter) async {
    return await _payrollService.exportForm24Q(financialYear: financialYear, quarter: quarter);
  }
}
