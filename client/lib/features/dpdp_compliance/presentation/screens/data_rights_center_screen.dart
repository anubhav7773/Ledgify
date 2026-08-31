import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/services/dpdp_dsr_service.dart';
import '../dialogs/erasure_confirmation_dialog.dart';
import 'dsr_status_tracker_screen.dart';

/// Data Principal Rights Center implementing DPDP Act 2023 Sections 11, 12, and 13.
class DataRightsCenterScreen extends StatefulWidget {
  final DpdpDsrService? dsrService;

  const DataRightsCenterScreen({super.key, this.dsrService});

  @override
  State<DataRightsCenterScreen> createState() => _DataRightsCenterScreenState();
}

class _DataRightsCenterScreenState extends State<DataRightsCenterScreen> {
  late final DpdpDsrService _dsrService;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _dsrService = widget.dsrService ?? DpdpDsrService();
  }

  Future<void> _handleDataExport() async {
    setState(() => _isProcessing = true);
    try {
      final exportPackage = await _dsrService.requestDataPortabilityExport();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Portability Archive Generated! (${exportPackage.totalVouchers} vouchers, ${exportPackage.totalAccounts} accounts)',
            ),
            backgroundColor: AppColors.debitGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate export: $e'), backgroundColor: AppColors.creditRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleRectification() async {
    final entityController = TextEditingController();
    final correctionController = TextEditingController();

    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Correction / सुधार अनुरोध'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: entityController,
              decoration: const InputDecoration(labelText: 'Entity Type (e.g. Ledger Name, GSTIN)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: correctionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Correction Details / नया विवरण'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit / भेजें'),
          ),
        ],
      ),
    );

    if (submit == true && mounted) {
      await _dsrService.submitRectificationRequest(
        entityType: entityController.text.trim(),
        entityId: 'MANUAL_REQUEST',
        requestedCorrections: {'details': correctionController.text.trim()},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rectification request submitted successfully!'), backgroundColor: AppColors.debitGreen),
        );
      }
    }
  }

  Future<void> _handleErasure() async {
    await ErasureConfirmationDialog.show(
      context,
      onConfirm: (reason) async {
        setState(() => _isProcessing = true);
        try {
          final res = await _dsrService.requestAccountErasure(reason: reason);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(res['message'] ?? 'Account data pseudonymized.'), backgroundColor: AppColors.debitGreen),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erasure request failed: $e'), backgroundColor: AppColors.creditRed),
            );
          }
        } finally {
          if (mounted) setState(() => _isProcessing = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Principal Rights / डेटा अधिकार', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'Request History / इतिहास',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DsrStatusTrackerScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppColors.standardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 32),
                    const SizedBox(height: 10),
                    const Text(
                      'Your Rights Under DPDP Act 2023\nभारतीय डेटा संरक्षण कानून के तहत आपके अधिकार',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Access, portability, correction, and erasure of your personal data at any time.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Hub Card 1: Data Portability
              _buildRightCard(
                icon: Icons.download_for_offline_outlined,
                iconColor: AppColors.primary,
                title: 'Download My Data (Portability)',
                hindiTitle: 'संपूर्ण डेटा डाउनलोड करें (बैकअप)',
                description: 'Export all accounting ledgers, vouchers, stock items, and audit logs into standard JSON/ZIP archive.',
                actionLabel: _isProcessing ? 'Generating...' : 'Export Data / डाउनलोड करें',
                onAction: _isProcessing ? null : _handleDataExport,
              ),
              const SizedBox(height: 12),

              // Hub Card 2: Rectification
              _buildRightCard(
                icon: Icons.edit_note_outlined,
                iconColor: AppColors.secondary,
                title: 'Correct My Information (Rectification)',
                hindiTitle: 'डेटा सुधार अनुरोध दर्ज करें',
                description: 'Request correction or update of inaccurate financial identifiers, contact details, or tax registration metadata.',
                actionLabel: 'Submit Correction / सुधारें',
                onAction: _handleRectification,
              ),
              const SizedBox(height: 12),

              // Hub Card 3: Summary of Personal Data
              _buildRightCard(
                icon: Icons.summarize_outlined,
                iconColor: AppColors.infoBlue,
                title: 'Summary of Personal Data',
                hindiTitle: 'व्यक्तिगत डेटा सारांश',
                description: 'Review transparently all categories of personal data processed, retention periods, and third-party NIC API disclosures.',
                actionLabel: 'View Summary / देखें',
                onAction: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Viewing sovereign data inventory...')),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Hub Card 4: Erasure / Right to be Forgotten (Danger Card)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                  side: BorderSide(color: AppColors.creditRed.withOpacity(0.4)),
                ),
                color: AppColors.creditRedLight.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.delete_forever_outlined, color: AppColors.creditRed, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Erase Account & Personal Data', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.creditRed)),
                                Text('खाता एवं व्यक्तिगत डेटा मिटाएं', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Deactivates account and pseudonymizes party names while archiving statutory books under Section 128 (8-year audit retention).',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: AppColors.minTouchTargetSize,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.creditRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _handleErasure,
                          child: const Text('Request Erasure / डेटा मिटाएं', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String hindiTitle,
    required String description,
    required String actionLabel,
    required VoidCallback? onAction,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
        side: const BorderSide(color: AppColors.surfaceVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(hindiTitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 14),

            SizedBox(
              height: AppColors.minTouchTargetSize,
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: iconColor,
                  side: BorderSide(color: iconColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onAction,
                child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
