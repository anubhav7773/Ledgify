/// Typed failure domain models for deterministic error boundary handling.
/// Adheres strictly to docs/12_coding_standards_and_env_config.md.
abstract class Failure {
  final String message;
  final String? code;
  final StackTrace? stackTrace;

  const Failure({required this.message, this.code, this.stackTrace});

  @override
  String toString() => 'Failure(code: $code, message: $message)';
}

class ServerFailure extends Failure {
  const ServerFailure({required String message, String? code, StackTrace? stackTrace})
      : super(message: message, code: code, stackTrace: stackTrace);
}

class GeminiRateLimitFailure extends Failure {
  final int retryAfterSeconds;
  const GeminiRateLimitFailure({
    required String message,
    this.retryAfterSeconds = 5,
  }) : super(message: message, code: 'GEMINI_429_RATE_LIMIT');
}

class AccountingInvariantFailure extends Failure {
  const AccountingInvariantFailure({required String message})
      : super(message: message, code: 'DOUBLE_ENTRY_UNBALANCED');
}

class DpdpConsentRequiredFailure extends Failure {
  final String? purpose;
  const DpdpConsentRequiredFailure({required String message, this.purpose})
      : super(message: message, code: 'DPDP_CONSENT_MISSING');
}

class ValidationFailure extends Failure {
  const ValidationFailure({required String message, String? code})
      : super(message: message, code: code ?? 'VALIDATION_ERROR');
}

class AiParsingFailure extends Failure {
  const AiParsingFailure({required String message, String? code})
      : super(message: message, code: code ?? 'AI_PARSING_ERROR');
}
