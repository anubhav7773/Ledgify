import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../domain/services/state_code_constants.dart';

/// Searchable Place of Supply (POS) picker widget.
/// Auto-extracts state codes from customer GSTIN and manages statutory state mapping.
class PosSelectorDropdown extends StatelessWidget {
  final int selectedStateCode;
  final ValueChanged<int> onStateCodeChanged;
  final String? customerGstin;

  const PosSelectorDropdown({
    super.key,
    required this.selectedStateCode,
    required this.onStateCodeChanged,
    this.customerGstin,
  });

  @override
  Widget build(BuildContext context) {
    // If customerGstin is provided, check if it overrides the POS
    final int? gstinStateCode = GstStateCodes.extractStateCodeFromGstin(customerGstin);
    final int effectiveCode = gstinStateCode != null && GstStateCodes.isValidStateCode(gstinStateCode)
        ? gstinStateCode
        : selectedStateCode;

    return DropdownButtonFormField<int>(
      value: GstStateCodes.isValidStateCode(effectiveCode) ? effectiveCode : 27, // Default Maharashtra (27)
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Place of Supply (POS) *',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.location_on_outlined),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        helperText: gstinStateCode != null
            ? 'Auto-detected from Party GSTIN (${gstinStateCode.toString().padLeft(2, '0')})'
            : 'Select transaction Place of Supply',
        helperStyle: TextStyle(
          color: gstinStateCode != null ? LedgifyColors.primaryBlue : LedgifyColors.secondarySlate,
          fontSize: 11,
        ),
      ),
      items: GstStateCodes.stateMap.keys.map((code) {
        return DropdownMenuItem<int>(
          value: code,
          child: Text(
            GstStateCodes.getStateDisplayName(code),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5),
          ),
        );
      }).toList(),
      onChanged: (newCode) {
        if (newCode != null) {
          onStateCodeChanged(newCode);
        }
      },
    );
  }
}
