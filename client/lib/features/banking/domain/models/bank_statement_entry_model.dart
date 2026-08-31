/// Domain model representing a single bank statement line item for Bank Reconciliation (BRS).
/// Adheres strictly to docs/08_banking_brs_payroll_direct_tax.md.
class BankStatementEntryModel {
  final String id;
  final String businessId;
  final String bankAccountId;
  final DateTime transactionDate;
  final String description;
  final String? chequeReferenceNo;
  final double withdrawalAmount;
  final double depositAmount;
  final double balance;
  final String? matchedVoucherId;
  final double? trgmSimilarityScore;
  final bool isReconciled;
  final DateTime? createdAt;

  const BankStatementEntryModel({
    required this.id,
    required this.businessId,
    required this.bankAccountId,
    required this.transactionDate,
    required this.description,
    this.chequeReferenceNo,
    this.withdrawalAmount = 0.00,
    this.depositAmount = 0.00,
    required this.balance,
    this.matchedVoucherId,
    this.trgmSimilarityScore,
    this.isReconciled = false,
    this.createdAt,
  });

  factory BankStatementEntryModel.fromJson(Map<String, dynamic> json) {
    return BankStatementEntryModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      bankAccountId: json['bank_account_id'] as String,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      description: json['description'] as String,
      chequeReferenceNo: json['cheque_reference_no'] as String?,
      withdrawalAmount: (json['withdrawal_amount'] as num?)?.toDouble() ?? 0.00,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0.00,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.00,
      matchedVoucherId: json['matched_voucher_id'] as String?,
      trgmSimilarityScore: (json['trgm_similarity_score'] as num?)?.toDouble(),
      isReconciled: json['is_reconciled'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'business_id': businessId,
      'bank_account_id': bankAccountId,
      'transaction_date': transactionDate.toIso8601String().split('T').first,
      'description': description,
      'cheque_reference_no': chequeReferenceNo,
      'withdrawal_amount': withdrawalAmount,
      'deposit_amount': depositAmount,
      'balance': balance,
      'matched_voucher_id': matchedVoucherId,
      'trgm_similarity_score': trgmSimilarityScore,
      'is_reconciled': isReconciled,
    };
  }

  bool get isWithdrawal => withdrawalAmount > 0;
  bool get isDeposit => depositAmount > 0;
  double get amount => isWithdrawal ? withdrawalAmount : depositAmount;

  int? get similarityPercentage =>
      trgmSimilarityScore != null ? (trgmSimilarityScore! * 100).round().clamp(0, 100) : null;

  String get reconciliationStatusText {
    if (isReconciled) return 'Reconciled / मिलान पूर्ण';
    if (trgmSimilarityScore != null && trgmSimilarityScore! >= 0.60) {
      return 'Suggested ($similarityPercentage%)';
    }
    return 'Un-reconciled / असंतुलित';
  }
}
