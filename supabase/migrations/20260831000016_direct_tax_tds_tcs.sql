-- ==============================================================================
-- Migration: 20260831000016_direct_tax_tds_tcs.sql
-- Description: Direct Taxation Engine (TDS Section 194Q, TCS Section 206C & Form 26Q/27EQ Aggregator)
-- Specification: docs/08_banking_brs_payroll_direct_tax.md & docs/02_database_schema_ddl_and_indexes.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Section 194Q TDS Deduction Stored Procedure (Purchase of Goods > ₹50 Lakhs)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.process_section_194q_tds(
    p_business_id UUID,
    p_voucher_id UUID,
    p_party_account_id UUID,
    p_purchase_amount NUMERIC(15, 2)
)
RETURNS NUMERIC(15, 2)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_party_pan VARCHAR(10);
    v_ytd_purchases NUMERIC(15, 2) := 0.00;
    v_tds_rate NUMERIC(5, 3) := 0.001; -- 0.1% normal rate
    v_taxable_excess NUMERIC(15, 2) := 0.00;
    v_tds_amount NUMERIC(15, 2) := 0.00;
    v_threshold NUMERIC(15, 2) := 5000000.00; -- ₹50,00,000 statutory limit
BEGIN
    SELECT party_pan INTO v_party_pan FROM public.accounts WHERE id = p_party_account_id;

    -- Higher penalty rate under Section 206AA if PAN missing (5.0%)
    IF v_party_pan IS NULL OR LENGTH(TRIM(v_party_pan)) <> 10 THEN
        v_tds_rate := 0.050;
        v_party_pan := 'PANNOTAVBL';
    END IF;

    -- Calculate financial Year-to-Date (YTD) purchases for this vendor (starting April 1st)
    SELECT COALESCE(SUM(vli.amount), 0.00) INTO v_ytd_purchases
    FROM public.voucher_line_items vli
    JOIN public.vouchers v ON v.id = vli.voucher_id
    WHERE v.business_id = p_business_id
      AND vli.account_id = p_party_account_id
      AND vli.entry_type = 'Cr'
      AND v.is_cancelled = FALSE
      AND v.voucher_date >= (
          CASE 
              WHEN EXTRACT(MONTH FROM CURRENT_DATE) >= 4 
              THEN MAKE_DATE(EXTRACT(YEAR FROM CURRENT_DATE)::INT, 4, 1)
              ELSE MAKE_DATE((EXTRACT(YEAR FROM CURRENT_DATE) - 1)::INT, 4, 1)
          END
      );

    -- Check if cumulative threshold of ₹50 Lakhs is crossed
    IF (v_ytd_purchases + p_purchase_amount) > v_threshold THEN
        IF v_ytd_purchases >= v_threshold THEN
            v_taxable_excess := p_purchase_amount;
        ELSE
            v_taxable_excess := (v_ytd_purchases + p_purchase_amount) - v_threshold;
        END IF;

        v_tds_amount := ROUND((v_taxable_excess * v_tds_rate), 2);

        -- Record TDS Entry for Form 26Q filing
        INSERT INTO public.tds_tcs_entries (
            business_id, voucher_id, section_code, party_pan,
            assessed_amount, tds_tcs_rate, tax_amount, form_type
        ) VALUES (
            p_business_id, p_voucher_id, '194Q', v_party_pan,
            v_taxable_excess, v_tds_rate, v_tds_amount, '26Q'
        );
    END IF;

    RETURN v_tds_amount;
END;
$$;

-- ------------------------------------------------------------------------------
-- 2. Section 206C(1H) TCS Collection Stored Procedure (Sale of Goods > ₹50 Lakhs)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.process_section_206c_tcs(
    p_business_id UUID,
    p_voucher_id UUID,
    p_party_account_id UUID,
    p_receipt_amount NUMERIC(15, 2)
)
RETURNS NUMERIC(15, 2)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_party_pan VARCHAR(10);
    v_ytd_receipts NUMERIC(15, 2) := 0.00;
    v_tcs_rate NUMERIC(5, 3) := 0.001; -- 0.1% standard rate
    v_taxable_excess NUMERIC(15, 2) := 0.00;
    v_tcs_amount NUMERIC(15, 2) := 0.00;
    v_threshold NUMERIC(15, 2) := 5000000.00; -- ₹50,00,000 threshold
BEGIN
    SELECT party_pan INTO v_party_pan FROM public.accounts WHERE id = p_party_account_id;

    -- Higher penalty rate under Section 206CC if PAN missing (1.0%)
    IF v_party_pan IS NULL OR LENGTH(TRIM(v_party_pan)) <> 10 THEN
        v_tcs_rate := 0.010;
        v_party_pan := 'PANNOTAVBL';
    END IF;

    -- Calculate financial Year-to-Date (YTD) customer collections
    SELECT COALESCE(SUM(vli.amount), 0.00) INTO v_ytd_receipts
    FROM public.voucher_line_items vli
    JOIN public.vouchers v ON v.id = vli.voucher_id
    WHERE v.business_id = p_business_id
      AND vli.account_id = p_party_account_id
      AND vli.entry_type = 'Dr'
      AND v.is_cancelled = FALSE
      AND v.voucher_date >= (
          CASE 
              WHEN EXTRACT(MONTH FROM CURRENT_DATE) >= 4 
              THEN MAKE_DATE(EXTRACT(YEAR FROM CURRENT_DATE)::INT, 4, 1)
              ELSE MAKE_DATE((EXTRACT(YEAR FROM CURRENT_DATE) - 1)::INT, 4, 1)
          END
      );

    IF (v_ytd_receipts + p_receipt_amount) > v_threshold THEN
        IF v_ytd_receipts >= v_threshold THEN
            v_taxable_excess := p_receipt_amount;
        ELSE
            v_taxable_excess := (v_ytd_receipts + p_receipt_amount) - v_threshold;
        END IF;

        v_tcs_amount := ROUND((v_taxable_excess * v_tcs_rate), 2);

        -- Record TCS Entry for Form 27EQ filing
        INSERT INTO public.tds_tcs_entries (
            business_id, voucher_id, section_code, party_pan,
            assessed_amount, tds_tcs_rate, tax_amount, form_type
        ) VALUES (
            p_business_id, p_voucher_id, '206C(1H)', v_party_pan,
            v_taxable_excess, v_tcs_rate, v_tcs_amount, '27EQ'
        );
    END IF;

    RETURN v_tcs_amount;
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. Quarterly Form 26Q / 27EQ Aggregation Stored Procedure
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_form_26q_payload(
    p_business_id UUID,
    p_financial_year VARCHAR(9), -- e.g. '2026-2027'
    p_quarter VARCHAR(2)         -- 'Q1', 'Q2', 'Q3', 'Q4'
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_q_start DATE;
    v_q_end DATE;
    v_base_year INT;
    v_result JSONB;
BEGIN
    v_base_year := SPLIT_PART(p_financial_year, '-', 1)::INT;

    IF p_quarter = 'Q1' THEN
        v_q_start := MAKE_DATE(v_base_year, 4, 1);
        v_q_end := MAKE_DATE(v_base_year, 6, 30);
    ELSIF p_quarter = 'Q2' THEN
        v_q_start := MAKE_DATE(v_base_year, 7, 1);
        v_q_end := MAKE_DATE(v_base_year, 9, 30);
    ELSIF p_quarter = 'Q3' THEN
        v_q_start := MAKE_DATE(v_base_year, 10, 1);
        v_q_end := MAKE_DATE(v_base_year, 12, 31);
    ELSE
        v_q_start := MAKE_DATE(v_base_year + 1, 1, 1);
        v_q_end := MAKE_DATE(v_base_year + 1, 3, 31);
    END IF;

    SELECT jsonb_build_object(
        'financial_year', p_financial_year,
        'quarter', p_quarter,
        'period_start', v_q_start,
        'period_end', v_q_end,
        'total_entries', COUNT(t.id),
        'total_tax_deducted', COALESCE(SUM(t.tax_amount), 0.00),
        'deductee_records', COALESCE(jsonb_agg(
            jsonb_build_object(
                'entry_id', t.id,
                'section_code', t.section_code,
                'party_pan', t.party_pan,
                'party_name', a.name,
                'voucher_number', v.voucher_number,
                'voucher_date', v.voucher_date,
                'assessed_amount', t.assessed_amount,
                'tax_rate', t.tds_tcs_rate,
                'tax_amount', t.tax_amount,
                'challan_number', t.challan_number,
                'challan_date', t.challan_date
            )
        ), '[]'::JSONB)
    ) INTO v_result
    FROM public.tds_tcs_entries t
    JOIN public.vouchers v ON v.id = t.voucher_id
    JOIN public.voucher_line_items vli ON vli.voucher_id = v.id AND vli.entry_type = 'Cr'
    JOIN public.accounts a ON a.id = vli.account_id
    WHERE t.business_id = p_business_id
      AND t.form_type = '26Q'
      AND v.voucher_date BETWEEN v_q_start AND v_q_end;

    RETURN v_result;
END;
$$;

-- ------------------------------------------------------------------------------
-- 4. Challan Payment Link Procedure
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_tds_challan_details(
    p_business_id UUID,
    p_entry_ids UUID[],
    p_challan_number VARCHAR(50),
    p_challan_date DATE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.tds_tcs_entries
    SET challan_number = p_challan_number,
        challan_date = p_challan_date
    WHERE business_id = p_business_id
      AND id = ANY(p_entry_ids);
END;
$$;

GRANT EXECUTE ON FUNCTION public.process_section_194q_tds(UUID, UUID, UUID, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_section_206c_tcs(UUID, UUID, UUID, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_form_26q_payload(UUID, VARCHAR, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_tds_challan_details(UUID, UUID[], VARCHAR, DATE) TO authenticated;

COMMIT;
