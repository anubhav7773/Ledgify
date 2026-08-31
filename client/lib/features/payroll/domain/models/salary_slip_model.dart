/// Domain model representing an individual employee payslip record.
class SalarySlipModel {
  final String employeeId;
  final String employeeCode;
  final String fullName;
  final String? designation;
  final String? pan;
  final String taxRegime;
  final String monthYear;
  final double basicSalary;
  final double hra;
  final double specialAllowance;
  final double grossSalary;
  final double epfEmployee;
  final double epfEmployer;
  final double esiEmployee;
  final double esiEmployer;
  final double professionalTax;
  final double tdsSalary;
  final double totalDeductions;
  final double netPayable;

  const SalarySlipModel({
    required this.employeeId,
    required this.employeeCode,
    required this.fullName,
    this.designation,
    this.pan,
    required this.taxRegime,
    required this.monthYear,
    required this.basicSalary,
    required this.hra,
    required this.specialAllowance,
    required this.grossSalary,
    required this.epfEmployee,
    required this.epfEmployer,
    required this.esiEmployee,
    required this.esiEmployer,
    required this.professionalTax,
    required this.tdsSalary,
    required this.totalDeductions,
    required this.netPayable,
  });

  factory SalarySlipModel.fromJson(Map<String, dynamic> json, {String monthYear = ''}) {
    return SalarySlipModel(
      employeeId: json['employee_id'] as String? ?? json['id'] as String? ?? '',
      employeeCode: json['employee_code'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      designation: json['designation'] as String?,
      pan: json['pan'] as String?,
      taxRegime: json['tax_regime'] as String? ?? 'NEW',
      monthYear: monthYear.isNotEmpty ? monthYear : (json['month_year'] as String? ?? '2026-08'),
      basicSalary: (json['basic_salary'] as num?)?.toDouble() ?? 0.00,
      hra: (json['hra'] as num?)?.toDouble() ?? 0.00,
      specialAllowance: (json['special_allowance'] as num?)?.toDouble() ?? 0.00,
      grossSalary: (json['gross_salary'] as num?)?.toDouble() ?? 0.00,
      epfEmployee: (json['epf_employee'] as num?)?.toDouble() ?? 0.00,
      epfEmployer: (json['epf_employer'] as num?)?.toDouble() ?? 0.00,
      esiEmployee: (json['esi_employee'] as num?)?.toDouble() ?? 0.00,
      esiEmployer: (json['esi_employer'] as num?)?.toDouble() ?? 0.00,
      professionalTax: (json['professional_tax'] as num?)?.toDouble() ?? 200.00,
      tdsSalary: (json['tds_salary'] as num?)?.toDouble() ?? 0.00,
      totalDeductions: (json['total_deductions'] as num?)?.toDouble() ?? 0.00,
      netPayable: (json['net_payable'] as num?)?.toDouble() ?? 0.00,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'employee_code': employeeCode,
      'full_name': fullName,
      'designation': designation,
      'pan': pan,
      'tax_regime': taxRegime,
      'month_year': monthYear,
      'basic_salary': basicSalary,
      'hra': hra,
      'special_allowance': specialAllowance,
      'gross_salary': grossSalary,
      'epf_employee': epfEmployee,
      'epf_employer': epfEmployer,
      'esi_employee': esiEmployee,
      'esi_employer': esiEmployer,
      'professional_tax': professionalTax,
      'tds_salary': tdsSalary,
      'total_deductions': totalDeductions,
      'net_payable': netPayable,
    };
  }
}
