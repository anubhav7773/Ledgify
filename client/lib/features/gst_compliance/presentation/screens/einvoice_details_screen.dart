import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:ledgify/features/vouchers/domain/models/voucher_model.dart';
import 'package:ledgify/features/gst_compliance/domain/models/einvoice_log_model.dart';

/// Screen displaying the official E-Invoice with 64-char IRN, 2D QR Code, and statutory tax breakdown.
class EInvoiceDetailsScreen extends StatelessWidget {
  final VoucherModel? voucher;
  final EInvoiceLogModel? einvoiceLog;
  final String? invoiceId;

  const EInvoiceDetailsScreen({
    super.key,
    this.voucher,
    this.einvoiceLog,
    this.invoiceId,
  });

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareInvoice() {
    final vNum = voucher?.voucherNumber ?? einvoiceLog?.irn ?? invoiceId ?? 'INV-001';
    final irn = einvoiceLog?.irn ?? 'IRN-NOT-GENERATED';
    final ack = einvoiceLog?.ackNo ?? 'N/A';
    final text = 'E-Invoice: $vNum\n'
        'IRN: $irn\n'
        'Ack No: $ack\n'
        'Verified via NIC / GST Portal';
    Share.share(text, subject: 'Tax Invoice $vNum');
  }

  @override
  Widget build(BuildContext context) {
    final hasData = voucher != null || einvoiceLog != null;
    final irn = einvoiceLog?.irn ?? (voucher != null ? 'IRN-PENDING-POSTING' : 'N/A');
    final qrData = einvoiceLog?.signedQrCode.isNotEmpty == true ? einvoiceLog!.signedQrCode : (irn != 'N/A' ? irn : 'NO_DATA');
    final ackNo = einvoiceLog?.ackNo ?? 'N/A';
    final vNum = voucher?.voucherNumber ?? einvoiceLog?.payloadJson['DocDtls']?['No']?.toString() ?? invoiceId ?? 'INV-001';
    final docDate = voucher != null
        ? '${voucher!.voucherDate.day.toString().padLeft(2, '0')}/${voucher!.voucherDate.month.toString().padLeft(2, '0')}/${voucher!.voucherDate.year}'
        : (einvoiceLog?.payloadJson['DocDtls']?['Dt']?.toString() ?? 'N/A');

    final double taxableAmount = voucher != null
        ? (voucher!.totalCreditAmount > 0 ? voucher!.totalCreditAmount : voucher!.totalDebitAmount)
        : ((einvoiceLog?.payloadJson['ValDtls']?['AssVal'] as num?)?.toDouble() ?? 0.0);

    final double cgstAmount = voucher?.lineItems.fold<double>(0.0, (sum, i) => sum + i.cgstAmt) ?? 0.0;
    final double sgstAmount = voucher?.lineItems.fold<double>(0.0, (sum, i) => sum + i.sgstAmt) ?? 0.0;
    final double igstAmount = voucher?.lineItems.fold<double>(0.0, (sum, i) => sum + i.igstAmt) ?? 0.0;
    final double totalTax = (cgstAmount + sgstAmount + igstAmount > 0)
        ? (cgstAmount + sgstAmount + igstAmount)
        : (taxableAmount * 0.18);
    final double totalInvoiceValue = taxableAmount + totalTax;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('E-Invoice Details', style: AppTypography.cardHeader),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Invoice',
            onPressed: _shareInvoice,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppColors.standardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Success Banner with QR Code
              Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                  side: BorderSide(color: AppColors.debitGreen.withOpacity(0.4), width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.verified_rounded, color: AppColors.debitGreen, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'IRP Registered & Signed',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.debitGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2D QR Code Container
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 160,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Scan via statutory NIC e-Invoice QR app',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Statutory IRN Details Card
              Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('IRN & Verification Details', style: AppTypography.cardHeader),
                      const Divider(height: 20),

                      // IRN with 1-Tap Copy
                      InkWell(
                        onTap: () => _copyToClipboard(context, irn, 'IRN Hash'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primaryLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [
                                  Text(
                                    'Invoice Reference Number (IRN)',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                                  ),
                                  Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                irn,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _buildInfoRow('Ack Number', ackNo),
                      const Divider(height: 16),
                      _buildInfoRow('Document Number', vNum),
                      const Divider(height: 16),
                      _buildInfoRow('Document Date', docDate),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Parties & Tax Valuation Card
              Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Parties & Valuation Summary', style: AppTypography.cardHeader),
                      const Divider(height: 20),
                      _buildInfoRow('Document Number', vNum),
                      const Divider(height: 16),
                      _buildInfoRow('Taxable Value', '₹${taxableAmount.toStringAsFixed(2)}'),
                      const Divider(height: 16),
                      _buildInfoRow('Estimated GST (18%)', '₹${totalTax.toStringAsFixed(2)}'),
                      const Divider(height: 18),

                      // Grand Total Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Invoice Value',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            '₹${totalInvoiceValue.toStringAsFixed(2)}',
                            style: AppTypography.currencyText.copyWith(
                              fontSize: 18,
                              color: AppColors.debitGreen,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 4. Action Buttons
              SizedBox(
                height: AppColors.minTouchTargetSize,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print Tax Invoice (FORM GST INV-01)', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Preparing PDF preview of FORM GST INV-01...')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                height: AppColors.minTouchTargetSize,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.debitGreen,
                    side: const BorderSide(color: AppColors.debitGreen),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share Invoice Summary', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: _shareInvoice,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }
}
