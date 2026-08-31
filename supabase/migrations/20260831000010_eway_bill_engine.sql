-- ==============================================================================
-- Migration: 20260831000010_eway_bill_engine.sql
-- Description: E-Way Bill Generation, Rule 138(10) Validity Engine & Threshold Triggers
-- Specification: docs/05_gst_einvoice_and_ewaybill_spec.md & docs/02_database_schema_ddl_and_indexes.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. E-Way Bill Record Creation & Voucher Synchronization Procedure
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_eway_bill_record(
    p_business_id UUID,
    p_voucher_id UUID,
    p_ewb_number VARCHAR(20),
    p_transporter_party_id UUID,
    p_vehicle_number VARCHAR(50),
    p_distance_km NUMERIC(8, 2),
    p_part_a_data JSONB,
    p_part_b_data JSONB,
    p_is_odc BOOLEAN DEFAULT FALSE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_validity_days INTEGER;
    v_valid_upto TIMESTAMPTZ;
    v_ewb_id UUID;
BEGIN
    -- 1. Calculate statutory validity under Rule 138(10)
    -- Standard Cargo: 1 Day per 200 km; Over Dimensional Cargo: 1 Day per 20 km
    v_validity_days := public.calculate_ewb_validity_days(p_distance_km, p_is_odc);
    v_valid_upto := clock_timestamp() + (v_validity_days || ' days')::INTERVAL;

    -- 2. Insert E-Way Bill record
    INSERT INTO public.eway_bills (
        business_id,
        voucher_id,
        ewb_number,
        ewb_date,
        valid_upto,
        transporter_party_id,
        vehicle_number,
        distance_km,
        part_a_data,
        part_b_data,
        status
    )
    VALUES (
        p_business_id,
        p_voucher_id,
        p_ewb_number,
        clock_timestamp(),
        v_valid_upto,
        p_transporter_party_id,
        p_vehicle_number,
        p_distance_km,
        p_part_a_data,
        p_part_b_data,
        'ACTIVE'
    )
    RETURNING id INTO v_ewb_id;

    -- 3. Synchronize Voucher Header with EWB Number
    UPDATE public.vouchers
    SET 
        e_way_bill_no = p_ewb_number,
        updated_at = clock_timestamp()
    WHERE id = p_voucher_id;

    RETURN v_ewb_id;
END;
$$;

-- ------------------------------------------------------------------------------
-- 2. E-Way Bill Requirement Checker Function
-- Validates statutory ₹50,000 threshold and mandatory inter-state job work rules
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_voucher_ewb_requirement(p_voucher_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total_amount NUMERIC(15, 2) := 0.00;
    v_category VARCHAR(50);
    v_is_required BOOLEAN := FALSE;
    v_reason TEXT := 'Consignment value is under statutory ₹50,000 threshold';
BEGIN
    -- 1. Determine voucher type category
    SELECT vt.category
    INTO v_category
    FROM public.vouchers v
    JOIN public.voucher_types vt ON vt.id = v.voucher_type_id
    WHERE v.id = p_voucher_id;

    -- 2. Calculate Total Consignment Value (sum of credit lines for Sales)
    SELECT COALESCE(SUM(amount + cgst_amt + sgst_amt + igst_amt + cess_amt), 0.00)
    INTO v_total_amount
    FROM public.voucher_line_items
    WHERE voucher_id = p_voucher_id
      AND entry_type = 'Cr';

    -- Statutory ₹50,000 Consignment Threshold Check
    IF v_total_amount > 50000.00 THEN
        v_is_required := TRUE;
        v_reason := 'Consignment total amount (₹' || v_total_amount || ') exceeds mandatory ₹50,000 threshold';
    END IF;

    RETURN jsonb_build_object(
        'is_required', v_is_required,
        'total_amount', v_total_amount,
        'category', v_category,
        'reason', v_reason
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_eway_bill_record(UUID, UUID, VARCHAR, UUID, VARCHAR, NUMERIC, JSONB, JSONB, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_voucher_ewb_requirement(UUID) TO authenticated;

COMMIT;
