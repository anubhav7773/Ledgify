import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../dpdp_compliance/presentation/screens/data_rights_center_screen.dart';
import '../../../monetization/presentation/screens/subscription_paywall_screen.dart';
import 'learned_aliases_screen.dart';

/// User Profile, Organization Settings, and Privacy Preferences (Google Stitch UI).
class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Profile & Settings', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppColors.standardPadding),
          children: [
            // User Header Profile Card
            Card(
              elevation: 0,
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
                      child: const Text(
                        'AE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Apex Enterprises Ltd.',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
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
                          const Text(
                            'GSTIN: 27AAAAA0000A1Z5',
                            style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textSecondary),
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
              elevation: 0,
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
                    onTap: () {},
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
              elevation: 0,
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
                    onTap: () {},
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
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: trailingBadge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                trailingBadge,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.primary),
              ),
            )
          : const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
