import 'dpdp_purpose.dart';

/// Failure thrown when a statutory operation is blocked due to lack of valid DPDP user consent.
class DpdpConsentRequiredFailure implements Exception {
  final DpdpPurpose purpose;
  final String message;

  const DpdpConsentRequiredFailure({
    required this.purpose,
    this.message = 'Statutory DPDP consent is required to proceed with this operation.',
  });

  @override
  String toString() => 'DpdpConsentRequiredFailure: $message (${purpose.code})';
}
