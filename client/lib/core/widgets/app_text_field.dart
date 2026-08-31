import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Standardized Material 3 text form field with bilingual helper text and currency options.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final String? prefixText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool isAmount;
  final bool isRequired;
  final bool isReadOnly;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const AppTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixText,
    this.prefixIcon,
    this.suffixIcon,
    this.isAmount = false,
    this.isRequired = false,
    this.isReadOnly = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: isReadOnly,
      keyboardType: isAmount
          ? const TextInputType.numberWithOptions(decimal: true)
          : keyboardType,
      onChanged: onChanged,
      validator: (val) {
        if (isRequired && (val == null || val.trim().isEmpty)) {
          return '$label is required';
        }
        return validator?.call(val);
      },
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        hintText: hint,
        helperText: helperText,
        errorText: errorText,
        prefixText: isAmount ? (prefixText ?? '₹ ') : prefixText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isReadOnly ? AppColors.surfaceVariant.withOpacity(0.5) : Colors.white,
      ),
    );
  }
}
