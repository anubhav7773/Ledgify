import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AppButtonVariant { filled, outlined, tonal }

/// Base button component enforcing 48x48 dp touch targets and built-in loading states.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final AppButtonVariant variant;
  final Color? color;
  final double? width;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = AppButtonVariant.filled,
    this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? AppColors.primary;

    Widget buttonChild;
    if (isLoading) {
      buttonChild = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: variant == AppButtonVariant.filled ? Colors.white : themeColor,
        ),
      );
    } else if (icon != null) {
      buttonChild = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      );
    } else {
      buttonChild = Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14));
    }

    Widget button;

    switch (variant) {
      case AppButtonVariant.filled:
        button = ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(AppColors.minTouchTargetSize, AppColors.minTouchTargetSize),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: isLoading ? null : onPressed,
          child: buttonChild,
        );
        break;
      case AppButtonVariant.outlined:
        button = OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: themeColor,
            side: BorderSide(color: themeColor),
            minimumSize: const Size(AppColors.minTouchTargetSize, AppColors.minTouchTargetSize),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: isLoading ? null : onPressed,
          child: buttonChild,
        );
        break;
      case AppButtonVariant.tonal:
        button = FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: themeColor.withOpacity(0.12),
            foregroundColor: themeColor,
            minimumSize: const Size(AppColors.minTouchTargetSize, AppColors.minTouchTargetSize),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: isLoading ? null : onPressed,
          child: buttonChild,
        );
        break;
    }

    if (width != null) {
      return SizedBox(width: width, child: button);
    }
    return button;
  }
}
