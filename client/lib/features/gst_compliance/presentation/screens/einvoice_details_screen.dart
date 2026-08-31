import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../../../vouchers/domain/models/voucher_model.dart';
import '../domain/models/einvoice_log_model.dart';

/// Screen displaying the official E-Invoice with 64-char IRN, 2D QR Code, and statutory tax breakdown.
/// Adheres strictly to docs/05_gst_einvoice_and_ewaybill_spec.md and docs/10_ui_ux_design_system_tokens.md.
class EInvoiceDetailsScreen extends StatelessWidget {
  final VoucherModel voucher;
  final EInvoiceLogModel einvoiceLog;

  const EInvoiceDetailsScreen({
    super.key,
    required this.voucher,
    required this.einvoiceLog,
  });

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard! / क्लिपबोर्ड पर कॉपी किया गया'),
        backgroundColor: LedgifyColors.primaryBlue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareInvoice() {
    final text = 'E-Invoice: ${voucher.voucherNumber}\n'
        'IRN: ${einvoiceLog.irn}\n'
        'Ack No: ${einvoiceLog.ackNo}\n'
        'Total Amount: ₹${voucher.totalCreditAmount > 0 ? voucher.totalCreditAmount.toStringAsFixed(2) : voucher.totalDebitAmount.toStringAsFixed(2)}';
    Share.share(text, subject: 'Tax Invoice ${voucher.voucherNumber}');
  }

  @override
  Widget build(BuildContext context) {
    final docDtls = einvoiceLog.payloadJson['DocDtls'] as Map<String, dynamic>? ?? {};
    final valDtls = einvoiceLog.payloadJson['ValDtls'] as Map<String, dynamic>? ?? {};
    final sellerDtls = einvoiceLog.payloadJson['SellerDtls'] as Map<String, dynamic>? ?? {};
    final buyerDtls = einvoiceLog.payloadJson['BuyerDtls'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Invoice / ई-चालान (INV-01)', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: _shareInvoice,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LedgifyColors.standardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Success Banner with QR Code
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LedgifyColors.cardBorderRadius),
                  side: const BorderSide(color: LedgifyColors.debitGreen, width: 1.2),
                ),
                color: LedgifyColors.debitGreenBg,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified, color: LedgifyColors.debitGreen, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'IRP Registered & Signed / ई-चालान प्रमाणित',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: LedgifyColors.debitGreen,
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: einvoiceLog.signedQrCode.isNotEmpty
                              ? einvoiceLog.signedQrCode
                              : einvoiceLog.irn,
                          version: QrVersions.auto,
                          size: 180.0,
                          gapless: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Scan with NIC / GST e-Invoice app to verify signature',
                        style: TextStyle(fontSize: 11, color: LedgifyColors.secondarySlate),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. IRN & Acknowledgement Details Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LedgifyColors.cardBorderRadius),
                  side: const BorderSide(color: LedgifyColors.surfaceVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('IRN & Verification / आईआरएन विवरण', style: LedgifyTypography.cardHeader),
                      const Divider(height: 20),

                      // IRN with 1-Tap Copy
                      InkWell(
                        onTap: () => _copyToClipboard(context, einvoiceLog.irn, 'IRN Hash'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: LedgifyColors.surfaceVariant.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Invoice Reference Number (IRN)',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LedgifyColors.secondarySlate),
                                  ),
                                  Icon(Icons.copy, size: 16, color: LedgifyColors.primaryBlue),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                einvoiceLog.irn,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildInfoRow('Ack No. / पावती संख्या', einvoiceLog.ackNo),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Ack Date / पावती दिनांक',
                        '${einvoiceLog.ackDate.day.toString().padLeft(2, '0')}/${einvoiceLog.ackDate.month.toString().padLeft(2, '0')}/${einvoiceLog.ackDate.year} ${einvoiceLog.ackDate.hour}:${einvoiceLog.ackDate.minute.toString().padLeft(2, '0')}',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow('Document No. / चालान संख्या', docDtls['No']?.toString() ?? voucher.voucherNumber),
                      const SizedBox(height: 8),
                      _buildInfoRow('Document Date / चालान दिनांक', docDtls['Dt']?.toString() ?? ''),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Parties & Tax Valuation Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LedgifyColors.cardBorderRadius),
                  side: const BorderSide(color: LedgifyColors.surfaceVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Parties & Valuation / पक्ष एवं कर मूल्य', style: LedgifyTypography.cardHeader),
                      const Divider(height: 20),
                      _buildInfoRow('Seller GSTIN / विक्रेता', sellerDtls['Gstin']?.toString() ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildInfoRow('Buyer / क्रेता', '${buyerDtls['LglNm'] ?? 'N/A'} (${buyerDtls['Gstin'] ?? 'URP'})'),
                      const SizedBox(height: 8),
                      _buildInfoRow('Place of Supply (POS)', buyerDtls['Pos']?.toString() ?? 'N/A'),
                      const Divider(height: 20),
                      _buildInfoRow('Taxable Value / कर योग्य मूल्य', '₹${valDtls['AssVal'] ?? '0.00'}'),
                      const SizedBox(height: 8),
                      if ((valDtls['CgstVal'] as num?)?.toDouble() != 0) ...[
                        _buildInfoRow('CGST / केंद्रीय कर', '₹${valDtls['CgstVal']}'),
                        const SizedBox(height: 8),
                        _buildInfoRow('SGST / राज्य कर', '₹${valDtls['SgstVal']}'),
                        const SizedBox(height: 8),
                      ],
                      if ((valDtls['IgstVal'] as num?)?.toDouble() != 0) ...[
                        _buildInfoRow('IGST / एकीकृत कर', '₹${valDtls['IgstVal']}'),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Invoice Value', style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            '₹${valDtls['TotInvVal'] ?? '0.00'}',
                            style: LedgifyTypography.financialAmount.copyWith(
                              color: LedgifyColors.debitGreen,
                              fontSize: 16,
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
                height: LedgifyColors.minTouchTargetSize,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LedgifyColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text(
                    'Print Tax Invoice (FORM GST INV-01) / चालान प्रिंट करें',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Preparing PDF preview of FORM GST INV-01...'),
                        backgroundColor: LedgifyColors.primaryBlue,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: LedgifyColors.minTouchTargetSize,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LedgifyColors.debitGreen,
                    side: const BorderSide(color: LedgifyColors.debitGreen, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text(
                    'Share via WhatsApp / व्हाट्सएप पर भेजें',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
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
        Text(label, style: const TextStyle(fontSize: 13, color: LedgifyColors.secondarySlate)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
