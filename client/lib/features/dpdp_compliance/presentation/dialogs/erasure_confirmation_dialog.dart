import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// High-security confirmation dialog for Right to Erasure under DPDP Act 2023.
class ErasureConfirmationDialog extends StatefulWidget {
  final ValueChanged<String> onConfirm;

  const ErasureConfirmationDialog({super.key, required this.onConfirm});

  static Future<bool?> show(BuildContext context, {required ValueChanged<String> onConfirm}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ErasureConfirmationDialog(onConfirm: onConfirm),
    );
  }

  @override
  State<ErasureConfirmationDialog> createState() => _ErasureConfirmationDialogState();
}

class _ErasureConfirmationDialogState extends State<ErasureConfirmationDialog> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _canDelete = false;

  @override
  void dispose() {
    _textController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _onTextChanged(String val) {
    final clean = val.trim().toUpperCase();
    setState(() {
      _canDelete = clean == 'DELETE' || clean == 'मिटाएं';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(20),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.creditRedLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, size: 36, color: AppColors.creditRed),
            ),
            const SizedBox(height: 14),

            Text(
              'Erase Account & Data?\nखाता एवं डेटा मिटाने का अनुरोध',
              textAlign: TextAlign.center,
              style: AppTypography.cardHeader.copyWith(color: AppColors.creditRed, fontSize: 17),
            ),
            const SizedBox(height: 10),

            // Statutory Legal Harmonization Notice
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningAmberLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warningAmber.withOpacity(0.4)),
              ),
              child: const Text(
                'Statutory Notice: All personal identifiers, contact numbers, and AI caches will be permanently erased. Under Section 128 of the Companies Act / Income Tax Act, double-entry financial voucher records and GSTINs are pseudonymized and archived for mandatory 8-year tax audit compliance.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.3),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Erasure (Optional)',
                hintText: 'e.g. Closing business...',
              ),
            ),
            const SizedBox(height: 12),

            const Text(
              'Type "DELETE" below to confirm:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),

            TextField(
              controller: _textController,
              onChanged: _onTextChanged,
              decoration: const InputDecoration(
                hintText: 'DELETE',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons (48dp Touch Targets)
            SizedBox(
              height: AppColors.minTouchTargetSize,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.creditRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _canDelete
                    ? () {
                        widget.onConfirm(_reasonController.text.trim());
                        Navigator.pop(context, true);
                      }
                    : null,
                child: const Text('Confirm Account Erasure', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 6),

            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
