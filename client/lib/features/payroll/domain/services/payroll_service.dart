import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../models/salary_slip_model.dart';

/// Summary of a calculated monthly payroll batch
class PayrollPreviewSummary {
  final String monthYear;
  final int employeeCount;
  final double totalGross;
  final double totalEpfEmployee;
  final double totalEpfEmployer;
  final double totalEsiEmployee;
  final double totalEsiEmployer;
  final double totalProfessionalTax;
  final double totalTdsSalary;
  final double totalNetPayable;
  final List<SalarySlipModel> salarySlips;

  const PayrollPreviewSummary({
    required this.monthYear,
    required this.employeeCount,
    required this.totalGross,
    required this.totalEpfEmployee,
    required this.totalEpfEmployer,
    required this.totalEsiEmployee,
    required this.totalEsiEmployer,
    required this.totalProfessionalTax,
    required this.totalTdsSalary,
    required this.totalNetPayable,
    required this.salarySlips,
  });

  factory PayrollPreviewSummary.fromJson(Map<String, dynamic> json) {
    final rawSlips = json['employees'] as List<dynamic>? ?? [];
    final month = json['month_year'] as String? ?? '2026-08';

    return PayrollPreviewSummary(
      monthYear: month,
      employeeCount: json['employee_count'] as int? ?? 0,
      totalGross: (json['total_gross'] as num?)?.toDouble() ?? 0.00,
      totalEpfEmployee: (json['total_epf_employee'] as num?)?.toDouble() ?? 0.00,
      totalEpfEmployer: (json['total_epf_employer'] as num?)?.toDouble() ?? 0.00,
      totalEsiEmployee: (json['total_esi_employee'] as num?)?.toDouble() ?? 0.00,
      totalEsiEmployer: (json['total_esi_employer'] as num?)?.toDouble() ?? 0.00,
      totalProfessionalTax: (json['total_professional_tax'] as num?)?.toDouble() ?? 0.00,
      totalTdsSalary: (json['total_tds_salary'] as num?)?.toDouble() ?? 0.00,
      totalNetPayable: (json['total_net_payable'] as num?)?.toDouble() ?? 0.00,
      salarySlips: rawSlips
          .map((s) => SalarySlipModel.fromJson(s as Map<String, dynamic>, monthYear: month))
          .toList(),
    );
  }
}

/// Service managing payroll preview calculations, journal voucher postings, and Form 24Q exports.
class PayrollService {
  final SupabaseClient _client;

  PayrollService({SupabaseClient? client})
      : _client = client ?? SupabaseClientService.client;

  /// Generates dry-run payroll preview with EPF, ESI, PT and TDS deductions
  Future<PayrollPreviewSummary> previewMonthlyPayroll({
    required String monthYear, // 'YYYY-MM'
  }) async {
    return await executeSafely<PayrollPreviewSummary>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'calculate_monthly_payroll',
        params: {
          'p_business_id': businessId,
          'p_month_year': monthYear,
        },
      );

      return PayrollPreviewSummary.fromJson(Map<String, dynamic>.from(response as Map));
    });
  }

  /// Commits monthly payroll batch into a balanced double-entry Journal voucher
  Future<String> executePayrollRun({
    required String monthYear,
    required DateTime paymentDate,
  }) async {
    return await executeSafely<String>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final voucherId = await _client.rpc(
        'post_monthly_payroll_voucher',
        params: {
          'p_business_id': businessId,
          'p_month_year': monthYear,
          'p_payment_date': paymentDate.toIso8601String().split('T').first,
        },
      );

      return voucherId as String;
    });
  }

  /// Exports Form 24Q quarterly e-TDS return payload
  Future<Map<String, dynamic>> exportForm24Q({
    required String financialYear,
    required String quarter, // 'Q1', 'Q2', 'Q3', 'Q4'
  }) async {
    return await executeSafely<Map<String, dynamic>>(() async {
      final user = _client.auth.currentUser;
      final businessId = user?.appMetadata['business_id'] ?? '00000000-0000-0000-0000-000000000000';

      final response = await _client.rpc(
        'generate_form_24q_payload',
        params: {
          'p_business_id': businessId,
          'p_financial_year': financialYear,
          'p_quarter': quarter,
        },
      );

      return Map<String, dynamic>.from(response as Map);
    });
  }
}
