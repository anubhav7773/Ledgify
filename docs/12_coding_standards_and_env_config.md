# 12_coding_standards_and_env_config.md — Coding Standards, Dependencies, Environment Configuration & Error Protocols

## 1. Overview & Development Philosophy
This document establishes the universal coding standards, exact dependency versions, environment configurations, and error-handling protocols for Ledgify across all components (Flutter Client, Supabase PostgreSQL, Deno Edge Functions, and Firebase Blocking Functions).

### Core Engineering Invariants:
1. **Zero Loose Typings:** Never use `dynamic` (Dart), `any` (TypeScript), or untyped SQL functions without explicit parameter and return signatures.
2. **Explicit Error Boundaries:** No bare `catch (e)` blocks. All exceptions must be mapped to typed failure domain models with structured logging.
3. **Deterministic Financial Math:** Never use standard binary floating-point calculations for financial currency math without strict precision rounding (`toStringAsFixed(2)` in Dart, `NUMERIC(15, 2)` in PostgreSQL).
4. **Environment Isolation:** Secrets, API keys, and service account tokens must never be hardcoded or checked into version control.

---

## 2. Naming Conventions & Project Standards

| Domain / Language | Entity | Convention | Example |
| :--- | :--- | :--- | :--- |
| **PostgreSQL** | Tables & Views | `snake_case` (pluralized) | `voucher_line_items`, `fixed_assets` |
| **PostgreSQL** | Columns & Foreign Keys | `snake_case` (singular) | `business_id`, `stock_item_id`, `amount` |
| **PostgreSQL** | Triggers & Functions | `snake_case` prefixed with `trg_` / verb | `trg_enforce_voucher_zero_sum`, `calculate_asset_depreciation` |
| **Flutter / Dart** | Classes & Enums | `PascalCase` | `AiConfirmationCard`, `VoucherTypeCategory` |
| **Flutter / Dart** | Files & Folders | `snake_case` | `gemini_pipeline_service.dart`, `color_tokens.dart` |
| **Flutter / Dart** | Variables & Methods | `camelCase` | `calculateTaxSplit()`, `totalTaxableValue` |
| **Deno / TypeScript** | Files & Folders | `kebab-case` (folders) / `index.ts` | `verify-purchase/index.ts`, `play-billing-rtdn/index.ts` |
| **Deno / TypeScript** | Functions & Variables | `camelCase` | `getGoogleOAuthToken()`, `purchaseToken` |

---

## 3. Flutter Client Configuration & Dependencies

### `client/pubspec.yaml`
```yaml
name: ledgify
description: "AI-Autonomous TallyPrime clone for Indian MSMEs."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: ">=3.19.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # Identity & Authentication
  firebase_core: ^2.30.0
  firebase_auth: ^4.19.4
  google_sign_in: ^6.2.1

  # Backend & Database
  supabase_flutter: ^2.5.6

  # Monetization
  in_app_purchase: ^3.2.0
  in_app_purchase_android: ^0.3.3

  # UI / UX, Icons & Vernacular Fonts
  google_fonts: ^6.2.1
  flutter_svg: ^2.0.10+1
  intl: ^0.19.0

  # Hardware, Media & Audio Capture
  camera: ^0.10.6
  record: ^5.1.2
  path_provider: ^2.1.3
  image_picker: ^1.1.1
  file_picker: ^8.0.3

  # Network & Utilities
  http: ^1.2.1
  flutter_dotenv: ^5.1.0
  uuid: ^4.4.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/fonts/
    - assets/icons/
    - .env

  fonts:
    - family: NotoSansDevanagari
      fonts:
        - asset: assets/fonts/NotoSansDevanagari-Regular.ttf
          weight: 400
        - asset: assets/fonts/NotoSansDevanagari-Medium.ttf
          weight: 500
        - asset: assets/fonts/NotoSansDevanagari-Bold.ttf
          weight: 700
4. Deno Edge Functions & Backend Dependencies
supabase/functions/deno.json
JSON
{
  "compilerOptions": {
    "allowJs": true,
    "strict": true,
    "lib": ["deno.window", "deno.ns"]
  },
  "imports": {
    "std/": "[https://deno.land/std@0.177.0/](https://deno.land/std@0.177.0/)",
    "@supabase/supabase-js": "[https://esm.sh/@supabase/supabase-js@2.39.8](https://esm.sh/@supabase/supabase-js@2.39.8)",
    "jose": "[https://esm.sh/jose@5.2.3](https://esm.sh/jose@5.2.3)"
  }
}
5. Firebase Functions Configuration (firebase/functions/package.json)
JSON
{
  "name": "ledgify-firebase-functions",
  "scripts": {
    "lint": "eslint --ext .js,.ts .",
    "build": "tsc",
    "serve": "npm run build && firebase emulators:start --only functions",
    "shell": "npm run build && firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "engines": {
    "node": "20"
  },
  "main": "lib/index.js",
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0"
  },
  "devDependencies": {
    "@typescript-eslint/eslint-plugin": "^7.0.0",
    "@typescript-eslint/parser": "^7.0.0",
    "eslint": "^8.57.0",
    "typescript": "^5.4.0"
  },
  "private": true
}
6. Environment Configuration Files
6.1 Flutter Client .env.example
Ini, TOML
# Supabase Configuration
SUPABASE_URL=[https://your-project-ref.supabase.co](https://your-project-ref.supabase.co)
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Google Gemini API
GEMINI_API_KEY=AIzaSyD...
GEMINI_MODEL_NAME=gemini-2.5-flash

# Firebase Project Mapping
FIREBASE_PROJECT_ID=ledgify-prod
FIREBASE_WEB_CLIENT_ID=your-google-client-id.apps.googleusercontent.com

# Server Endpoints (Edge Functions)
SERVER_VERIFY_PURCHASE_URL=[https://your-project-ref.supabase.co/functions/v1/verify-purchase](https://your-project-ref.supabase.co/functions/v1/verify-purchase)

# DPDP Notice & App Version
DPDP_NOTICE_VERSION=v1.0_20260831
APP_ENVIRONMENT=development
6.2 Supabase Edge Functions Environment Variables (.env.local / Secrets)
Ini, TOML
SUPABASE_URL=[https://your-project-ref.supabase.co](https://your-project-ref.supabase.co)
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Google Play Developer Service Account JSON (Single-line escaped JSON string)
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"ledgify-prod",...}

# Google Cloud Pub/Sub Audience verification for RTDN
GOOGLE_PUBSUB_AUDIENCE=[https://your-project-ref.supabase.co/functions/v1/play-billing-rtdn](https://your-project-ref.supabase.co/functions/v1/play-billing-rtdn)
7. Global Error Handling & Exception Management Protocols
7.1 Dart Failure Domain Models
Dart
// client/lib/core/errors/failures.dart
abstract class Failure {
  final String message;
  final String? code;
  final StackTrace? stackTrace;

  const Failure({required this.message, this.code, this.stackTrace});

  @override
  String toString() => 'Failure(code: $code, message:$message)';
}

class ServerFailure extends Failure {
  const ServerFailure({required String message, String? code, StackTrace? stackTrace})
      : super(message: message, code: code, stackTrace: stackTrace);
}

class GeminiRateLimitFailure extends Failure {
  final int retryAfterSeconds;
  const GeminiRateLimitFailure({required String message, this.retryAfterSeconds = 5})
      : super(message: message, code: 'GEMINI_429_RATE_LIMIT');
}

class AccountingInvariantFailure extends Failure {
  const AccountingInvariantFailure({required String message})
      : super(message: message, code: 'DOUBLE_ENTRY_UNBALANCED');
}

class DpdpConsentRequiredFailure extends Failure {
  const DpdpConsentRequiredFailure({required String message})
      : super(message: message, code: 'DPDP_CONSENT_MISSING');
}
7.2 Structured Repository Call Wrapper
Dart
// client/lib/core/utils/safe_executor.dart
import 'package:flutter/foundation.dart';
import '../errors/failures.dart';

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
8. Git Commit & PR Standards
Commits must follow the Conventional Commits specification:

feat(accounting): implement zero-sum deferred constraint trigger

fix(gst): correct inter-state IGST calculation rounding

feat(ai-intake): add thinking_level minimal config to Gemini pipeline

sec(rls): apply AS RESTRICTIVE guard across master tables

docs(spec): update Section 17(5) blocked ITC classification table