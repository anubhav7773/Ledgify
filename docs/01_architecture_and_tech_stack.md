# 01_architecture_and_tech_stack.md — Ledgify System Architecture & Monorepo Specification

## 1. Executive Summary & Product Objective
Ledgify is an AI-autonomous, mobile-first clone of TallyPrime designed for Indian Micro, Small, and Medium Enterprises (MSMEs). 
The core design eliminates manual data entry through a dual-intake interface (OCR bill/receipt scanning and Voice speech-to-voucher). 
The system extracts accounting entities via Google Gemini Multimodal APIs, parses them against a unified statutory JSON schema, executes fuzzy entity resolution on existing ledgers via PostgreSQL extensions, and atomically writes double-entry balanced vouchers to a multi-tenant database.

The product operates under strict free-tier architecture constraints for initial investor demonstrations (3–4 concurrent users) while maintaining a strict, zero-trust security model ready for production scale.

---

## 2. Technology Stack & Free-Tier Boundaries

| Component | Technology | Version / Configuration | Free-Tier Constraints & Strategy |
| :--- | :--- | :--- | :--- |
| **Mobile Client** | Flutter (Dart) | SDK ^3.x / Material Design 3 Expressive | Multi-device rendering, native audio capture, camera integration |
| **Identity & Auth** | Firebase Authentication | Google Identity Platform / Blocking Functions | Handles user login; injects `role: 'authenticated'` custom claim |
| **Database & API** | Supabase (PostgreSQL) | Postgres 15+ / PostgREST / GoTrue Disabled | Multi-tenant RLS; B-Tree & Trigram indexes; max 500MB DB pool |
| **Backend Compute** | Supabase Edge Functions | Deno TypeScript Runtime | Stateless execution for webhooks (Pub/Sub) and secure operations |
| **AI / Multimodal** | Google Gemini API | Free Tier (`gemini-2.5-flash` / `gemini-3.5-flash`) | Rate-limited (RPM/TPM/RPD); Exponential backoff + client queue |
| **Fuzzy Matching** | PostgreSQL Extensions | `pg_trgm`, `fuzzystrmatch` | Accelerated in-database trigram and phonetic entity resolution |
| **Local Cache** | SQLite (`sqflite` / `drift`) | Mobile Client Embedded | Offline draft storage, local master caching, and sync queue |
| **Monetization** | Google Play Billing | Play Billing Library v8+ | Subscriptions (`ProductType.SUBS`) + RTDN Cloud Pub/Sub webhooks |

---

## 3. End-to-End System Data Flow Architecture

[User Input: Camera OCR / Microphone Voice]│▼[Flutter Mobile Application]│(1) File Pre-check (<20MB Inline / >20MB Files API)(2) Rate-Limit Guard & Client Request Queue│▼[Google Gemini API]│(3) Multimodal Structured JSON Extraction (Unified Schema)│▼[Flutter Client-Side Validation]│(4) Semantic Schema Validation & Type Assertion(5) User Confirmation UI (M3 Card with Tap-to-Edit)│▼ (Authenticated Firebase JWT)[Supabase PostgreSQL Database]│(6) AS RESTRICTIVE Firebase Project ID Verification(7) Permissive RLS Tenant Isolation (business_id)(8) 2-Stage Entity Disambiguation (pg_trgm + fuzzystrmatch)(9) Atomic Transaction Orchestrator:├── Zero-Sum Double-Entry Trigger (Σ Debits = Σ Credits)├── Voucher & Line Items Creation├── Batch Tracking & Stock Movement├── GST E-Invoice / E-Way Bill Staging└── Audit Trail (edit_logs via SECURITY DEFINER)│▼[Local SQLite Cache Sync & Instant Visual/Haptic Feedback]
---

## 4. Monorepo Directory Layout

```text
ledgify/
├── .github/                      # CI/CD workflows and automated checks
├── docs/                        # Ground-truth architecture & specification documents
│   ├── 01_architecture_and_tech_stack.md
│   ├── 02_database_schema_ddl_and_indexes.md
│   ├── 03_security_auth_and_rls_matrix.md
│   ├── 04_core_accounting_engine_rules.md
│   ├── 05_gst_einvoice_and_ewaybill_spec.md
│   ├── 06_gemini_ai_multimodal_pipeline.md
│   ├── 07_fuzzy_entity_matching_spec.md
│   ├── 08_banking_brs_payroll_direct_tax.md
│   ├── 09_google_play_billing_rtdn_spec.md
│   ├── 10_ui_ux_design_system_tokens.md
│   ├── 11_dpdp_compliance_and_audit_spec.md
│   └── 12_coding_standards_and_env_config.md
├── client/                      # Flutter Mobile Application
│   ├── android/                 # Android native runner & Play Billing configuration
│   ├── ios/                     # iOS native runner
│   ├── assets/                  # Noto Sans Devanagari fonts, icons, branding
│   ├── lib/
│   │   ├── core/                # Core utilities, network clients, base themes
│   │   │   ├── constants/       # App-wide constants and statutory limits
│   │   │   ├── network/         # Supabase client wrapper & Gemini API client
│   │   │   ├── theme/           # Material 3 Expressive theme & Typography tokens
│   │   │   └── utils/           # Formatters (INR, Date), Logger, Audio recorder
│   │   ├── features/            # Feature-first modular architecture
│   │   │   ├── auth/            # Firebase Google sign-in & JWT management
│   │   │   ├── dashboard/       # MSME home dashboard, quick stats, navigation
│   │   │   ├── ai_intake/       # Camera OCR, Audio voice recorder, Confirmation card
│   │   │   ├── vouchers/        # Voucher creation, listing, detail view, filtering
│   │   │   ├── masters/         # Accounts/Ledgers, Stock Items, Godowns, Batches
│   │   │   ├── gst_compliance/  # E-Invoice logs, E-Way Bill generation, GSTR reports
│   │   │   ├── banking/         # Bank statement upload, BRS matching engine
│   │   │   ├── payroll/         # Employee profiles, salary vouchers, Form 16/24Q
│   │   │   └── settings/        # Company profiles, DPDP privacy center, Subscriptions
│   │   └── main.dart            # Application entry point & dependency injection
│   └── pubspec.yaml             # Flutter dependencies and asset registrations
├── supabase/                    # Supabase Infrastructure & Database Configuration
│   ├── config.toml              # Third-party Firebase Auth trust configuration
│   ├── migrations/              # Sequential SQL migration files
│   │   ├── 20260831000001_initial_schema.sql
│   │   ├── 20260831000002_indexes_and_extensions.sql
│   │   ├── 20260831000003_rls_policies_and_guards.sql
│   │   ├── 20260831000004_accounting_triggers.sql
│   │   └── 20260831000005_fuzzy_matching_functions.sql
│   ├── functions/               # Deno Supabase Edge Functions
│   │   ├── play-billing-rtdn/   # Google Cloud Pub/Sub webhook receiver
│   │   └── verify-purchase/     # Server-side purchase verification via Play API
│   └── seed.sql                 # Default 28 Tally groups & statutory GST rate slabs
├── firebase/                    # Firebase Configuration & Identity Functions
│   ├── functions/               # Blocking Auth Functions (beforeUserCreated/SignedIn)
│   └── firebase.json            # Firebase project configuration
└── README.md                    # Repository setup and execution guide
5. Architectural Principles & ConstraintsStrict Dependency Order: No phase or module may be implemented before its underlying schema and security layer are verified and committed.Zero-Trust Multi-Tenancy: The mobile client never specifies permissions or bypasses tenant boundaries. Every query evaluates business_id from the cryptographically verified JWT claim.Double-Entry Invariant: No financial record can enter the system without strict equality:$$\sum \text{Debits} = \sum \text{Credits}$$This is validated at the database level via transaction triggers, regardless of AI extraction output.Deterministic AI Boundaries: The Gemini API is strictly an extraction and structuring engine. Business logic, tax calculations, accounting classification, and entity linking are validated by deterministic Postgres rules and Dart algorithms.DPDP Act 2023 Compliance: Explicit multilingual consent notices are served before processing document data on free tiers, with automated data erasure workflows honoring the 72-month CGST Act statutory books retention floor.