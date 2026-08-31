-- ==============================================================================
-- Migration: 20260831000006_voucher_engine_triggers.sql
-- Description: Double-Entry Voucher Engine, Zero-Sum Trigger & Atomic Stored Procedures
-- Specification: docs/04_core_accounting_engine_rules.md & docs/02_database_schema_ddl_and_indexes.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Zero-Sum Balancing Constraint Trigger Function
-- Validates: \sum Debits = \sum Credits across line items for any committed voucher
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_voucher_zero_sum()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    total_debits NUMERIC(15, 2) := 0.00;
    total_credits NUMERIC(15, 2) := 0.00;
    target_voucher_id UUID;
BEGIN
    target_voucher_id := COALESCE(NEW.voucher_id, OLD.voucher_id);

    -- Calculate total debits and credits for the target voucher
    SELECT 
        COALESCE(SUM(CASE WHEN entry_type = 'Dr' THEN amount ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN entry_type = 'Cr' THEN amount ELSE 0 END), 0.00)
    INTO total_debits, total_credits
    FROM public.voucher_line_items
    WHERE voucher_id = target_voucher_id;

    -- Enforce absolute mathematical equality (2-decimal precision)
    IF total_debits <> total_credits THEN
        RAISE EXCEPTION 'Double-entry balancing violation: Total Debits (₹%) must equal Total Credits (₹%) for voucher %', 
            total_debits, total_credits, target_voucher_id
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_voucher_zero_sum ON public.voucher_line_items;
CREATE CONSTRAINT TRIGGER trg_enforce_voucher_zero_sum
AFTER INSERT OR UPDATE OR DELETE ON public.voucher_line_items
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validate_voucher_zero_sum();

-- ------------------------------------------------------------------------------
-- 2. Original Voucher Number Retention Trigger
-- Preserves immutable initial voucher numbering during alterations or cancellations
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.preserve_original_voucher_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.original_voucher_number IS NULL OR NEW.original_voucher_number = '' THEN
            NEW.original_voucher_number := NEW.voucher_number;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Retain original voucher number even if voucher_number is modified
        NEW.original_voucher_number := OLD.original_voucher_number;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_preserve_original_voucher_number ON public.vouchers;
CREATE TRIGGER trg_preserve_original_voucher_number
BEFORE INSERT OR UPDATE ON public.vouchers
FOR EACH ROW
EXECUTE FUNCTION public.preserve_original_voucher_number();

-- ------------------------------------------------------------------------------
-- 3. Statutory Books Retention Enforcement (CGST Act Section 36)
-- Prohibits hard-deletion of vouchers within the 72-month statutory retention window
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.prevent_early_voucher_deletion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_age_months INTEGER;
BEGIN
    v_age_months := (DATE_PART('year', CURRENT_DATE) - DATE_PART('year', OLD.voucher_date)) * 12 +
                    (DATE_PART('month', CURRENT_DATE) - DATE_PART('month', OLD.voucher_date));

    IF v_age_months < 72 THEN
        RAISE EXCEPTION 'Statutory Retention Violation (CGST Sec 36): Cannot hard-delete voucher % within 72 months of creation.', 
            OLD.voucher_number
            USING ERRCODE = 'integrity_constraint_violation';
    END IF;

    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_voucher_retention ON public.vouchers;
CREATE TRIGGER trg_protect_voucher_retention
BEFORE DELETE ON public.vouchers
FOR EACH ROW
EXECUTE FUNCTION public.prevent_early_voucher_deletion();

-- ------------------------------------------------------------------------------
-- 4. Atomic Voucher Creation Stored Procedure
-- Atomically writes voucher header and all debit/credit line items
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.post_double_entry_voucher(p_voucher_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_business_id UUID;
    v_voucher_type_id UUID;
    v_voucher_number VARCHAR(50);
    v_voucher_date DATE;
    v_narration TEXT;
    v_reference_number VARCHAR(100);
    v_reference_date DATE;
    v_ai_confidence_score NUMERIC(5, 4);
    v_new_voucher_id UUID;
    v_line_items JSONB;
    v_item JSONB;
    v_line_count INTEGER;
BEGIN
    -- Extract header properties
    v_business_id := (p_voucher_payload->>'business_id')::UUID;
    v_voucher_type_id := (p_voucher_payload->>'voucher_type_id')::UUID;
    v_voucher_number := p_voucher_payload->>'voucher_number';
    v_voucher_date := (p_voucher_payload->>'voucher_date')::DATE;
    v_narration := p_voucher_payload->>'narration';
    v_reference_number := p_voucher_payload->>'reference_number';
    IF p_voucher_payload->>'reference_date' IS NOT NULL AND p_voucher_payload->>'reference_date' <> '' THEN
        v_reference_date := (p_voucher_payload->>'reference_date')::DATE;
    END IF;
    v_ai_confidence_score := (p_voucher_payload->>'ai_confidence_score')::NUMERIC;
    v_line_items := p_voucher_payload->'line_items';

    -- Validate minimum double-entry requirements (at least 2 line items)
    v_line_count := jsonb_array_length(v_line_items);
    IF v_line_count < 2 THEN
        RAISE EXCEPTION 'Double-entry violation: A voucher must contain at least 2 line items (received %)', v_line_count
            USING ERRCODE = 'check_violation';
    END IF;

    -- 1. Insert Voucher Header
    INSERT INTO public.vouchers (
        business_id,
        voucher_type_id,
        voucher_number,
        voucher_date,
        narration,
        reference_number,
        reference_date,
        ai_confidence_score
    )
    VALUES (
        v_business_id,
        v_voucher_type_id,
        v_voucher_number,
        v_voucher_date,
        v_narration,
        v_reference_number,
        v_reference_date,
        v_ai_confidence_score
    )
    RETURNING id INTO v_new_voucher_id;

    -- 2. Insert all Line Items
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_line_items)
    LOOP
        INSERT INTO public.voucher_line_items (
            business_id,
            voucher_id,
            account_id,
            entry_type,
            amount,
            item_description,
            stock_item_id,
            godown_id,
            batch_id,
            cgst_amt,
            sgst_amt,
            igst_amt,
            cess_amt
        )
        VALUES (
            v_business_id,
            v_new_voucher_id,
            (v_item->>'account_id')::UUID,
            v_item->>'entry_type',
            (v_item->>'amount')::NUMERIC(15, 2),
            v_item->>'item_description',
            NULLIF(v_item->>'stock_item_id', '')::UUID,
            NULLIF(v_item->>'godown_id', '')::UUID,
            NULLIF(v_item->>'batch_id', '')::UUID,
            COALESCE((v_item->>'cgst_amt')::NUMERIC(15, 2), 0.00),
            COALESCE((v_item->>'sgst_amt')::NUMERIC(15, 2), 0.00),
            COALESCE((v_item->>'igst_amt')::NUMERIC(15, 2), 0.00),
            COALESCE((v_item->>'cess_amt')::NUMERIC(15, 2), 0.00)
        );
    END LOOP;

    -- The deferred zero-sum trigger `trg_enforce_voucher_zero_sum` will evaluate on transaction completion
    RETURN jsonb_build_object(
        'status', 'SUCCESS',
        'voucher_id', v_new_voucher_id,
        'voucher_number', v_voucher_number
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.post_double_entry_voucher(JSONB) TO authenticated;

COMMIT;
