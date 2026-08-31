import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/safe_executor.dart';

/// Authentication service managing Google Sign-In and Firebase token refresh lifecycle.
/// Adheres strictly to docs/03_security_auth_and_rls_matrix.md.
class AuthService {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  /// Stream of user authentication state changes
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  /// Currently authenticated user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Executes Google OAuth Sign-In flow and forces a token refresh
  /// to ensure the custom claim `role: 'authenticated'` is immediately present.
  Future<UserCredential> signInWithGoogle() async {
    return await executeSafely<UserCredential>(() async {
      try {
        // 1. Trigger the Google Sign-In authentication flow
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw const ServerFailure(
            message: 'Google Sign-In was cancelled by user.',
            code: 'AUTH_CANCELLED',
          );
        }

        // 2. Obtain authentication details from Google
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        // 3. Create a credential for Firebase Authentication
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // 4. Sign in to Firebase with the credential
        final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
        final User? user = userCredential.user;

        if (user != null) {
          // 5. Force-refresh the ID token to ensure custom claims from
          // Firebase 2nd Gen Blocking Functions (beforeUserCreated / beforeUserSignedIn)
          // are attached before Supabase PostgREST queries are executed.
          final String? freshToken = await user.getIdToken(true);
          debugPrint('Firebase Auth token refreshed with custom claims. UID: ${user.uid}');
          if (freshToken == null) {
            throw const ServerFailure(
              message: 'Failed to obtain fresh JWT token from Firebase.',
              code: 'JWT_FETCH_FAILED',
            );
          }
        }

        return userCredential;
      } on FirebaseAuthException catch (e, stackTrace) {
        debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
        throw ServerFailure(
          message: e.message ?? 'Authentication error occurred.',
          code: e.code,
          stackTrace: stackTrace,
        );
      } catch (e, stackTrace) {
        if (e is Failure) rethrow;
        debugPrint('Sign-in Error: $e');
        throw ServerFailure(
          message: e.toString(),
          stackTrace: stackTrace,
        );
      }
    });
  }

  /// Signs out of Firebase and Google Sign-In
  Future<void> signOut() async {
    await executeSafely<void>(() async {
      await Future.wait([
        _firebaseAuth.signOut(),
        _googleSignIn.signOut(),
      ]);
      debugPrint('User successfully signed out.');
    });
  }
}
