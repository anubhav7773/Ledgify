-- ==============================================================================
-- Migration: 20260831000008_gst_tax_engine.sql
-- Description: Indian GST Tax Calculation Engine, POS Rules & E-Way Bill Validity Stored Procedures
-- Specification: docs/05_gst_einvoice_and_ewaybill_spec.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Composite Type for GST Tax Split Results
-- ------------------------------------------------------------------------------
DO $$ BEGIN
    CREATE TYPE public.gst_tax_split_type AS (
        cgst_amt NUMERIC(15, 2),
        sgst_amt NUMERIC(15, 2),
        igst_amt NUMERIC(15, 2),
        cess_amt NUMERIC(15, 2),
        total_tax NUMERIC(15, 2),
        total_amount NUMERIC(15, 2)
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- ------------------------------------------------------------------------------
-- 2. Core GST Split Calculation Function
-- Determines Intra-State (CGST + SGST) vs Inter-State (IGST) according to POS rules
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.compute_gst_split(
    p_supplier_state_code INTEGER,
    p_pos_state_code INTEGER,
    p_taxable_value NUMERIC(15, 2),
    p_gst_rate NUMERIC(5, 2),
    p_supply_category VARCHAR(10) DEFAULT 'B2B'
)
RETURNS public.gst_tax_split_type
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_result public.gst_tax_split_type;
    v_is_inter_state BOOLEAN;
    v_half_rate NUMERIC(5, 3);
BEGIN
    -- Statutory GST Rate Validation
    IF p_gst_rate NOT IN (0.0, 0.1, 0.25, 3.0, 5.0, 12.0, 18.0, 28.0) THEN
        RAISE EXCEPTION 'Invalid GST rate slab: %%%. Allowed rates: 0, 0.1, 0.25, 3, 5, 12, 18, 28', p_gst_rate
            USING ERRCODE = 'check_violation';
    END IF;

    -- POS Determination: Inter-state if states differ OR supply is export/SEZ
    v_is_inter_state := (p_supplier_state_code <> p_pos_state_code)
                     OR p_supply_category IN ('EXPWP', 'SEZWP', 'DEXP');

    v_result.cess_amt := 0.00;

    IF v_is_inter_state THEN
        -- Inter-State Supply: 100% of GST rate to IGST
        v_result.igst_amt := ROUND((p_taxable_value * (p_gst_rate / 100.0)), 2);
        v_result.cgst_amt := 0.00;
        v_result.sgst_amt := 0.00;
        v_result.total_tax := v_result.igst_amt;
        v_result.total_amount := ROUND(p_taxable_value + v_result.total_tax, 2);
    ELSE
        -- Intra-State Supply: 50% CGST + 50% SGST
        v_half_rate := p_gst_rate / 2.0;
        v_result.cgst_amt := ROUND((p_taxable_value * (v_half_rate / 100.0)), 2);
        v_result.sgst_amt := ROUND((p_taxable_value * (v_half_rate / 100.0)), 2);
        v_result.igst_amt := 0.00;
        v_result.total_tax := ROUND(v_result.cgst_amt + v_result.sgst_amt, 2);
        v_result.total_amount := ROUND(p_taxable_value + v_result.total_tax, 2);
    END IF;

    RETURN v_result;
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. E-Way Bill Validity Calculation Function (Rule 138(10))
-- Standard Cargo: 1 Day per 200 km (or part thereof); ODC: 1 Day per 20 km
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_ewb_validity_days(
    distance_km NUMERIC,
    is_odc BOOLEAN DEFAULT FALSE
)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF distance_km <= 0 THEN
        RETURN 1;
    END IF;

    IF is_odc THEN
        RETURN GREATEST(1, CEIL(distance_km / 20.0)::INTEGER);
    ELSE
        RETURN GREATEST(1, CEIL(distance_km / 200.0)::INTEGER);
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.compute_gst_split(INTEGER, INTEGER, NUMERIC, NUMERIC, VARCHAR) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.calculate_ewb_validity_days(NUMERIC, BOOLEAN) TO authenticated, anon;

COMMIT;
