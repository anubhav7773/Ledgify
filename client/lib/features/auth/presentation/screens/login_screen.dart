import 'package:flutter/material.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../../services/auth_service.dart';

/// Material 3 Expressive login screen designed for Indian MSME owners and traders.
/// Features bilingual typography, high-contrast visual hierarchy, and 48dp touch targets.
/// Adheres strictly to docs/10_ui_ux_design_system_tokens.md.
class LoginScreen extends StatefulWidget {
  final AuthService? authService;
  final VoidCallback? onLoginSuccess;

  const LoginScreen({
    super.key,
    this.authService,
    this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthService _authService;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithGoogle();
      if (mounted) {
        widget.onLoginSuccess?.call();
      }
    } on Failure catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: LedgifyColors.creditRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign-in failed. Please try again.'),
            backgroundColor: LedgifyColors.creditRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LedgifyColors.surfaceLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LedgifyColors.standardPadding * 1.5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Branding Logo & Identity
                Container(
                  width: 80,
                  height: 80,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: LedgifyColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 44,
                    color: LedgifyColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 24),

                // Bilingual App Title
                const Text(
                  'Ledgify / लेजिफाइ',
                  textAlign: TextAlign.center,
                  style: LedgifyTypography.displayTitle,
                ),
                const SizedBox(height: 6),
                const Text(
                  'स्वायत्त व्यापार और लेखांकन',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: LedgifyTypography.fontDeva,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w500,
                    color: LedgifyColors.secondarySlate,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'AI-Autonomous Mobile Tally for MSMEs',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: LedgifyTypography.fontDeva,
                    fontSize: 13.0,
                    color: LedgifyColors.secondarySlate,
                  ),
                ),
                const SizedBox(height: 48),

                // Feature Highlights Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LedgifyColors.cardBorderRadius),
                    side: const BorderSide(color: LedgifyColors.surfaceVariant),
                  ),
                  color: LedgifyColors.surfaceCard,
                  child: Padding(
                    padding: const EdgeInsets.all(LedgifyColors.standardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFeatureItem(
                          icon: Icons.document_scanner_outlined,
                          title: 'OCR Bill & Receipt Scanner',
                          titleHi: 'कैमरा बिल स्कैनर',
                        ),
                        const Divider(height: 20),
                        _buildFeatureItem(
                          icon: Icons.mic_none_outlined,
                          title: 'Voice-to-Voucher Entry',
                          titleHi: 'बोलकर वाउचर बनाएं',
                        ),
                        const Divider(height: 20),
                        _buildFeatureItem(
                          icon: Icons.verified_user_outlined,
                          title: 'GST E-Invoice & E-Way Bill Ready',
                          titleHi: 'जीएसटी ई-चालान और ई-वे बिल',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Error Message Indicator if present
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: LedgifyColors.creditRedBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: LedgifyColors.creditRed, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: LedgifyColors.creditRed,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Google Sign-In Button (48dp Minimum Touch Target)
                SizedBox(
                  height: LedgifyColors.minTouchTargetSize,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LedgifyColors.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.g_mobiledata_rounded, size: 30),
                              SizedBox(width: 8),
                              Text(
                                'Sign in with Google / गूगल से साइन इन करें',
                                style: TextStyle(
                                  fontFamily: LedgifyTypography.fontDeva,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // DPDP Notice Footer
                const Text(
                  'सुरक्षित एवं DPDP अधिनियम 2023 के अनुरूप • 100% Data Encrypted',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: LedgifyTypography.fontDeva,
                    fontSize: 11,
                    color: LedgifyColors.secondarySlate,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String titleHi,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: LedgifyColors.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: LedgifyColors.primaryBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                titleHi,
                style: const TextStyle(
                  fontFamily: LedgifyTypography.fontDeva,
                  fontSize: 12,
                  color: LedgifyColors.secondarySlate,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
