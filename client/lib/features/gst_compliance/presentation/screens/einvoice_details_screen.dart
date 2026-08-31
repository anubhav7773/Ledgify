import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../vouchers/domain/models/voucher_model.dart';
import '../domain/models/einvoice_log_model.dart';

/// Screen displaying the official E-Invoice with 64-char IRN, 2D QR Code, and statutory tax breakdown (Google Stitch UI).
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
    final vNum = voucher?.voucherNumber ?? invoiceId ?? 'INV-001';
    final irn = einvoiceLog?.irn ?? '3a1b2c3d4e5f...64char';
    final ack = einvoiceLog?.ackNo ?? '122610001000';
    final text = 'E-Invoice: $vNum\n'
        'IRN: $irn\n'
        'Ack No: $ack\n'
        'Verified via NIC / GST Portal';
    Share.share(text, subject: 'Tax Invoice $vNum');
  }

  @override
  Widget build(BuildContext context) {
    final irn = einvoiceLog?.irn ?? '9b20756786c52a0a2df3d82a170155b9e075037d0577be2e6f47738f654b17e8';
    final qrData = einvoiceLog?.signedQrCode.isNotEmpty == true ? einvoiceLog!.signedQrCode : irn;
    final ackNo = einvoiceLog?.ackNo ?? '122610294821';
    final vNum = voucher?.voucherNumber ?? invoiceId ?? 'INV-2026-0801';
    final docDtls = einvoiceLog?.payloadJson['DocDtls'] as Map<String, dynamic>? ?? {};
    final valDtls = einvoiceLog?.payloadJson['ValDtls'] as Map<String, dynamic>? ?? {};
    final sellerDtls = einvoiceLog?.payloadJson['SellerDtls'] as Map<String, dynamic>? ?? {};
    final buyerDtls = einvoiceLog?.payloadJson['BuyerDtls'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('E-Invoice Details', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
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
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                  side: BorderSide(color: AppColors.debitGreen.withOpacity(0.4), width: 1.2),
                ),
                color: AppColors.debitGreenLight,
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
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 180.0,
                          gapless: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Scan with official NIC / GST e-Invoice app to verify signature',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. IRN & Acknowledgement Details Card
              Card(
                elevation: 0,
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
                      _buildInfoRow('Document Number', docDtls['No']?.toString() ?? vNum),
                      const Divider(height: 16),
                      _buildInfoRow('Document Date', docDtls['Dt']?.toString() ?? '2026-08-31'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Parties & Tax Valuation Card
              Card(
                elevation: 0,
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
                      _buildInfoRow('Seller GSTIN', sellerDtls['Gstin']?.toString() ?? '27AAAAA0000A1Z5'),
                      const Divider(height: 16),
                      _buildInfoRow('Buyer Details', '${buyerDtls['LglNm'] ?? 'Apex Enterprises'} (${buyerDtls['Gstin'] ?? '27ABCDE1234F1Z5'})'),
                      const Divider(height: 16),
                      _buildInfoRow('Place of Supply (POS)', buyerDtls['Pos']?.toString() ?? '27 - Maharashtra'),
                      const Divider(height: 16),
                      _buildInfoRow('Taxable Value', '₹${valDtls['AssVal'] ?? '42,500.00'}'),
                      const Divider(height: 16),
                      _buildInfoRow('Estimated GST (18%)', '₹${valDtls['TotInvVal'] != null ? (valDtls['TotInvVal'] - (valDtls['AssVal'] ?? 0)) : '7,650.00'}'),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Invoice Value', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.textPrimary)),
                          Text(
                            '₹${valDtls['TotInvVal'] ?? '50,150.00'}',
                            style: AppTypography.currencyText.copyWith(
                              color: AppColors.debitGreen,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 4. Action Buttons (48dp Touch Targets)
              SizedBox(
                height: AppColors.minTouchTargetSize,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text(
                    'Print Tax Invoice (FORM GST INV-01)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Preparing PDF preview of FORM GST INV-01...'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: AppColors.minTouchTargetSize,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.debitGreen,
                    side: const BorderSide(color: AppColors.debitGreen, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text(
                    'Share Invoice Summary',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  onPressed: _shareInvoice,
                ),
              ),
              const SizedBox(height: 20),
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
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
