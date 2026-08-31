import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/safe_executor.dart';
import '../domain/models/search_result_item.dart';

/// Service executing concurrent multi-index searches across Ledgers, Vouchers, Stock Items, and Reports.
class GlobalSearchService {
  final SupabaseClient _client;

  GlobalSearchService({SupabaseClient? client})
      : _client = client ?? SupabaseClientService.client;

  // Static App Navigation Reports Index
  static const List<SearchResultItem> _appReportShortcuts = [
    SearchResultItem(
      id: 'rep_balance_sheet',
      title: 'Balance Sheet',
      subtitle: 'Schedule III Sources & Applications of Funds / तुलन पत्र',
      category: SearchCategory.report,
      route: '/reports/balance-sheet',
    ),
    SearchResultItem(
      id: 'rep_pnl',
      title: 'Profit & Loss Account',
      subtitle: 'Trading & Income Statement (Gross & Net Margins) / लाभ-हानि खाता',
      category: SearchCategory.report,
      route: '/reports/profit-and-loss',
    ),
    SearchResultItem(
      id: 'rep_trial_balance',
      title: 'Trial Balance',
      subtitle: '4-Column Ledger Closing Balances & Zero-Sum Verification / तलपट',
      category: SearchCategory.report,
      route: '/reports/trial-balance',
    ),
    SearchResultItem(
      id: 'rep_day_book',
      title: 'Day Book',
      subtitle: 'Daily Chronological Transaction Register / दैनिक बही',
      category: SearchCategory.report,
      route: '/reports/day-book',
    ),
    SearchResultItem(
      id: 'rep_sales_register',
      title: 'Sales Register',
      subtitle: 'Statutory GST Outward Sales Register / बिक्री रजिस्टर',
      category: SearchCategory.report,
      route: '/reports/sales-register',
    ),
    SearchResultItem(
      id: 'rep_purchase_register',
      title: 'Purchase Register',
      subtitle: 'Statutory Inward Purchases Register / खरीद रजिस्टर',
      category: SearchCategory.report,
      route: '/reports/purchase-register',
    ),
    SearchResultItem(
      id: 'rep_stock_summary',
      title: 'Stock Summary',
      subtitle: 'Inventory Valuation & Closing Stock Qty / स्टॉक सारांश',
      category: SearchCategory.report,
      route: '/reports/stock-summary',
    ),
    SearchResultItem(
      id: 'comp_gstr1',
      title: 'GSTR-1 Return Filing',
      subtitle: 'Tables 4A/5A/7/12 Outward Taxable Supplies / जीएसटीआर-1',
      category: SearchCategory.report,
      route: '/compliance/gstr1',
    ),
    SearchResultItem(
      id: 'comp_ims',
      title: 'IMS Inward Invoices (GSTR-2B)',
      subtitle: 'Invoice Management System (Accept/Reject/Pending) / आईएमएस',
      category: SearchCategory.report,
      route: '/compliance/ims',
    ),
    SearchResultItem(
      id: 'comp_brs',
      title: 'Bank Reconciliation (BRS)',
      subtitle: 'Automated Trigram Statement Match & Bank Accounts / बैंक समाधान',
      category: SearchCategory.report,
      route: '/banking/brs',
    ),
    SearchResultItem(
      id: 'comp_tds',
      title: 'Direct Tax (TDS / TCS)',
      subtitle: 'Section 194Q & 206C Register and Form 26Q Export / टीडीएस',
      category: SearchCategory.report,
      route: '/direct-tax/register',
    ),
    SearchResultItem(
      id: 'comp_payroll',
      title: 'Payroll & Salary Slips',
      subtitle: 'EPF/ESI Slabs & Monthly Salary Journal / पेरोल एवं वेतन',
      category: SearchCategory.report,
      route: '/payroll/directory',
    ),
  ];

  /// Performs concurrent multi-index search
  Future<List<SearchResultItem>> search(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];

    return await executeSafely<List<SearchResultItem>>(() async {
      final List<SearchResultItem> results = [];

      // 1. Match Navigation and Reports (In-memory)
      for (final item in _appReportShortcuts) {
        if (item.title.toLowerCase().contains(clean) ||
            item.subtitle.toLowerCase().contains(clean)) {
          results.add(item);
        }
      }

      // 2. Query Accounts / Ledgers concurrently
      try {
        final accountsRes = await _client
            .from('accounts')
            .select('id, name, group_name, gstin')
            .ilike('name', '%$clean%')
            .limit(10);

        for (final acc in accountsRes as List<dynamic>) {
          results.add(
            SearchResultItem(
              id: acc['id'] as String,
              title: acc['name'] as String,
              subtitle: '${acc['group_name']} • GSTIN: ${acc['gstin'] ?? "Unregistered"}',
              category: SearchCategory.ledger,
              arguments: acc['id'],
            ),
          );
        }
      } catch (_) {}

      // 3. Query Stock Items
      try {
        final itemsRes = await _client
            .from('stock_items')
            .select('id, name, hsn_or_sac_code, current_stock_quantity')
            .ilike('name', '%$clean%')
            .limit(10);

        for (final itm in itemsRes as List<dynamic>) {
          results.add(
            SearchResultItem(
              id: itm['id'] as String,
              title: itm['name'] as String,
              subtitle: 'HSN: ${itm['hsn_or_sac_code'] ?? "N/A"} • Stock: ${(itm['current_stock_quantity'] as num?)?.toStringAsFixed(1) ?? "0"}',
              category: SearchCategory.stockItem,
              arguments: itm['id'],
            ),
          );
        }
      } catch (_) {}

      // 4. Query Vouchers
      try {
        final vouchersRes = await _client
            .from('vouchers')
            .select('id, voucher_number, voucher_date, narration, voucher_types(name)')
            .or('voucher_number.ilike.%$clean%,narration.ilike.%$clean%')
            .limit(8);

        for (final v in vouchersRes as List<dynamic>) {
          final vType = v['voucher_types'] != null ? v['voucher_types']['name'] as String? : 'Voucher';
          results.add(
            SearchResultItem(
              id: v['id'] as String,
              title: '$vType #${v['voucher_number']}',
              subtitle: '${v['voucher_date']} • ${v['narration'] ?? "No narration"}',
              category: SearchCategory.voucher,
              arguments: v['id'],
            ),
          );
        }
      } catch (_) {}

      return results;
    });
  }
}
