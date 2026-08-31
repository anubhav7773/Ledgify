import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Horizontally scrollable suggestion & repair chips for high-speed conversational AI adjustments.
class AiSuggestionChips extends StatelessWidget {
  final VoidCallback onEditParty;
  final VoidCallback onEditAmount;
  final VoidCallback onSwitchVoucherType;
  final VoidCallback? onAddNarration;
  final VoidCallback? onApplyTds;

  const AiSuggestionChips({
    super.key,
    required this.onEditParty,
    required this.onEditAmount,
    required this.onSwitchVoucherType,
    this.onAddNarration,
    this.onApplyTds,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          _buildChip(
            icon: Icons.person_outline,
            label: 'Change Party / पार्टी बदलें',
            onTap: onEditParty,
          ),
          const SizedBox(width: 8),
          _buildChip(
            icon: Icons.currency_rupee,
            label: 'Edit Amount / राशि बदलें',
            onTap: onEditAmount,
          ),
          const SizedBox(width: 8),
          _buildChip(
            icon: Icons.swap_horiz,
            label: 'Switch Type / प्रकार बदलें',
            onTap: onSwitchVoucherType,
          ),
          if (onAddNarration != null) ...[
            const SizedBox(width: 8),
            _buildChip(
              icon: Icons.comment_outlined,
              label: 'Narration / विवरण',
              onTap: onAddNarration!,
            ),
          ],
          if (onApplyTds != null) ...[
            const SizedBox(width: 8),
            _buildChip(
              icon: Icons.percent,
              label: 'Apply TDS/TCS / टीडीएस',
              onTap: onApplyTds!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: AppColors.minTouchTargetSize,
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: AppColors.primary),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.surfaceCard,
        side: const BorderSide(color: AppColors.surfaceVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: onTap,
      ),
    );
  }
}
