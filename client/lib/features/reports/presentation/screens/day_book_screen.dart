import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../../../vouchers/presentation/screens/voucher_entry_screen.dart';
import 'package:ledgify/features/reports/domain/models/day_book_model.dart';
import 'package:ledgify/features/reports/domain/services/statutory_registers_service.dart';

/// Screen presenting the Day Book daily transaction register with day stepping and drill-down capabilities.
class DayBookScreen extends StatefulWidget {
  final StatutoryRegistersService? service;

  const DayBookScreen({super.key, this.service});

  @override
  State<DayBookScreen> createState() => _DayBookScreenState();
}

class _DayBookScreenState extends State<DayBookScreen> {
  late final StatutoryRegistersService _service;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  DayBookReportModel? _report;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? StatutoryRegistersService();
    _loadDayBook();
  }

  Future<void> _loadDayBook() async {
    setState(() => _isLoading = true);
    try {
      final report = await _service.fetchDayBook(date: _selectedDate);
      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _stepDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadDayBook();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Day Book / दैनिक बही (डे बुक)', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDayBook,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Date Stepper Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: LedgifyColors.surfaceCard,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _stepDate(-1),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _loadDayBook();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _stepDate(1),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue)))
            else if (_report == null || _report!.totalVouchers == 0)
              const Expanded(
                child: Center(
                  child: Text('No vouchers posted on this date.\nइस तारीख पर कोई वाउचर दर्ज नहीं है', textAlign: TextAlign.center, style: LedgifyTypography.bilingualLabel),
                ),
              )
            else ...[
              // Summary Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: LedgifyColors.primaryContainer.withOpacity(0.4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Transactions: ${_report!.totalVouchers}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      'Turnover: ₹${_report!.totalTurnover.toStringAsFixed(2)}',
                      style: LedgifyTypography.financialAmount.copyWith(fontSize: 15, color: LedgifyColors.primaryBlue),
                    ),
                  ],
                ),
              ),

              // Vouchers List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _report!.vouchers.length,
                  itemBuilder: (context, index) {
                    final voucher = _report!.vouchers[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: LedgifyColors.surfaceVariant),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VoucherEntryScreen(existingVoucherId: voucher.voucherId),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: LedgifyColors.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      voucher.voucherTypeName.toUpperCase(),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: LedgifyColors.primaryBlue),
                                    ),
                                  ),
                                  Text(
                                    '₹${voucher.totalAmount.toStringAsFixed(2)}',
                                    style: LedgifyTypography.financialAmount.copyWith(fontSize: 16, color: LedgifyColors.debitGreen),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              Text('Voucher No: ${voucher.voucherNumber}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              if (voucher.narration != null && voucher.narration!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(voucher.narration!, style: const TextStyle(fontSize: 11.5, color: LedgifyColors.secondarySlate)),
                              ],
                              const Divider(height: 16),

                              // Line Items Brief
                              ...voucher.lineItems.map((li) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${li.entryType}  ${li.accountName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                      Text('₹${li.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
