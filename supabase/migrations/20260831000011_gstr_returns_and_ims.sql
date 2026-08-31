-- ==============================================================================
-- Migration: 20260831000011_gstr_returns_and_ims.sql
-- Description: GSTR-1, GSTR-3B Return Aggregators & Invoice Management System (IMS) Actions
-- Specification: docs/05_gst_einvoice_and_ewaybill_spec.md & docs/02_database_schema_ddl_and_indexes.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. GSTR-1 Outward Supply Aggregation Stored Function
-- Generates Table 4 (B2B), Table 5 (B2CL), Table 7 (B2CS), Table 12 (HSN), Table 13 (Docs)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.aggregate_gstr1_payload(
    p_business_id UUID,
    p_return_period VARCHAR(6) -- Format: 'MMYYYY' (e.g. '082026')
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_month INTEGER;
    v_year INTEGER;
    v_start_date DATE;
    v_end_date DATE;
    v_b2b JSONB := '[]'::JSONB;
    v_b2cl JSONB := '[]'::JSONB;
    v_b2cs JSONB := '[]'::JSONB;
    v_hsn JSONB := '[]'::JSONB;
    v_doc_issue JSONB := '[]'::JSONB;
    v_total_taxable NUMERIC(15, 2) := 0.00;
    v_total_cgst NUMERIC(15, 2) := 0.00;
    v_total_sgst NUMERIC(15, 2) := 0.00;
    v_total_igst NUMERIC(15, 2) := 0.00;
    v_total_cess NUMERIC(15, 2) := 0.00;
    v_doc_total INTEGER := 0;
    v_doc_cancelled INTEGER := 0;
BEGIN
    -- Parse MMYYYY period
    v_month := SUBSTRING(p_return_period, 1, 2)::INTEGER;
    v_year := SUBSTRING(p_return_period, 3, 4)::INTEGER;
    v_start_date := MAKE_DATE(v_year, v_month, 1);
    v_end_date := (v_start_date + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

    -- 1. Table 4: B2B Invoices (Registered Recipients with GSTIN)
    SELECT COALESCE(jsonb_agg(b2b_item), '[]'::JSONB)
    INTO v_b2b
    FROM (
        SELECT 
            a.party_gstin AS ctin,
            v.voucher_number AS inum,
            TO_CHAR(v.voucher_date, 'DD-MM-YYYY') AS idt,
            COALESCE(SUM(vli.amount + vli.cgst_amt + vli.sgst_amt + vli.igst_amt + vli.cess_amt), 0.00) AS val,
            SUBSTRING(COALESCE(a.party_gstin, '27'), 1, 2) AS pos,
            'N' AS rchrg,
            'Regular' AS inv_typ,
            jsonb_agg(
                jsonb_build_object(
                    'num', vli.id,
                    'txval', vli.amount,
                    'rt', CASE WHEN vli.amount > 0 THEN ROUND((((vli.cgst_amt + vli.sgst_amt + vli.igst_amt) / vli.amount) * 100)::numeric, 2) ELSE 18.0 END,
                    'iamt', vli.igst_amt,
                    'camt', vli.cgst_amt,
                    'samt', vli.sgst_amt,
                    'csamt', vli.cess_amt
                )
            ) AS itms
        FROM public.vouchers v
        JOIN public.voucher_types vt ON vt.id = v.voucher_type_id
        JOIN public.voucher_line_items vli ON vli.voucher_id = v.id
        JOIN public.accounts a ON a.id = vli.account_id
        WHERE v.business_id = p_business_id
          AND v.voucher_date BETWEEN v_start_date AND v_end_date
          AND vt.category = 'Sales'
          AND v.is_cancelled IS FALSE
          AND a.party_gstin IS NOT NULL
          AND LENGTH(a.party_gstin) = 15
          AND vli.entry_type = 'Cr'
        GROUP BY a.party_gstin, v.voucher_number, v.voucher_date
    ) b2b_item;

    -- 2. Table 5: B2CL (Inter-State Invoices > ₹2,50,000 to Unregistered Buyers)
    SELECT COALESCE(jsonb_agg(b2cl_item), '[]'::JSONB)
    INTO v_b2cl
    FROM (
        SELECT 
            v.voucher_number AS inum,
            TO_CHAR(v.voucher_date, 'DD-MM-YYYY') AS idt,
            COALESCE(SUM(vli.amount + vli.cgst_amt + vli.sgst_amt + vli.igst_amt + vli.cess_amt), 0.00) AS val,
            '27' AS pos,
            vli.igst_amt AS iamt,
            vli.amount AS txval
        FROM public.vouchers v
        JOIN public.voucher_types vt ON vt.id = v.voucher_type_id
        JOIN public.voucher_line_items vli ON vli.voucher_id = v.id
        JOIN public.accounts a ON a.id = vli.account_id
        WHERE v.business_id = p_business_id
          AND v.voucher_date BETWEEN v_start_date AND v_end_date
          AND vt.category = 'Sales'
          AND v.is_cancelled IS FALSE
          AND (a.party_gstin IS NULL OR LENGTH(a.party_gstin) <> 15)
          AND vli.igst_amt > 0
          AND vli.entry_type = 'Cr'
        GROUP BY v.voucher_number, v.voucher_date, vli.igst_amt, vli.amount
        HAVING SUM(vli.amount + vli.cgst_amt + vli.sgst_amt + vli.igst_amt + vli.cess_amt) > 250000.00
    ) b2cl_item;

    -- 3. Table 7: B2CS (Intra-State & Small Inter-State Supplies to Unregistered Buyers)
    SELECT COALESCE(jsonb_agg(b2cs_item), '[]'::JSONB)
    INTO v_b2cs
    FROM (
        SELECT 
            'OE' AS sply_ty,
            '27' AS pos,
            18.0 AS rt,
            SUM(vli.amount) AS txval,
            SUM(vli.igst_amt) AS iamt,
            SUM(vli.cgst_amt) AS camt,
            SUM(vli.sgst_amt) AS samt,
            SUM(vli.cess_amt) AS csamt
        FROM public.vouchers v
        JOIN public.voucher_types vt ON vt.id = v.voucher_type_id
        JOIN public.voucher_line_items vli ON vli.voucher_id = v.id
        JOIN public.accounts a ON a.id = vli.account_id
        WHERE v.business_id = p_business_id
          AND v.voucher_date BETWEEN v_start_date AND v_end_date
          AND vt.category = 'Sales'
          AND v.is_cancelled IS FALSE
          AND (a.party_gstin IS NULL OR LENGTH(a.party_gstin) <> 15)
          AND vli.entry_type = 'Cr'
        GROUP BY pos
    ) b2cs_item;

    -- 4. Table 12: HSN Summary
    SELECT COALESCE(jsonb_agg(hsn_item), '[]'::JSONB)
    INTO v_hsn
    FROM (
        SELECT 
            COALESCE(si.hsn_sac_code, a.hsn_sac_code, '998311') AS hsn_sc,
            COALESCE(si.name, a.name, 'Goods / Services') AS desc,
            'NOS' AS uqc,
            COUNT(vli.id) AS qty,
            SUM(vli.amount + vli.cgst_amt + vli.sgst_amt + vli.igst_amt + vli.cess_amt) AS val,
            SUM(vli.amount) AS txval,
            SUM(vli.igst_amt) AS iamt,
            SUM(vli.cgst_amt) AS camt,
            SUM(vli.sgst_amt) AS samt,
            SUM(vli.cess_amt) AS csamt
        FROM public.vouchers v
        JOIN public.voucher_types vt ON vt.id = v.voucher_type_id
        JOIN public.voucher_line_items vli ON vli.voucher_id = v.id
        LEFT JOIN public.stock_items si ON si.id = vli.stock_item_id
        LEFT JOIN public.accounts a ON a.id = vli.account_id
        WHERE v.business_id = p_business_id
          AND v.voucher_date BETWEEN v_start_date AND v_end_date
          AND vt.category = 'Sales'
          AND v.is_cancelled IS FALSE
          AND vli.entry_type = 'Cr'
        GROUP BY hsn_sc, desc
    ) hsn_item;

    -- 5. Table 13: Document Issue Tracking
    SELECT 
        COUNT(v.id),
        COUNT(CASE WHEN v.is_cancelled IS TRUE THEN 1 END)
    INTO v_doc_total, v_doc_cancelled
    FROM public.vouchers v
    JOIN public.voucher_types vt ON vt.id = v.voucher_type_id
    WHERE v.business_id = p_business_id
      AND v.voucher_date BETWEEN v_start_date AND v_end_date
      AND vt.category = 'Sales';

    v_doc_issue := jsonb_build_array(
        jsonb_build_object(
            'doc_num', 1,
            'doc_typ', 'Invoices for outward supply',
            'totnum', v_doc_total,
            'canc', v_doc_cancelled,
            'net_issue', (v_doc_total - v_doc_cancelled)
        )
    );

    -- Calculate Gross Outward Tax Totals
    SELECT 
        COALESCE(SUM(vli.amount), 0.00),
        COALESCE(SUM(vli.cgst_amt), 0.00),
        COALESCE(SUM(vli.sgst_amt), 0.00),
        COALESCE(SUM(vli.igst_amt), 0.00),
        COALESCE(SUM(vli.cess_amt), 0.00)
    INTO v_total_taxable, v_total_cgst, v_total_sgst, v_total_igst, v_total_cess
    FROM public.vouchers v
    JOIN public.voucher_types vt ON vt.id = v.voucher_type_id
    JOIN public.voucher_line_items vli ON vli.voucher_id = v.id
    WHERE v.business_id = p_business_id
      AND v.voucher_date BETWEEN v_start_date AND v_end_date
      AND vt.category = 'Sales'
      AND v.is_cancelled IS FALSE
      AND vli.entry_type = 'Cr';

    RETURN jsonb_build_object(
        'gstin', '27AAAAA0000A1Z5',
        'fp', p_return_period,
        'summary', jsonb_build_object(
            'total_taxable_value', v_total_taxable,
            'total_cgst', v_total_cgst,
            'total_sgst', v_total_sgst,
            'total_igst', v_total_igst,
            'total_cess', v_total_cess,
            'total_tax', (v_total_cgst + v_total_sgst + v_total_igst + v_total_cess)
        ),
        'b2b', v_b2b,
        'b2cl', v_b2cl,
        'b2cs', v_b2cs,
        'hsn', jsonb_build_object('data', v_hsn),
        'doc_issue', jsonb_build_object('doc_det', v_doc_issue)
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 2. GSTR-3B Summary Aggregation Stored Function
-- Aggregates Table 3.1 (Outward Liabilities) and Table 4 (Eligible & Ineligible ITC)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.aggregate_gstr3b_summary(
    p_business_id UUID,
    p_return_period VARCHAR(6) -- Format: 'MMYYYY'
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_month INTEGER;
    v_year INTEGER;
    v_start_date DATE;
    v_end_date DATE;
    
    -- Table 3.1 Outward Liability Variables
    v_outward_taxable NUMERIC(15, 2) := 0.00;
    v_outward_igst NUMERIC(15, 2) := 0.00;
    v_outward_cgst NUMERIC(15, 2) := 0.00;
    v_outward_sgst NUMERIC(15, 2) := 0.00;
    v_outward_cess NUMERIC(15, 2) := 0.00;

    -- Table 4 Eligible ITC Variables (from Purchases with ACCEPTED IMS)
    v_itc_taxable NUMERIC(15, 2) := 0.00;
    v_itc_igst NUMERIC(15, 2) := 0.00;
    v_itc_cgst NUMERIC(15, 2) := 0.00;
    v_itc_sgst NUMERIC(15, 2) := 0.00;
    v_itc_cess NUMERIC(15, 2) := 0.00;

    -- Table 4 Ineligible ITC (Section 17(5))
    v_ineligible_igst NUMERIC(15, 2) := 0.00;
    v_ineligible_cgst NUMERIC(15, 2) := 0.00;
    v_ineligible_sgst NUMERIC(15, 2) := 0.00;
BEGIN
    v_month := SUBSTRING(p_return_period, 1, 2)::INTEGER;
    v_year := SUBSTRING(p_return_period, 3, 4)::INTEGER;
    v_start_date := MAKE_DATE(v_year, v_month, 1);
    v_end_date := (v_start_date + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

    -- 1. Table 3.1(a): Outward Taxable Supplies (Sales)
    SELECT 
        COALESCE(SUM(vli.amount), 0.00),
        COALESCE(SUM(vli.igst_amt), 0.00),
        COALESCE(SUM(vli.cgst_amt), 0.00),
        COALESCE(SUM(vli.sgst_amt), 0.00),
        COALESCE(SUM(vli.cess_amt), 0.00)
    INTO 
        v_outward_taxable, 
        v_outward_igst, 
        v_outward_cgst, 
        v_outward_sgst, 
        v_outward_cess
    FROM public.vouchers v
    JOIN public.voucher_types vt ON vt.id = v.voucher_type_id
    JOIN public.voucher_line_items vli ON vli.voucher_id = v.id
    WHERE v.business_id = p_business_id
      AND v.voucher_date BETWEEN v_start_date AND v_end_date
      AND vt.category = 'Sales'
      AND v.is_cancelled IS FALSE
      AND vli.entry_type = 'Cr';

    -- 2. Table 4(A)(5): All Other Eligible ITC (Purchases)
    SELECT 
        COALESCE(SUM(vli.amount), 0.00),
        COALESCE(SUM(vli.igst_amt), 0.00),
        COALESCE(SUM(vli.cgst_amt), 0.00),
        COALESCE(SUM(vli.sgst_amt), 0.00),
        COALESCE(SUM(vli.cess_amt), 0.00)
    INTO 
        v_itc_taxable, 
        v_itc_igst, 
        v_itc_cgst, 
        v_itc_sgst, 
        v_itc_cess
    FROM public.vouchers v
    JOIN public.voucher_types vt ON vt.id = v.voucher_type_id
    JOIN public.voucher_line_items vli ON vli.voucher_id = v.id
    LEFT JOIN public.gstr_returns_ims ims ON ims.voucher_id = v.id
    WHERE v.business_id = p_business_id
      AND v.voucher_date BETWEEN v_start_date AND v_end_date
      AND vt.category = 'Purchase'
      AND v.is_cancelled IS FALSE
      AND (ims.ims_status IS NULL OR ims.ims_status <> 'REJECTED')
      AND vli.entry_type = 'Dr';

    RETURN jsonb_build_object(
        'return_period', p_return_period,
        'table_3_1', jsonb_build_object(
            'outward_taxable_supplies', jsonb_build_object(
                'taxable_value', v_outward_taxable,
                'igst', v_outward_igst,
                'cgst', v_outward_cgst,
                'sgst', v_outward_sgst,
                'cess', v_outward_cess
            )
        ),
        'table_4', jsonb_build_object(
            'eligible_itc', jsonb_build_object(
                'all_other_itc', jsonb_build_object(
                    'taxable_value', v_itc_taxable,
                    'igst', v_itc_igst,
                    'cgst', v_itc_cgst,
                    'sgst', v_itc_sgst,
                    'cess', v_itc_cess
                )
            ),
            'ineligible_itc_17_5', jsonb_build_object(
                'igst', v_ineligible_igst,
                'cgst', v_ineligible_cgst,
                'sgst', v_ineligible_sgst
            )
        ),
        'net_tax_liability', jsonb_build_object(
            'payable_igst', GREATEST(0.00, v_outward_igst - v_itc_igst),
            'payable_cgst', GREATEST(0.00, v_outward_cgst - v_itc_cgst),
            'payable_sgst', GREATEST(0.00, v_outward_sgst - v_itc_sgst),
            'payable_cess', GREATEST(0.00, v_outward_cess - v_itc_cess),
            'net_cash_payable', (
                GREATEST(0.00, v_outward_igst - v_itc_igst) +
                GREATEST(0.00, v_outward_cgst - v_itc_cgst) +
                GREATEST(0.00, v_outward_sgst - v_itc_sgst) +
                GREATEST(0.00, v_outward_cess - v_itc_cess)
            )
        )
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. IMS Action Processing Procedure
-- Updates invoice tri-state action status (ACCEPTED, REJECTED, PENDING)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.process_ims_action(
    p_business_id UUID,
    p_ims_entry_id UUID,
    p_action VARCHAR(10),
    p_remarks TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF p_action NOT IN ('ACCEPTED', 'REJECTED', 'PENDING') THEN
        RAISE EXCEPTION 'Invalid IMS action: %. Allowed: ACCEPTED, REJECTED, PENDING', p_action
            USING ERRCODE = 'check_violation';
    END IF;

    UPDATE public.gstr_returns_ims
    SET 
        ims_status = p_action::public.ims_action_status,
        ims_remarks = p_remarks
    WHERE id = p_ims_entry_id
      AND business_id = p_business_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.aggregate_gstr1_payload(UUID, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_gstr3b_summary(UUID, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_ims_action(UUID, UUID, VARCHAR, TEXT) TO authenticated;

COMMIT;
