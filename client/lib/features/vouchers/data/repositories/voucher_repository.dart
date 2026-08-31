import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/safe_executor.dart';
import 'package:ledgify/features/masters/domain/models/voucher_type_model.dart';
import '../../domain/models/voucher_line_item_model.dart';
import '../../domain/models/voucher_model.dart';

/// Repository managing Double-Entry Voucher operations via FastAPI backend.
class VoucherRepository {
  VoucherRepository();

  /// Fetches default voucher types supported by Tally/Ledgify
  Future<List<VoucherTypeModel>> fetchVoucherTypes() async {
    return const [
      VoucherTypeModel(id: 'vt-payment', businessId: 'BIZ-DEFAULT-01', name: 'Payment', category: 'Payment', isSystemDefault: true),
      VoucherTypeModel(id: 'vt-receipt', businessId: 'BIZ-DEFAULT-01', name: 'Receipt', category: 'Receipt', isSystemDefault: true),
      VoucherTypeModel(id: 'vt-sales', businessId: 'BIZ-DEFAULT-01', name: 'Sales', category: 'Sales', isSystemDefault: true),
      VoucherTypeModel(id: 'vt-purchase', businessId: 'BIZ-DEFAULT-01', name: 'Purchase', category: 'Purchase', isSystemDefault: true),
      VoucherTypeModel(id: 'vt-contra', businessId: 'BIZ-DEFAULT-01', name: 'Contra', category: 'Contra', isSystemDefault: true),
      VoucherTypeModel(id: 'vt-journal', businessId: 'BIZ-DEFAULT-01', name: 'Journal', category: 'Journal', isSystemDefault: true),
    ];
  }

  /// Creates a double-entry balanced voucher via FastAPI backend
  Future<Map<String, dynamic>> createVoucher(VoucherModel voucher) async {
    return await executeSafely<Map<String, dynamic>>(() async {
      if (!voucher.isBalanced) {
        throw AccountingInvariantFailure(
          message: 'Voucher is not balanced! Total Debits (₹${voucher.totalDebitAmount.toStringAsFixed(2)}) '
              'must equal Total Credits (₹${voucher.totalCreditAmount.toStringAsFixed(2)}). '
              'Difference: ₹${voucher.differenceAmount.toStringAsFixed(2)}',
        );
      }

      final itemsPayload = voucher.lineItems.map((i) {
        return {
          'ledger_id': i.accountId,
          'ledger_name': 'Ledger ${i.accountId}',
          'is_debit': i.entryType == 'Dr',
          'amount': i.amount,
          'particulars': i.itemDescription,
        };
      }).toList();

      final payload = {
        'voucher_type': _mapCategory(voucher.voucherTypeName),
        'voucher_number': voucher.voucherNumber,
        'voucher_date': voucher.voucherDate.toIso8601String().split('T')[0],
        'narration': voucher.narration,
        'items': itemsPayload,
      };

      final response = await ApiClient.post('/vouchers', body: payload);
      return Map<String, dynamic>.from(response as Map);
    });
  }

  static String _mapCategory(String? type) {
    if (type == null) return 'Payment';
    final name = type.toLowerCase();
    if (name.contains('sales') || name.contains('sale')) return 'Sales';
    if (name.contains('purchase')) return 'Purchase';
    if (name.contains('receipt')) return 'Receipt';
    if (name.contains('contra')) return 'Contra';
    if (name.contains('journal')) return 'Journal';
    return 'Payment';
  }

  /// Fetches vouchers from FastAPI backend
  Future<List<VoucherModel>> fetchVouchers({
    DateTime? startDate,
    DateTime? endDate,
    String? voucherTypeId,
    int limit = 50,
    int offset = 0,
  }) async {
    return await executeSafely<List<VoucherModel>>(() async {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }

      final response = await ApiClient.get('/vouchers', queryParams: queryParams);
      final list = response as List<dynamic>;

      return list.map((json) {
        final data = json as Map<String, dynamic>;
        final itemsList = (data['items'] as List<dynamic>?) ?? [];

        final items = itemsList.map((itemJson) {
          final item = itemJson as Map<String, dynamic>;
          return VoucherLineItemModel(
            id: item['id'] ?? '',
            businessId: data['business_id'] ?? 'BIZ-DEFAULT-01',
            voucherId: data['id'] ?? '',
            accountId: item['ledger_id'] ?? '',
            entryType: (item['is_debit'] == true) ? 'Dr' : 'Cr',
            amount: (item['amount'] as num?)?.toDouble() ?? 0.0,
            itemDescription: item['particulars'],
          );
        }).toList();

        return VoucherModel(
          id: data['id'] ?? '',
          businessId: data['business_id'] ?? 'BIZ-DEFAULT-01',
          voucherTypeId: 'vt-${data['voucher_type'] ?? 'Payment'}',
          voucherTypeName: data['voucher_type'] ?? 'Payment',
          voucherNumber: data['voucher_number'] ?? 'VCH-001',
          voucherDate: DateTime.tryParse(data['voucher_date'] ?? '') ?? DateTime.now(),
          narration: data['narration'],
          lineItems: items,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();
    });
  }

  /// Fetches single voucher by ID
  Future<VoucherModel> fetchVoucherById(String voucherId) async {
    return await executeSafely<VoucherModel>(() async {
      final response = await ApiClient.get('/vouchers/$voucherId');
      final data = response as Map<String, dynamic>;
      final itemsList = (data['items'] as List<dynamic>?) ?? [];

      final items = itemsList.map((itemJson) {
        final item = itemJson as Map<String, dynamic>;
        return VoucherLineItemModel(
          id: item['id'] ?? '',
          businessId: data['business_id'] ?? 'BIZ-DEFAULT-01',
          voucherId: data['id'] ?? '',
          accountId: item['ledger_id'] ?? '',
          entryType: (item['is_debit'] == true) ? 'Dr' : 'Cr',
          amount: (item['amount'] as num?)?.toDouble() ?? 0.0,
          itemDescription: item['particulars'],
        );
      }).toList();

      return VoucherModel(
        id: data['id'] ?? '',
        businessId: data['business_id'] ?? 'BIZ-DEFAULT-01',
        voucherTypeId: 'vt-${data['voucher_type'] ?? 'Payment'}',
        voucherTypeName: data['voucher_type'] ?? 'Payment',
        voucherNumber: data['voucher_number'] ?? 'VCH-001',
        voucherDate: DateTime.tryParse(data['voucher_date'] ?? '') ?? DateTime.now(),
        narration: data['narration'],
        lineItems: items,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });
  }
}
