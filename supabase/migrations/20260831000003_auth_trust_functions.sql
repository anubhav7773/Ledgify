-- ==============================================================================
-- Migration: 20260831000003_auth_trust_functions.sql
-- Description: Supabase-Firebase Third-Party Auth Trust & JWT Verification Functions
-- Specification: docs/03_security_auth_and_rls_matrix.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Helper function to validate Firebase Project ID inside PostgreSQL
-- Defends against cross-project Firebase JWT forgery by verifying issuer and audience
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_valid_project_jwt()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT (
        (
            auth.jwt() ->> 'iss' IN (
                'https://securetoken.google.com/ledgify-9ac70',
                'https://securetoken.google.com/ledgify-prod'
            )
            AND auth.jwt() ->> 'aud' IN ('ledgify-9ac70', 'ledgify-prod')
        )
        OR
        (
            auth.jwt() ->> 'iss' LIKE '%supabase.co/auth/v1'
        )
    );
$$;

-- ------------------------------------------------------------------------------
-- 2. Helper function to extract active tenant business_id from JWT claims
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_current_business_id()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(auth.jwt() -> 'app_metadata' ->> 'business_id', '')::UUID;
$$;

-- ------------------------------------------------------------------------------
-- 3. Helper function to extract Firebase UID from JWT
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_current_firebase_uid()
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        auth.jwt() ->> 'sub',
        (auth.uid())::text
    );
$$;

-- ------------------------------------------------------------------------------
-- 4. Grant Execution Permissions to Authenticated & Anon Roles
-- ------------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.is_valid_project_jwt() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_current_business_id() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_current_firebase_uid() TO authenticated, anon;

COMMIT;
