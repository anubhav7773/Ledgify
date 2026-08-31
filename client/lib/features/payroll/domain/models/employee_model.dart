/// Domain model representing an employee profile in Ledgify Payroll.
/// Adheres strictly to docs/08_banking_brs_payroll_direct_tax.md.
class EmployeeModel {
  final String id;
  final String businessId;
  final String employeeCode;
  final String fullName;
  final String? designation;
  final String? department;
  final String salaryLedgerId;
  final String taxRegime; // 'NEW' or 'OLD'
  final String? pan;
  final String? aadhaar;
  final String? bankAccountNumber;
  final String? ifscCode;
  final String? pfUan;
  final String? esicNumber;
  final double basicSalary;
  final double hra;
  final double specialAllowance;
  final bool pfApplicable;
  final bool esiApplicable;
  final double professionalTax;
  final double monthlyTds;
  final bool isActive;
  final DateTime? joiningDate;
  final DateTime? createdAt;

  const EmployeeModel({
    required this.id,
    required this.businessId,
    required this.employeeCode,
    required this.fullName,
    this.designation,
    this.department,
    required this.salaryLedgerId,
    this.taxRegime = 'NEW',
    this.pan,
    this.aadhaar,
    this.bankAccountNumber,
    this.ifscCode,
    this.pfUan,
    this.esicNumber,
    required this.basicSalary,
    this.hra = 0.00,
    this.specialAllowance = 0.00,
    this.pfApplicable = true,
    this.esiApplicable = false,
    this.professionalTax = 200.00,
    this.monthlyTds = 0.00,
    this.isActive = true,
    this.joiningDate,
    this.createdAt,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      employeeCode: json['employee_code'] as String,
      fullName: json['full_name'] as String,
      designation: json['designation'] as String?,
      department: json['department'] as String?,
      salaryLedgerId: json['salary_ledger_id'] as String,
      taxRegime: json['tax_regime'] as String? ?? 'NEW',
      pan: json['pan'] as String?,
      aadhaar: json['aadhaar'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
      ifscCode: json['ifsc_code'] as String?,
      pfUan: json['pf_uan'] as String?,
      esicNumber: json['esic_number'] as String?,
      basicSalary: (json['basic_salary'] as num?)?.toDouble() ?? 0.00,
      hra: (json['hra'] as num?)?.toDouble() ?? 0.00,
      specialAllowance: (json['special_allowance'] as num?)?.toDouble() ?? 0.00,
      pfApplicable: json['pf_applicable'] as bool? ?? true,
      esiApplicable: json['esi_applicable'] as bool? ?? false,
      professionalTax: (json['professional_tax'] as num?)?.toDouble() ?? 200.00,
      monthlyTds: (json['monthly_tds'] as num?)?.toDouble() ?? 0.00,
      isActive: json['is_active'] as bool? ?? true,
      joiningDate: json['joining_date'] != null ? DateTime.parse(json['joining_date'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'business_id': businessId,
      'employee_code': employeeCode,
      'full_name': fullName,
      'designation': designation,
      'department': department,
      'salary_ledger_id': salaryLedgerId,
      'tax_regime': taxRegime,
      'pan': pan,
      'aadhaar': aadhaar,
      'bank_account_number': bankAccountNumber,
      'ifsc_code': ifscCode,
      'pf_uan': pfUan,
      'esic_number': esicNumber,
      'basic_salary': basicSalary,
      'hra': hra,
      'special_allowance': specialAllowance,
      'pf_applicable': pfApplicable,
      'esi_applicable': esiApplicable,
      'professional_tax': professionalTax,
      'monthly_tds': monthlyTds,
      'is_active': isActive,
      if (joiningDate != null) 'joining_date': joiningDate!.toIso8601String().split('T').first,
    };
  }

  double get grossSalary => basicSalary + hra + specialAllowance;
}
