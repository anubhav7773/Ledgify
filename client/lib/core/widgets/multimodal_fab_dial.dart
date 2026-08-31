import 'package:flutter/material.dart';
import '../../features/ai_intake/presentation/screens/document_scanner_screen.dart';
import '../../features/ai_intake/presentation/screens/voice_voucher_screen.dart';
import 'package:ledgify/features/masters/presentation/widgets/quick_create_ledger_bottom_sheet.dart';
import '../../features/vouchers/presentation/screens/voucher_entry_screen.dart';
import '../theme/app_colors.dart';

/// Multi-Modal Speed Dial Floating Action Button for AI OCR, Voice Voucher, Manual Entry, and Quick Ledger.
class MultimodalFabDial extends StatefulWidget {
  const MultimodalFabDial({super.key});

  @override
  State<MultimodalFabDial> createState() => _MultimodalFabDialState();
}

class _MultimodalFabDialState extends State<MultimodalFabDial> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _navigateTo(Widget screen) {
    _toggle();
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen) ...[
          // Option 4: Quick Ledger
          _buildSpeedDialItem(
            icon: Icons.person_add_alt_1_outlined,
            label: 'New Ledger / नया खाता',
            color: AppColors.secondary,
            onTap: () {
              _toggle();
              QuickCreateLedgerBottomSheet.show(context, initialName: '');
            },
          ),
          const SizedBox(height: 12),

          // Option 3: Manual Entry
          _buildSpeedDialItem(
            icon: Icons.edit_note_outlined,
            label: 'Manual Voucher / मैन्युअल वाउचर',
            color: AppColors.primary,
            onTap: () => _navigateTo(const VoucherEntryScreen()),
          ),
          const SizedBox(height: 12),

          // Option 2: Voice Note
          _buildSpeedDialItem(
            icon: Icons.mic_none_outlined,
            label: 'Voice Voucher / बोलकर दर्ज करें',
            color: const Color(0xFFE11D48), // Rose
            onTap: () => _navigateTo(const VoiceVoucherScreen()),
          ),
          const SizedBox(height: 12),

          // Option 1: Scan Bill (Gemini OCR)
          _buildSpeedDialItem(
            icon: Icons.camera_alt_outlined,
            label: 'Scan Bill (OCR) / बिल स्कैन करें',
            color: const Color(0xFF2563EB), // Blue
            onTap: () => _navigateTo(const DocumentScannerScreen()),
          ),
          const SizedBox(height: 16),
        ],

        // Central Primary FAB (Min 48dp Touch Target)
        SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            elevation: 4,
            backgroundColor: _isOpen ? AppColors.creditRed : AppColors.primary,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            onPressed: _toggle,
            child: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _expandAnimation,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedDialItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ScaleTransition(
      scale: _expandAnimation,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: AppColors.surfaceVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
