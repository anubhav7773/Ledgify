/// Domain model representing a company Bank Account in Ledgify.
/// Adheres strictly to docs/02_database_schema_ddl_and_indexes.md and docs/08_banking_brs_payroll_direct_tax.md.
class BankAccountModel {
  final String id;
  final String businessId;
  final String ledgerId;
  final String? ledgerName;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String? branchName;
  final bool isConnected;
  final String? integrationProvider;
  final double currentBalance;
  final int unreconciledCount;

  const BankAccountModel({
    required this.id,
    required this.businessId,
    required this.ledgerId,
    this.ledgerName,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    this.branchName,
    this.isConnected = false,
    this.integrationProvider,
    this.currentBalance = 0.00,
    this.unreconciledCount = 0,
  });

  factory BankAccountModel.fromJson(Map<String, dynamic> json) {
    return BankAccountModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      ledgerId: json['ledger_id'] as String,
      ledgerName: json['accounts'] != null ? json['accounts']['name'] as String? : null,
      bankName: json['bank_name'] as String,
      accountNumber: json['account_number'] as String,
      ifscCode: json['ifsc_code'] as String,
      branchName: json['branch_name'] as String?,
      isConnected: json['is_connected'] as bool? ?? false,
      integrationProvider: json['integration_provider'] as String?,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0.00,
      unreconciledCount: (json['unreconciled_count'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'business_id': businessId,
      'ledger_id': ledgerId,
      'bank_name': bankName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'branch_name': branchName,
      'is_connected': isConnected,
      'integration_provider': integrationProvider,
    };
  }

  String get maskedAccountNumber {
    if (accountNumber.length <= 4) return accountNumber;
    return '•••• •••• ${accountNumber.substring(accountNumber.length - 4)}';
  }
}
