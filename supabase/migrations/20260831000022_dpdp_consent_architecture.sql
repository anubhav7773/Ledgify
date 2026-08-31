-- ==============================================================================
-- Migration: 20260831000022_dpdp_consent_architecture.sql
-- Description: Indian DPDP Act 2023 Statutory Consent Logging, Cryptographic Notice Hashing & Immutability Triggers
-- Specification: docs/11_dpdp_compliance_and_audit_spec.md & docs/02_database_schema_ddl_and_indexes.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Rebuild or Extend dpdp_consent_logs with Statutory Mandates
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS public.dpdp_consent_logs CASCADE;

CREATE TABLE public.dpdp_consent_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL, -- Auth / Firebase UID
    purpose VARCHAR(50) NOT NULL CHECK (
        purpose IN (
            'FINANCIAL_OCR_EXTRACTION',
            'VOICE_VOUCHER_PROCESSING',
            'CONNECTED_BANKING_SYNC',
            'GOVERNMENT_PORTAL_SYNC',
            'TELEMETRY_ANALYTICS'
        )
    ),
    consent_status VARCHAR(20) NOT NULL CHECK (consent_status IN ('GRANTED', 'REVOKED', 'EXPIRED')),
    consent_version VARCHAR(20) NOT NULL DEFAULT 'v1.0',
    ip_address VARCHAR(45),
    user_agent TEXT,
    consent_payload_hash VARCHAR(64) NOT NULL, -- SHA-256 fingerprint of agreed statutory notice text
    granted_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

CREATE INDEX idx_dpdp_consent_lookup 
ON public.dpdp_consent_logs(business_id, user_id, purpose, consent_status);

CREATE INDEX idx_dpdp_consent_granted_at 
ON public.dpdp_consent_logs(granted_at DESC);

-- ------------------------------------------------------------------------------
-- 2. Append-Only Immutability Trigger
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_dpdp_log_immutability()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'DPDP Audit Violation: Consent logs are strictly append-only and cannot be deleted.';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF OLD.consent_status = 'REVOKED' THEN
            RAISE EXCEPTION 'DPDP Audit Violation: Revoked consent logs cannot be modified.';
        END IF;

        IF NEW.consent_status <> 'REVOKED' OR NEW.user_id <> OLD.user_id OR NEW.purpose <> OLD.purpose THEN
            RAISE EXCEPTION 'DPDP Audit Violation: Only revocation state transitions are permitted.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_dpdp_consent_immutability ON public.dpdp_consent_logs;
CREATE TRIGGER trg_dpdp_consent_immutability
BEFORE UPDATE OR DELETE ON public.dpdp_consent_logs
FOR EACH ROW EXECUTE FUNCTION public.enforce_dpdp_log_immutability();

-- ------------------------------------------------------------------------------
-- 3. Check Active DPDP Consent Stored Procedure
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.has_active_dpdp_consent(
    p_business_id UUID,
    p_user_id TEXT,
    p_purpose VARCHAR(50)
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_has_active BOOLEAN := FALSE;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM public.dpdp_consent_logs
        WHERE (business_id = p_business_id OR business_id IS NULL)
          AND user_id = p_user_id
          AND purpose = p_purpose
          AND consent_status = 'GRANTED'
          AND revoked_at IS NULL
    ) INTO v_has_active;

    RETURN v_has_active;
END;
$$;

-- ------------------------------------------------------------------------------
-- 4. Record or Revoke Consent Stored Procedure
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_dpdp_consent(
    p_business_id UUID,
    p_user_id TEXT,
    p_purpose VARCHAR(50),
    p_status VARCHAR(20),
    p_version VARCHAR(20),
    p_payload_hash VARCHAR(64),
    p_ip VARCHAR(45),
    p_user_agent TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_id UUID;
BEGIN
    -- If granting, revoke any prior active consent records for this exact purpose
    IF p_status = 'GRANTED' THEN
        UPDATE public.dpdp_consent_logs
        SET consent_status = 'REVOKED',
            revoked_at = clock_timestamp()
        WHERE (business_id = p_business_id OR business_id IS NULL)
          AND user_id = p_user_id
          AND purpose = p_purpose
          AND consent_status = 'GRANTED'
          AND revoked_at IS NULL;
    ELSIF p_status = 'REVOKED' THEN
        UPDATE public.dpdp_consent_logs
        SET consent_status = 'REVOKED',
            revoked_at = clock_timestamp()
        WHERE (business_id = p_business_id OR business_id IS NULL)
          AND user_id = p_user_id
          AND purpose = p_purpose
          AND consent_status = 'GRANTED'
          AND revoked_at IS NULL;
    END IF;

    -- Append new immutable audit record
    INSERT INTO public.dpdp_consent_logs (
        business_id,
        user_id,
        purpose,
        consent_status,
        consent_version,
        consent_payload_hash,
        ip_address,
        user_agent,
        granted_at,
        revoked_at
    ) VALUES (
        p_business_id,
        p_user_id,
        p_purpose,
        p_status,
        COALESCE(p_version, 'v1.0'),
        p_payload_hash,
        p_ip,
        p_user_agent,
        clock_timestamp(),
        CASE WHEN p_status = 'REVOKED' THEN clock_timestamp() ELSE NULL END
    )
    RETURNING id INTO v_new_id;

    RETURN v_new_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.has_active_dpdp_consent(UUID, TEXT, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_dpdp_consent(UUID, TEXT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT) TO authenticated;

COMMIT;
