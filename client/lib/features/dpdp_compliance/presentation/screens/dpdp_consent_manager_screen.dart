import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/models/dpdp_consent_log_model.dart';
import '../../domain/models/dpdp_purpose.dart';
import '../../domain/services/dpdp_consent_service.dart';

/// Screen managing DPDP Act 2023 privacy settings, active consent toggles, and audit logs.
class DpdpConsentManagerScreen extends StatefulWidget {
  final DpdpConsentService? consentService;

  const DpdpConsentManagerScreen({super.key, this.consentService});

  @override
  State<DpdpConsentManagerScreen> createState() => _DpdpConsentManagerScreenState();
}

class _DpdpConsentManagerScreenState extends State<DpdpConsentManagerScreen> {
  late final DpdpConsentService _consentService;
  Map<DpdpPurpose, bool> _activeConsents = {};
  List<DpdpConsentLogModel> _auditLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _consentService = widget.consentService ?? DpdpConsentService();
    _loadConsentStates();
  }

  Future<void> _loadConsentStates() async {
    setState(() => _isLoading = true);

    final Map<DpdpPurpose, bool> states = {};
    for (final purpose in DpdpPurpose.values) {
      states[purpose] = await _consentService.checkConsent(purpose);
    }

    final logs = await _consentService.fetchConsentAuditHistory();

    if (mounted) {
      setState(() {
        _activeConsents = states;
        _auditLogs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleConsent(DpdpPurpose purpose, bool currentValue) async {
    if (currentValue) {
      // Prompt revocation confirmation
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Revoke Consent? / सहमति वापस लें?'),
          content: Text(
            'Revoking consent for "${purpose.titleEnglish}" will disable AI parsing/automated processing for this feature until consent is re-granted.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.creditRed, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Revoke / वापस लें'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _consentService.revokeConsent(purpose);
        await _loadConsentStates();
      }
    } else {
      await _consentService.grantConsent(purpose);
      await _loadConsentStates();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy & Consent Manager', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppColors.standardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Statutory Header Info Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Indian DPDP Act 2023 Compliant. You have total sovereign control over what data is processed.',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Purposes Toggles Section
                    const Text('Data Processing Purposes / डेटा उपयोग के उद्देश्य', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 10),

                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                        side: const BorderSide(color: AppColors.surfaceVariant),
                      ),
                      child: Column(
                        children: DpdpPurpose.values.map((purpose) {
                          final isGranted = _activeConsents[purpose] ?? false;

                          return SwitchListTile(
                            title: Text(purpose.titleEnglish, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                            subtitle: Text('${purpose.titleHindi}\n${purpose.code}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            value: isGranted,
                            activeColor: AppColors.primary,
                            onChanged: (val) => _toggleConsent(purpose, isGranted),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Immutable Audit Trail Table
                    const Text('Unalterable Consent Audit Log / सहमति इतिहास', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 10),

                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                        side: const BorderSide(color: AppColors.surfaceVariant),
                      ),
                      child: _auditLogs.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Center(child: Text('No historical consent actions recorded.')),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _auditLogs.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final log = _auditLogs[index];
                                final isGranted = log.consentStatus == 'GRANTED';

                                return ListTile(
                                  leading: Icon(
                                    isGranted ? Icons.check_circle : Icons.cancel,
                                    color: isGranted ? AppColors.debitGreen : AppColors.creditRed,
                                  ),
                                  title: Text(log.purpose.titleEnglish, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  subtitle: Text(
                                    '${log.consentStatus} • ${DateFormatter.formatVoucherDate(log.grantedAt)} • Hash: ${log.consentPayloadHash.substring(0, 10)}...',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
