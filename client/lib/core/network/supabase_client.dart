import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service managing Supabase client initialization with dynamic Firebase JWT injection.
/// Eliminates manual Authorization headers and satisfies zero-trust third-party auth.
/// Adheres strictly to docs/03_security_auth_and_rls_matrix.md.
class SupabaseClientService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        accessToken: () async {
          final user = fb_auth.FirebaseAuth.instance.currentUser;
          if (user != null) {
            // Retrieve fresh or cached Firebase ID token for Supabase PostgREST requests
            return await user.getIdToken(false);
          }
          return null;
        },
      );
      debugPrint('SupabaseClient initialized with dynamic Firebase JWT provider.');
    } catch (e, stackTrace) {
      debugPrint('Error initializing SupabaseClient: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }
}
