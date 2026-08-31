import 'package:flutter/foundation.dart';
import '../errors/failures.dart';

/// Deterministic error boundary wrapper mapping unhandled exceptions to [ServerFailure].
/// Ensures no bare unhandled exceptions escape business logic boundaries.
/// Adheres strictly to docs/12_coding_standards_and_env_config.md.
Future<T> executeSafely<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on Failure {
    rethrow;
  } catch (e, stackTrace) {
    debugPrint('Unhandled Exception Caught: $e');
    debugPrint('Stacktrace: $stackTrace');
    throw ServerFailure(
      message: e.toString(),
      stackTrace: stackTrace,
    );
  }
}
