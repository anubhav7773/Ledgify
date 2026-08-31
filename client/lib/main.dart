import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/network/supabase_client.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/presentation/app_shell.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Notice: .env file not loaded directly: $e');
  }

  // 2. Initialize Firebase with platform-specific credentials
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Notice: Firebase initialization fallback: $e');
  }

  // 3. Initialize Supabase Client with dynamic Firebase JWT callback
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://mock.supabase.co';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 'mock-anon-key';

  try {
    await SupabaseClientService.initialize(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Notice: Supabase client initialization deferred/mocked: $e');
  }

  runApp(const LedgifyApp());
}

class LedgifyApp extends StatelessWidget {
  const LedgifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ledgify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const AppShell();
        }
        return const LoginScreen();
      },
    );
  }
}
