# 03_security_auth_and_rls_matrix.md — Security Architecture, Firebase-Supabase Auth Bridge & Row Level Security (RLS)

## 1. Security Architecture Overview
Ledgify implements a zero-trust multi-tenant isolation model combining Firebase Authentication (identity provider) with Supabase PostgreSQL (data store). 
Because Firebase Auth uses global signing keys across all Firebase projects, Ledgify enforces defense-in-depth security:
1. **Identity Assertion:** Firebase Blocking Functions enforce custom claims (`role: 'authenticated'`).
2. **Third-Party Auth Trust:** Supabase validates incoming Firebase JWT signatures and project identifiers.
3. **Two-Layer PostgreSQL Security:** Default public table access is revoked (`REVOKE ALL`), followed by explicit SQL permissions (`GRANT SELECT, INSERT, UPDATE, DELETE`).
4. **Mandatory Restrictive Guards (`AS RESTRICTIVE`):** Every table executes a global project validation check via logical `AND`.
5. **Permissive Tenant Isolation:** Multi-tenant scoping isolates data by evaluating `auth.jwt() -> 'app_metadata' ->> 'business_id'`.
6. **Statutory Audit Protection:** Audit logs (`edit_logs`) are read-only for tenant users and write-only via `SECURITY DEFINER` database triggers.

---

## 2. Firebase Blocking Functions & Custom Claims

To map Firebase authenticated users directly to PostgreSQL's `authenticated` role, Firebase Blocking Functions (`beforeUserCreated` and `beforeUserSignedIn`) attach custom claims prior to JWT issuance.

### `firebase/functions/src/index.ts`
```typescript
import { beforeUserCreated, beforeUserSignedIn } from "firebase-functions/v2/identity";

/**
 * Automatically injects the Supabase PostgreSQL role claim upon account creation.
 */
export const beforecreated = beforeUserCreated((event) => {
  return {
    customClaims: {
      role: "authenticated",
    },
  };
});

/**
 * Ensures the role claim is always present on token refresh and sign-in.
 */
export const beforesignedin = beforeUserSignedIn((event) => {
  return {
    customClaims: {
      role: "authenticated",
    },
  };
});
Note: On initial sign-up, the Flutter mobile client must call getIdToken(true) to force-refresh and receive the claim immediately.

3. Supabase Third-Party Auth Configuration
Supabase is configured to accept and verify Firebase JWTs directly.

supabase/config.toml
Ini, TOML
[auth.third_party.firebase]
enabled = true
project_id = "YOUR_FIREBASE_PROJECT_ID"
4. Frontend Client Dynamic Token Injection
The Flutter mobile client passes the active Firebase ID token dynamically on every Supabase request without manual authorization headers.

client/lib/core/network/supabase_client.dart
Dart
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientService {
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      accessToken: () async {
        final user = fb_auth.FirebaseAuth.instance.currentUser;
        if (user != null) {
          return await user.getIdToken(false);
        }
        return null;
      },
    );
  }
}
5. Defense-in-Depth Restrictive Project Guard Function
To protect against cross-project Firebase JWT forgery, a PostgreSQL helper function validates the token issuer (iss) and audience (aud).

SQL
-- Helper function to validate Firebase Project ID inside PostgreSQL
CREATE OR REPLACE FUNCTION public.is_valid_project_jwt()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$   SELECT (     (auth.jwt() ->> 'iss' = '[https://securetoken.google.com/YOUR_FIREBASE_PROJECT_ID](https://securetoken.google.com/YOUR_FIREBASE_PROJECT_ID)'      AND auth.jwt() ->> 'aud' = 'YOUR_FIREBASE_PROJECT_ID')     OR     (auth.jwt() ->> 'iss' LIKE '\%supabase.co/auth/v1')   ); $$;
6. Comprehensive RLS Policy Matrix for All 22 Tables
6.1 Two-Layer Security & Restrictive Policy Pattern
Before defining policies, default public permissions are stripped and reapplied explicitly. Every table receives the AS RESTRICTIVE guard:

SQL
-- Pattern applied across all tables (Example: accounts)
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.accounts FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.accounts TO authenticated;

-- Restrictive Guard (Evaluated with logical AND against all permissive policies)
CREATE POLICY "project_guard_accounts"
ON public.accounts AS RESTRICTIVE
TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);
6.2 Complete RLS Policy Definitions
SQL
-- ============================================================================
-- 1. TENANTS / COMPANIES
-- ============================================================================
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.tenants FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.tenants TO authenticated;

CREATE POLICY "guard_tenants" ON public.tenants AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "tenant_select" ON public.tenants FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = id::text);

CREATE POLICY "tenant_insert" ON public.tenants FOR INSERT TO authenticated
WITH CHECK ((select auth.uid())::text = firebase_uid);

CREATE POLICY "tenant_update" ON public.tenants FOR UPDATE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = id::text);

CREATE POLICY "tenant_delete" ON public.tenants FOR DELETE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = id::text);

-- ============================================================================
-- 2. GST REGISTRATIONS
-- ============================================================================
ALTER TABLE public.gst_registrations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.gst_registrations FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.gst_registrations TO authenticated;

CREATE POLICY "guard_gst_reg" ON public.gst_registrations AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "gst_reg_select" ON public.gst_registrations FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "gst_reg_insert" ON public.gst_registrations FOR INSERT TO authenticated
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "gst_reg_update" ON public.gst_registrations FOR UPDATE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "gst_reg_delete" ON public.gst_registrations FOR DELETE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- ============================================================================
-- 3. ACCOUNTS / LEDGERS
-- ============================================================================
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.accounts FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.accounts TO authenticated;

CREATE POLICY "guard_accounts" ON public.accounts AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "accounts_select" ON public.accounts FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "accounts_insert" ON public.accounts FOR INSERT TO authenticated
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "accounts_update" ON public.accounts FOR UPDATE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "accounts_delete" ON public.accounts FOR DELETE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- ============================================================================
-- 4. VOUCHER TYPES (System Defaults + Tenant Custom)
-- ============================================================================
ALTER TABLE public.voucher_types ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.voucher_types FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.voucher_types TO authenticated;

CREATE POLICY "guard_voucher_types" ON public.voucher_types AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "voucher_types_select" ON public.voucher_types FOR SELECT TO authenticated
USING (
    is_system_default IS TRUE 
    OR (select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text
);

CREATE POLICY "voucher_types_insert" ON public.voucher_types FOR INSERT TO authenticated
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "voucher_types_update" ON public.voucher_types FOR UPDATE TO authenticated
USING (is_system_default IS FALSE AND (select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "voucher_types_delete" ON public.voucher_types FOR DELETE TO authenticated
USING (is_system_default IS FALSE AND (select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- ============================================================================
-- 5. VOUCHERS
-- ============================================================================
ALTER TABLE public.vouchers ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.vouchers FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vouchers TO authenticated;

CREATE POLICY "guard_vouchers" ON public.vouchers AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "vouchers_select" ON public.vouchers FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "vouchers_insert" ON public.vouchers FOR INSERT TO authenticated
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "vouchers_update" ON public.vouchers FOR UPDATE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "vouchers_delete" ON public.vouchers FOR DELETE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- ============================================================================
-- 6. VOUCHER LINE ITEMS
-- ============================================================================
ALTER TABLE public.voucher_line_items ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.voucher_line_items FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.voucher_line_items TO authenticated;

CREATE POLICY "guard_voucher_line_items" ON public.voucher_line_items AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "vli_select" ON public.voucher_line_items FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "vli_insert" ON public.voucher_line_items FOR INSERT TO authenticated
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "vli_update" ON public.voucher_line_items FOR UPDATE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "vli_delete" ON public.voucher_line_items FOR DELETE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- ============================================================================
-- 7. FIXED ASSETS
-- ============================================================================
ALTER TABLE public.fixed_assets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.fixed_assets FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.fixed_assets TO authenticated;

CREATE POLICY "guard_fixed_assets" ON public.fixed_assets AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "fa_select" ON public.fixed_assets FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "fa_insert" ON public.fixed_assets FOR INSERT TO authenticated
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "fa_update" ON public.fixed_assets FOR UPDATE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "fa_delete" ON public.fixed_assets FOR DELETE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- ============================================================================
-- 8. EINVOICE LOGS
-- ============================================================================
ALTER TABLE public.einvoice_logs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.einvoice_logs FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.einvoice_logs TO authenticated;

CREATE POLICY "guard_einvoice_logs" ON public.einvoice_logs AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "einv_select" ON public.einvoice_logs FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "einv_insert" ON public.einvoice_logs FOR INSERT TO authenticated
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "einv_update" ON public.einvoice_logs FOR UPDATE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "einv_delete" ON public.einvoice_logs FOR DELETE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- ============================================================================
-- 9. E-WAY BILLS
-- ============================================================================
ALTER TABLE public.eway_bills ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.eway_bills FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.eway_bills TO authenticated;

CREATE POLICY "guard_eway_bills" ON public.eway_bills AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "ewb_select" ON public.eway_bills FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "ewb_insert" ON public.eway_bills FOR INSERT TO authenticated
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "ewb_update" ON public.eway_bills FOR UPDATE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "ewb_delete" ON public.eway_bills FOR DELETE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- ============================================================================
-- 10. GSTR RETURNS & IMS
-- ============================================================================
ALTER TABLE public.gstr_returns_ims ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.gstr_returns_ims FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.gstr_returns_ims TO authenticated;

CREATE POLICY "guard_gstr_returns_ims" ON public.gstr_returns_ims AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "gstr_select" ON public.gstr_returns_ims FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "gstr_insert" ON public.gstr_returns_ims FOR INSERT TO authenticated
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "gstr_update" ON public.gstr_returns_ims FOR UPDATE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "gstr_delete" ON public.gstr_returns_ims FOR DELETE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- ============================================================================
-- 11. STOCK GROUPS & CATEGORIES
-- ============================================================================
ALTER TABLE public.stock_groups_categories ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.stock_groups_categories FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.stock_groups_categories TO authenticated;

CREATE POLICY "guard_sgc" ON public.stock_groups_categories AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "sgc_select" ON public.stock_groups_categories FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "sgc_insert" ON public.stock_groups_categories FOR INSERT TO authenticated
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "sgc_update" ON public.stock_groups_categories FOR UPDATE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "sgc_delete" ON public.stock_groups_categories FOR DELETE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- ============================================================================
-- 12. STOCK ITEMS
-- ============================================================================
ALTER TABLE public.stock_items ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.stock_items FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.stock_items TO authenticated;

CREATE POLICY "guard_stock_items" ON public.stock_items AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "si_select" ON public.stock_items FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "si_insert" ON public.stock_items FOR INSERT TO authenticated
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "si_update" ON public.stock_items FOR UPDATE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "si_delete" ON public.stock_items FOR DELETE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- ============================================================================
-- 13. GODOWNS / WAREHOUSES
-- ============================================================================
ALTER TABLE public.godowns ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.godowns FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.godowns TO authenticated;

CREATE POLICY "guard_godowns" ON public.godowns AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "godowns_select" ON public.godowns FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "godowns_insert" ON public.godowns FOR INSERT TO authenticated
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "godowns_update" ON public.godowns FOR UPDATE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "godowns_delete" ON public.godowns FOR DELETE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- ============================================================================
-- 14. STOCK BATCHES
-- ============================================================================
ALTER TABLE public.stock_batches ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.stock_batches FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.stock_batches TO authenticated;

CREATE POLICY "guard_stock_batches" ON public.stock_batches AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "batches_select" ON public.stock_batches FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "batches_insert" ON public.stock_batches FOR INSERT TO authenticated
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "batches_update" ON public.stock_batches FOR UPDATE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "batches_delete" ON public.stock_batches FOR DELETE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- ============================================================================
-- 15. BANK ACCOUNTS
-- ============================================================================
ALTER TABLE public.bank_accounts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.bank_accounts FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.bank_accounts TO authenticated;

CREATE POLICY "guard_bank_accounts" ON public.bank_accounts AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "ba_select" ON public.bank_accounts FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "ba_insert" ON public.bank_accounts FOR INSERT TO authenticated
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "ba_update" ON public.bank_accounts FOR UPDATE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "ba_delete" ON public.bank_accounts FOR DELETE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- ============================================================================
-- 16. BANK STATEMENTS & BRS
-- ============================================================================
ALTER TABLE public.bank_statements_brs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.bank_statements_brs FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.bank_statements_brs TO authenticated;

CREATE POLICY "guard_bank_statements" ON public.bank_statements_brs AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "bs_select" ON public.bank_statements_brs FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "bs_insert" ON public.bank_statements_brs FOR INSERT TO authenticated
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "bs_update" ON public.bank_statements_brs FOR UPDATE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "bs_delete" ON public.bank_statements_brs FOR DELETE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- ============================================================================
-- 17. EMPLOYEES & PAYROLL
-- ============================================================================
ALTER TABLE public.employees_payroll ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.employees_payroll FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.employees_payroll TO authenticated;

CREATE POLICY "guard_employees_payroll" ON public.employees_payroll AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "emp_select" ON public.employees_payroll FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "emp_insert" ON public.employees_payroll FOR INSERT TO authenticated
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "emp_update" ON public.employees_payroll FOR UPDATE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "emp_delete" ON public.employees_payroll FOR DELETE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- ============================================================================
-- 18. TDS & TCS ENTRIES
-- ============================================================================
ALTER TABLE public.tds_tcs_entries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.tds_tcs_entries FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.tds_tcs_entries TO authenticated;

CREATE POLICY "guard_tds_tcs" ON public.tds_tcs_entries AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "tds_select" ON public.tds_tcs_entries FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "tds_insert" ON public.tds_tcs_entries FOR INSERT TO authenticated
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "tds_update" ON public.tds_tcs_entries FOR UPDATE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

CREATE POLICY "tds_delete" ON public.tds_tcs_entries FOR DELETE TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- ============================================================================
-- 19. USER SUBSCRIPTIONS (User-Level Isolation)
-- ============================================================================
ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.user_subscriptions FROM anon, authenticated;
GRANT SELECT ON TABLE public.user_subscriptions TO authenticated;

CREATE POLICY "guard_user_subs" ON public.user_subscriptions AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "subs_select" ON public.user_subscriptions FOR SELECT TO authenticated
USING ((select auth.uid()) IS NOT NULL AND (select auth.uid()) = user_id);

-- Note: INSERT, UPDATE, DELETE are handled exclusively by backend Edge Functions via service_role.

-- ============================================================================
-- 20. BILLING WEBHOOK LOGS (System-Level Isolation)
-- ============================================================================
ALTER TABLE public.billing_webhook_logs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.billing_webhook_logs FROM anon, authenticated;

CREATE POLICY "guard_billing_logs" ON public.billing_webhook_logs AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

-- Accessible exclusively via service_role; no public or authenticated grants.

-- ============================================================================
-- 21. EDIT LOGS (Immutable Audit Trail)
-- ============================================================================
ALTER TABLE public.edit_logs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.edit_logs FROM anon, authenticated;
GRANT SELECT ON TABLE public.edit_logs TO authenticated;

CREATE POLICY "guard_edit_logs" ON public.edit_logs AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "edit_logs_select" ON public.edit_logs FOR SELECT TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

-- Note: INSERT is populated strictly via PostgreSQL SECURITY DEFINER triggers.

-- ============================================================================
-- 22. DPDP CONSENT LOGS (Data Principal Rights)
-- ============================================================================
ALTER TABLE public.dpdp_consent_logs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.dpdp_consent_logs FROM anon, authenticated;
GRANT SELECT, INSERT ON TABLE public.dpdp_consent_logs TO authenticated;

CREATE POLICY "guard_dpdp_consent" ON public.dpdp_consent_logs AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

CREATE POLICY "dpdp_select" ON public.dpdp_consent_logs FOR SELECT TO authenticated
USING ((select auth.uid()) IS NOT NULL AND (select auth.uid()) = user_id);

CREATE POLICY "dpdp_insert" ON public.dpdp_consent_logs FOR INSERT TO authenticated
WITH CHECK ((select auth.uid()) IS NOT NULL AND (select auth.uid()) = user_id);
7. Performance & Optimizer Guidelines
Statement-Level Caching (initPlan):
All JWT evaluations are wrapped in scalar subqueries (e.g., (select auth.jwt() -> 'app_metadata' ->> 'business_id')). This guarantees the query planner computes the JWT claim once per query rather than re-evaluating it per row.

Index Alignment:
Every multi-tenant table must feature a leading B-Tree index on business_id (defined in 02_database_schema_ddl_and_indexes.md) to ensure sequential row scans are avoided.