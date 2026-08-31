# Ledgify

**AI-Autonomous, Mobile-First Clone of TallyPrime for Indian MSMEs**

Ledgify eliminates manual data entry for Indian Micro, Small, and Medium Enterprises through an intelligent dual-intake interface (OCR bill scanning and Voice-to-voucher). Powered by Google Gemini Multimodal APIs, Supabase PostgreSQL with RLS, Firebase Authentication, and Google Play Billing.

---

## Monorepo Architecture

```text
ledgify/
├── docs/                        # Ground-truth architecture & technical specifications
├── client/                      # Flutter mobile application
│   ├── assets/                  # Noto Sans Devanagari fonts, icons
│   ├── lib/
│   │   ├── core/                # Tokens, themes, errors, safe execution, network
│   │   └── features/            # Feature modules (auth, dashboard, ai_intake, vouchers, etc.)
│   ├── .env.example             # Client environment configuration template
│   └── pubspec.yaml             # Flutter dependencies & font registrations
├── supabase/                    # Backend persistence & compute
│   ├── config.toml              # Third-party Firebase Auth trust configuration
│   ├── migrations/              # Database schema migrations
│   └── functions/               # Deno Edge Functions
│       ├── play-billing-rtdn/   # Google Cloud Pub/Sub RTDN webhook receiver
│       └── verify-purchase/     # Server-side purchase verification via Play API
└── firebase/                    # Firebase Identity & Blocking Functions
    ├── firebase.json            # Firebase project configuration
    └── functions/               # Blocking Auth Functions (beforeUserCreated / beforeUserSignedIn)
```

---

## Environment Setup

### 1. Flutter Client
Copy `client/.env.example` to `client/.env` and supply the required API keys:
```bash
cd client
cp .env.example .env
```

### 2. Supabase Local / Edge Functions
Ensure Deno is installed. Supabase Edge Functions use `supabase/functions/deno.json` for import mapping.

### 3. Firebase Blocking Functions
Install dependencies and build TypeScript functions:
```bash
cd firebase/functions
npm install
npm run build
```
