-- ==============================================================================
-- Migration: 20260831000009_einvoice_pipeline.sql
-- Description: E-Invoice Storage Procedures, IRP Handshake & Voucher Validation Engine
-- Specification: docs/05_gst_einvoice_and_ewaybill_spec.md & docs/02_database_schema_ddl_and_indexes.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. IRP Response Storage Stored Procedure
-- Commits IRP signed invoice, QR code, and IRN hash atomically to logs & voucher
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_einvoice_irp_response(
    p_business_id UUID,
    p_voucher_id UUID,
    p_irn VARCHAR(64),
    p_ack_no VARCHAR(50),
    p_ack_date TIMESTAMPTZ,
    p_signed_invoice TEXT,
    p_signed_qr_code TEXT,
    p_payload_json JSONB,
    p_irp_response JSONB,
    p_status VARCHAR(50) DEFAULT 'SUCCESS'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_log_id UUID;
BEGIN
    -- 1. Insert detailed audit record in einvoice_logs
    INSERT INTO public.einvoice_logs (
        business_id,
        voucher_id,
        irn,
        ack_no,
        ack_date,
        signed_invoice,
        signed_qr_code,
        payload_json,
        irp_response,
        status
    )
    VALUES (
        p_business_id,
        p_voucher_id,
        p_irn,
        p_ack_no,
        p_ack_date,
        p_signed_invoice,
        p_signed_qr_code,
        p_payload_json,
        p_irp_response,
        p_status
    )
    RETURNING id INTO v_log_id;

    -- 2. Update Voucher Header with IRN tracking properties
    UPDATE public.vouchers
    SET 
        irn = p_irn,
        qr_code = p_signed_qr_code,
        ack_no = p_ack_no,
        ack_date = p_ack_date,
        updated_at = clock_timestamp()
    WHERE id = p_voucher_id;

    RETURN v_log_id;
END;
$$;

-- ------------------------------------------------------------------------------
-- 2. E-Invoice Eligibility & Statutory Validation Function
-- Validates statutory invoice length, regex constraints, and mandatory HSN codes
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_voucher_for_einvoice(p_voucher_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_voucher RECORD;
    v_errors TEXT[] := ARRAY[]::TEXT[];
    v_line RECORD;
    v_line_count INTEGER := 0;
BEGIN
    -- 1. Fetch Voucher Header
    SELECT 
        v.id,
        v.business_id,
        v.voucher_number,
        v.voucher_date,
        v.is_cancelled,
        vt.category
    INTO v_voucher
    FROM public.vouchers v
    JOIN public.voucher_types vt ON vt.id = v.voucher_type_id
    WHERE v.id = p_voucher_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('is_valid', FALSE, 'errors', ARRAY['Voucher not found']);
    END IF;

    -- Document Type Check (Only Sales, Debit Note, Credit Note eligible for e-invoicing)
    IF v_voucher.category NOT IN ('Sales', 'Credit Note', 'Debit Note') THEN
        v_errors := array_append(v_errors, 'Voucher category ' || v_voucher.category || ' is not eligible for E-Invoicing (only Sales, Credit Note, Debit Note)');
    END IF;

    -- Cancelled Voucher Check
    IF v_voucher.is_cancelled IS TRUE THEN
        v_errors := array_append(v_errors, 'Cancelled vouchers cannot be submitted for E-Invoicing');
    END IF;

    -- Document Number Length (Max 16 characters for FORM GST INV-01)
    IF LENGTH(v_voucher.voucher_number) > 16 THEN
        v_errors := array_append(v_errors, 'Document number exceeds statutory 16-character limit: ' || v_voucher.voucher_number);
    END IF;

    -- Document Number Regex Check (^[a-zA-Z0-9/-]+$)
    IF v_voucher.voucher_number !~ '^[a-zA-Z0-9/-]+$' THEN
        v_errors := array_append(v_errors, 'Document number contains invalid characters (allowed: alphanumeric, hyphen, slash)');
    END IF;

    -- 2. Check Line Items
    FOR v_line IN
        SELECT 
            vli.id,
            vli.amount,
            vli.entry_type,
            COALESCE(si.hsn_sac_code, a.hsn_sac_code) as hsn_code
        FROM public.voucher_line_items vli
        LEFT JOIN public.stock_items si ON si.id = vli.stock_item_id
        LEFT JOIN public.accounts a ON a.id = vli.account_id
        WHERE vli.voucher_id = p_voucher_id
    LOOP
        v_line_count := v_line_count + 1;
        
        -- HSN/SAC code check on product/item rows
        IF v_line.hsn_code IS NOT NULL AND LENGTH(v_line.hsn_code) < 4 THEN
            v_errors := array_append(v_errors, 'HSN/SAC code must be at least 4 digits for line item ' || v_line.id);
        END IF;
    END LOOP;

    IF v_line_count < 2 THEN
        v_errors := array_append(v_errors, 'Voucher must have at least 2 line items for double-entry');
    END IF;

    RETURN jsonb_build_object(
        'is_valid', (array_length(v_errors, 1) IS NULL),
        'errors', to_jsonb(v_errors)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_einvoice_irp_response(UUID, UUID, VARCHAR, VARCHAR, TIMESTAMPTZ, TEXT, TEXT, JSONB, JSONB, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_voucher_for_einvoice(UUID) TO authenticated;

COMMIT;
