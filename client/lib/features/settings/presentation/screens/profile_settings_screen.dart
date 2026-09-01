import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/services/auth_service.dart';
import '../../../dpdp_compliance/presentation/screens/data_rights_center_screen.dart';
import '../../../monetization/presentation/screens/subscription_paywall_screen.dart';
import 'learned_aliases_screen.dart';

/// User Profile, Organization Settings, and Privacy Preferences.
class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  String _companyName = 'Apex Enterprises Ltd.';
  String _tradeName = 'Apex Global Tech';
  String _gstin = '27AAAAA0000A1Z5';
  String _pan = 'AAAAA0000A';
  String _address = 'Plot 42, MIDC Industrial Area, Andheri East, Mumbai, Maharashtra 400093';
  bool _isBiometricEnabled = false;
  String _pin = '••••';

  void _showOrganizationDetailsDialog() {
    final nameCtrl = TextEditingController(text: _companyName);
    final tradeCtrl = TextEditingController(text: _tradeName);
    final gstinCtrl = TextEditingController(text: _gstin);
    final panCtrl = TextEditingController(text: _pan);
    final addrCtrl = TextEditingController(text: _address);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Organization Details', style: AppTypography.cardHeader),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Legal Entity Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: tradeCtrl,
                  decoration: const InputDecoration(labelText: 'Trade Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: gstinCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'GSTIN *', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: panCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'PAN *', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addrCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Registered Address', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: AppColors.minTouchTargetSize,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() {
                        _companyName = nameCtrl.text.trim();
                        _tradeName = tradeCtrl.text.trim();
                        _gstin = gstinCtrl.text.trim();
                        _pan = panCtrl.text.trim();
                        _address = addrCtrl.text.trim();
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Organization details saved!'), backgroundColor: AppColors.debitGreen),
                      );
                    },
                    child: const Text('Save Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBiometricDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('App Lock & Biometrics', style: AppTypography.cardHeader),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Biometric Authentication', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Require Fingerprint / Face ID to open app and view financial balances'),
                  value: _isBiometricEnabled,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setSheetState(() => _isBiometricEnabled = val);
                    setState(() => _isBiometricEnabled = val);
                  },
                ),
                const Divider(height: 20),
                ListTile(
                  leading: const Icon(Icons.pin_outlined, color: AppColors.primary),
                  title: const Text('4-Digit Security PIN', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Current PIN: $_pin'),
                  trailing: TextButton(
                    onPressed: () {
                      final pinCtrl = TextEditingController();
                      showDialog(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Set 4-Digit PIN'),
                          content: TextField(
                            controller: pinCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'New 4-digit PIN', border: OutlineInputBorder()),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () {
                                if (pinCtrl.text.length == 4) {
                                  setState(() => _pin = pinCtrl.text);
                                  setSheetState(() {});
                                  Navigator.pop(dCtx);
                                }
                              },
                              child: const Text('Save PIN'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Change PIN'),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isBiometricEnabled ? 'Biometric security activated!' : 'Security preferences updated.'),
                        backgroundColor: AppColors.debitGreen,
                      ),
                    );
                  },
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Profile & Settings', style: AppTypography.cardHeader),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppColors.standardPadding),
          children: [
            // User Header Profile Card
            Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        _companyName.isNotEmpty ? _companyName.substring(0, 2).toUpperCase() : 'AE',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _companyName,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'PRO',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'GSTIN: $_gstin',
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'admin@apexenterprises.in',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Section 1: Business & Accounting
            Text('Business & Accounting', style: AppTypography.cardHeader),
            const SizedBox(height: 10),

            Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.business_center_rounded,
                    title: 'Organization Details',
                    subtitle: 'Legal Entity Name, Registered Address, PAN',
                    onTap: _showOrganizationDetailsDialog,
                  ),
                  const Divider(height: 1),
                  _buildSettingsTile(
                    icon: Icons.psychology_alt_rounded,
                    title: 'AI Learned Vendor Aliases',
                    subtitle: 'Manage OCR neural memory and ledger auto-mapping rules',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LearnedAliasesScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildSettingsTile(
                    icon: Icons.workspace_premium_rounded,
                    title: 'Subscription & Billing',
                    subtitle: 'Active Pro Plan • Renews August 2027',
                    trailingBadge: 'Upgrade',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SubscriptionPaywallScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 2: Privacy & Security
            Text('Privacy & Compliance', style: AppTypography.cardHeader),
            const SizedBox(height: 10),

            Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.security_rounded,
                    title: 'DPDP Data Principal Rights',
                    subtitle: 'Data portability, rectification, and right to be forgotten',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DataRightsCenterScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildSettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'App Lock & Biometric PIN',
                    subtitle: 'Require Fingerprint / Face Unlock to view balances',
                    onTap: _showBiometricDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout CTA Button
            SizedBox(
              height: AppColors.minTouchTargetSize,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.creditRed,
                  side: const BorderSide(color: AppColors.creditRed, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                onPressed: () async {
                  try {
                    await AuthService().signOut();
                  } catch (_) {}
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    String? trailingBadge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (trailingBadge != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trailingBadge,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.primary),
                ),
              ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
