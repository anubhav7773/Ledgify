-- ==============================================================================
-- Migration: 20260831000021_subscriptions_and_entitlements.sql
-- Description: Google Play Billing 7.0+ Subscriptions, Entitlement State Machine & Feature Gates
-- Specification: docs/09_monetization_play_billing_and_admob.md & docs/02_database_schema_ddl_and_indexes.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Extend user_subscriptions with Tier and Period Attributes
-- ------------------------------------------------------------------------------
ALTER TABLE public.user_subscriptions
ADD COLUMN IF NOT EXISTS tier VARCHAR(20) DEFAULT 'PRO' CHECK (tier IN ('FREE', 'PRO', 'ENTERPRISE')),
ADD COLUMN IF NOT EXISTS current_period_start TIMESTAMPTZ DEFAULT clock_timestamp(),
ADD COLUMN IF NOT EXISTS current_period_end TIMESTAMPTZ;

-- Backfill current_period_end from expiry_time where null
UPDATE public.user_subscriptions
SET current_period_end = expiry_time
WHERE current_period_end IS NULL AND expiry_time IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_status ON public.user_subscriptions(user_id, status);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_token ON public.user_subscriptions(purchase_token);

-- ------------------------------------------------------------------------------
-- 2. User Entitlement Evaluation Stored Function
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_entitlement(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_sub RECORD;
    v_tier VARCHAR(20) := 'FREE';
    v_has_active BOOLEAN := FALSE;
    v_is_grace_period BOOLEAN := FALSE;
    v_max_ai_scans INT := 30;
    v_multi_business BOOLEAN := FALSE;
    v_einvoice_enabled BOOLEAN := FALSE;
    v_period_end TIMESTAMPTZ;
BEGIN
    SELECT * INTO v_sub
    FROM public.user_subscriptions
    WHERE user_id = p_user_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_sub IS NOT NULL THEN
        v_period_end := COALESCE(v_sub.current_period_end, v_sub.expiry_time);

        -- Active subscription check (ACTIVE or IN_GRACE_PERIOD within expiry)
        IF v_sub.status = 'ACTIVE' AND (v_period_end IS NULL OR v_period_end > clock_timestamp()) THEN
            v_has_active := TRUE;
            v_tier := COALESCE(v_sub.tier, 'PRO');
        ELSIF v_sub.status = 'IN_GRACE_PERIOD' THEN
            v_has_active := TRUE;
            v_is_grace_period := TRUE;
            v_tier := COALESCE(v_sub.tier, 'PRO');
        END IF;
    END IF;

    -- Compute Tier Capabilities
    IF v_tier = 'ENTERPRISE' THEN
        v_max_ai_scans := -1; -- Unlimited
        v_multi_business := TRUE;
        v_einvoice_enabled := TRUE;
    ELSIF v_tier = 'PRO' THEN
        v_max_ai_scans := 500;
        v_multi_business := FALSE;
        v_einvoice_enabled := TRUE;
    ELSE
        v_tier := 'FREE';
        v_max_ai_scans := 30;
        v_multi_business := FALSE;
        v_einvoice_enabled := FALSE;
    END IF;

    RETURN jsonb_build_object(
        'user_id', p_user_id,
        'tier', v_tier,
        'has_active_subscription', v_has_active,
        'is_in_grace_period', v_is_grace_period,
        'current_period_end', v_period_end,
        'max_ai_scans_per_month', v_max_ai_scans,
        'is_multi_business_enabled', v_multi_business,
        'is_e_invoice_enabled', v_einvoice_enabled
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. Record / Activate Client Purchase Stored Procedure
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_subscription_purchase(
    p_user_id UUID,
    p_product_id VARCHAR(100),
    p_purchase_token TEXT,
    p_order_id VARCHAR(100),
    p_tier VARCHAR(20)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_end_time TIMESTAMPTZ;
    v_sub_id UUID;
BEGIN
    -- Determine period end date based on monthly vs annual plan
    IF p_product_id ILIKE '%annual%' OR p_product_id ILIKE '%year%' THEN
        v_end_time := clock_timestamp() + INTERVAL '365 days';
    ELSE
        v_end_time := clock_timestamp() + INTERVAL '30 days';
    END IF;

    INSERT INTO public.user_subscriptions (
        user_id, product_id, purchase_token, order_id, tier,
        status, current_period_start, current_period_end, expiry_time, auto_renewing
    ) VALUES (
        p_user_id, p_product_id, p_purchase_token, p_order_id, p_tier,
        'ACTIVE', clock_timestamp(), v_end_time, v_end_time, TRUE
    )
    ON CONFLICT (purchase_token) DO UPDATE SET
        status = 'ACTIVE',
        tier = p_tier,
        current_period_end = v_end_time,
        expiry_time = v_end_time,
        updated_at = clock_timestamp()
    RETURNING id INTO v_sub_id;

    RETURN public.get_user_entitlement(p_user_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_entitlement(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_subscription_purchase(UUID, VARCHAR, TEXT, VARCHAR, VARCHAR) TO authenticated;

COMMIT;
