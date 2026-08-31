import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum BadgeStatus { active, pending, reconciled, failed, cancelled, warning }

/// Compact semantic pill badge for status indications across Ledgify.
class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeStatus status;

  const StatusBadge({
    super.key,
    required this.label,
    this.status = BadgeStatus.active,
  });

  factory StatusBadge.fromString(String statusString) {
    final lower = statusString.toLowerCase();
    if (lower.contains('active') || lower.contains('success') || lower.contains('reconciled') || lower.contains('paid')) {
      return StatusBadge(label: statusString, status: BadgeStatus.active);
    } else if (lower.contains('pending') || lower.contains('hold') || lower.contains('wait')) {
      return StatusBadge(label: statusString, status: BadgeStatus.pending);
    } else if (lower.contains('fail') || lower.contains('reject') || lower.contains('error')) {
      return StatusBadge(label: statusString, status: BadgeStatus.failed);
    } else if (lower.contains('cancel') || lower.contains('void')) {
      return StatusBadge(label: statusString, status: BadgeStatus.cancelled);
    }
    return StatusBadge(label: statusString, status: BadgeStatus.warning);
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;

    switch (status) {
      case BadgeStatus.active:
      case BadgeStatus.reconciled:
        bg = AppColors.debitGreenLight;
        text = AppColors.debitGreen;
        break;
      case BadgeStatus.pending:
        bg = AppColors.warningAmberLight;
        text = AppColors.warningAmber;
        break;
      case BadgeStatus.failed:
      case BadgeStatus.cancelled:
        bg = AppColors.creditRedLight;
        text = AppColors.creditRed;
        break;
      case BadgeStatus.warning:
        bg = AppColors.infoBlueLight;
        text = AppColors.infoBlue;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }
}
