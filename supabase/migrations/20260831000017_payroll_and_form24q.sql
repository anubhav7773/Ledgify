-- ==============================================================================
-- Migration: 20260831000017_payroll_and_form24q.sql
-- Description: Automated Indian Payroll Engine, EPF/ESI Statutory Calculations & Form 24Q Pipeline
-- Specification: docs/08_banking_brs_payroll_direct_tax.md & docs/02_database_schema_ddl_and_indexes.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Extend Employees Payroll Schema with Statutory Metadata
-- ------------------------------------------------------------------------------
ALTER TABLE public.employees_payroll
ADD COLUMN IF NOT EXISTS designation VARCHAR(100),
ADD COLUMN IF NOT EXISTS department VARCHAR(100),
ADD COLUMN IF NOT EXISTS pan VARCHAR(10),
ADD COLUMN IF NOT EXISTS aadhaar VARCHAR(12),
ADD COLUMN IF NOT EXISTS bank_account_number VARCHAR(50),
ADD COLUMN IF NOT EXISTS ifsc_code VARCHAR(11),
ADD COLUMN IF NOT EXISTS pf_uan VARCHAR(12),
ADD COLUMN IF NOT EXISTS esic_number VARCHAR(17),
ADD COLUMN IF NOT EXISTS professional_tax NUMERIC(10, 2) DEFAULT 200.00,
ADD COLUMN IF NOT EXISTS monthly_tds NUMERIC(10, 2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS joining_date DATE DEFAULT CURRENT_DATE;

-- ------------------------------------------------------------------------------
-- 2. Monthly Payroll Calculation Stored Function (Preview / Compute)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_monthly_payroll(
    p_business_id UUID,
    p_month_year VARCHAR(7) -- 'YYYY-MM', e.g. '2026-08'
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_records JSONB;
    v_totals RECORD;
BEGIN
    WITH computed_salaries AS (
        SELECT 
            e.id AS employee_id,
            e.employee_code,
            e.full_name,
            e.designation,
            e.pan,
            e.tax_regime,
            e.basic_salary,
            e.hra,
            e.special_allowance,
            (e.basic_salary + e.hra + e.special_allowance) AS gross_salary,
            -- EPF Employee (12% of Basic capped at ₹15,000 ceiling -> max ₹1,800)
            CASE 
                WHEN e.pf_applicable THEN ROUND((LEAST(e.basic_salary, 15000.00) * 0.12), 2)
                ELSE 0.00
            END AS epf_employee,
            -- EPF Employer (12% of Basic capped at ₹15,000 ceiling)
            CASE 
                WHEN e.pf_applicable THEN ROUND((LEAST(e.basic_salary, 15000.00) * 0.12), 2)
                ELSE 0.00
            END AS epf_employer,
            -- ESI Employee (0.75% of Gross if Gross <= ₹21,000)
            CASE 
                WHEN e.esi_applicable OR (e.basic_salary + e.hra + e.special_allowance) <= 21000.00 
                THEN ROUND(((e.basic_salary + e.hra + e.special_allowance) * 0.0075), 2)
                ELSE 0.00
            END AS esi_employee,
            -- ESI Employer (3.25% of Gross if Gross <= ₹21,000)
            CASE 
                WHEN e.esi_applicable OR (e.basic_salary + e.hra + e.special_allowance) <= 21000.00 
                THEN ROUND(((e.basic_salary + e.hra + e.special_allowance) * 0.0325), 2)
                ELSE 0.00
            END AS esi_employer,
            COALESCE(e.professional_tax, 200.00) AS professional_tax,
            COALESCE(e.monthly_tds, 0.00) AS tds_salary
        FROM public.employees_payroll e
        WHERE e.business_id = p_business_id
          AND e.is_active = TRUE
    ),
    evaluated_salaries AS (
        SELECT 
            c.*,
            (c.epf_employee + c.esi_employee + c.professional_tax + c.tds_salary) AS total_deductions,
            (c.gross_salary - (c.epf_employee + c.esi_employee + c.professional_tax + c.tds_salary)) AS net_payable
        FROM computed_salaries c
    )
    SELECT 
        jsonb_build_object(
            'month_year', p_month_year,
            'employee_count', COUNT(e.employee_id),
            'total_gross', COALESCE(SUM(e.gross_salary), 0.00),
            'total_epf_employee', COALESCE(SUM(e.epf_employee), 0.00),
            'total_epf_employer', COALESCE(SUM(e.epf_employer), 0.00),
            'total_esi_employee', COALESCE(SUM(e.esi_employee), 0.00),
            'total_esi_employer', COALESCE(SUM(e.esi_employer), 0.00),
            'total_professional_tax', COALESCE(SUM(e.professional_tax), 0.00),
            'total_tds_salary', COALESCE(SUM(e.tds_salary), 0.00),
            'total_net_payable', COALESCE(SUM(e.net_payable), 0.00),
            'employees', COALESCE(jsonb_agg(to_jsonb(e.*)), '[]'::JSONB)
        ) INTO v_records
    FROM evaluated_salaries e;

    RETURN v_records;
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. Automated Salary Journal Voucher Posting Stored Procedure
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.post_monthly_payroll_voucher(
    p_business_id UUID,
    p_month_year VARCHAR(7), -- 'YYYY-MM'
    p_payment_date DATE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_data JSONB;
    v_voucher_id UUID;
    v_vtype_id UUID;
    v_sal_exp_ledger UUID;
    v_epf_exp_ledger UUID;
    v_esi_exp_ledger UUID;
    v_sal_pay_ledger UUID;
    v_epf_pay_ledger UUID;
    v_esi_pay_ledger UUID;
    v_pt_pay_ledger UUID;
    v_tds_pay_ledger UUID;
    
    v_total_gross NUMERIC(15, 2);
    v_total_epf_er NUMERIC(15, 2);
    v_total_esi_er NUMERIC(15, 2);
    v_total_net NUMERIC(15, 2);
    v_total_epf_comb NUMERIC(15, 2);
    v_total_esi_comb NUMERIC(15, 2);
    v_total_pt NUMERIC(15, 2);
    v_total_tds NUMERIC(15, 2);
    v_emp_count INT;
BEGIN
    -- 1. Compute payroll aggregation
    v_data := public.calculate_monthly_payroll(p_business_id, p_month_year);
    v_emp_count := (v_data->>'employee_count')::INT;

    IF v_emp_count = 0 THEN
        RAISE EXCEPTION 'No active employees found for payroll processing.';
    END IF;

    v_total_gross := (v_data->>'total_gross')::NUMERIC;
    v_total_epf_er := (v_data->>'total_epf_employer')::NUMERIC;
    v_total_esi_er := (v_data->>'total_esi_employer')::NUMERIC;
    v_total_net := (v_data->>'total_net_payable')::NUMERIC;
    v_total_epf_comb := ((v_data->>'total_epf_employee')::NUMERIC + v_total_epf_er);
    v_total_esi_comb := ((v_data->>'total_esi_employee')::NUMERIC + v_total_esi_er);
    v_total_pt := (v_data->>'total_professional_tax')::NUMERIC;
    v_total_tds := (v_data->>'total_tds_salary')::NUMERIC;

    -- 2. Lookup Chart of Accounts Ledgers
    SELECT id INTO v_vtype_id FROM public.voucher_types WHERE (business_id = p_business_id OR is_system_default = TRUE) AND name = 'Journal' LIMIT 1;
    
    SELECT id INTO v_sal_exp_ledger FROM public.accounts WHERE business_id = p_business_id AND name ILIKE '%Salary Expense%' LIMIT 1;
    IF v_sal_exp_ledger IS NULL THEN SELECT id INTO v_sal_exp_ledger FROM public.accounts WHERE business_id = p_business_id AND group_name = 'Indirect Expenses' LIMIT 1; END IF;

    SELECT id INTO v_sal_pay_ledger FROM public.accounts WHERE business_id = p_business_id AND name ILIKE '%Salaries Payable%' LIMIT 1;
    IF v_sal_pay_ledger IS NULL THEN SELECT id INTO v_sal_pay_ledger FROM public.accounts WHERE business_id = p_business_id AND group_name = 'Current Liabilities' LIMIT 1; END IF;

    SELECT id INTO v_epf_pay_ledger FROM public.accounts WHERE business_id = p_business_id AND name ILIKE '%EPF Payable%' LIMIT 1;
    IF v_epf_pay_ledger IS NULL THEN v_epf_pay_ledger := v_sal_pay_ledger; END IF;

    SELECT id INTO v_esi_pay_ledger FROM public.accounts WHERE business_id = p_business_id AND name ILIKE '%ESI Payable%' LIMIT 1;
    IF v_esi_pay_ledger IS NULL THEN v_esi_pay_ledger := v_sal_pay_ledger; END IF;

    SELECT id INTO v_pt_pay_ledger FROM public.accounts WHERE business_id = p_business_id AND name ILIKE '%Professional Tax%' LIMIT 1;
    IF v_pt_pay_ledger IS NULL THEN v_pt_pay_ledger := v_sal_pay_ledger; END IF;

    SELECT id INTO v_tds_pay_ledger FROM public.accounts WHERE business_id = p_business_id AND name ILIKE '%TDS Salary%' LIMIT 1;
    IF v_tds_pay_ledger IS NULL THEN v_tds_pay_ledger := v_sal_pay_ledger; END IF;

    -- 3. Insert Journal Voucher Header
    INSERT INTO public.vouchers (
        business_id, voucher_type_id, voucher_number, voucher_date, narration
    ) VALUES (
        p_business_id, v_vtype_id, 'PAYROLL-' || REPLACE(p_month_year, '-', '') || '-' || SUBSTRING(gen_random_uuid()::TEXT, 1, 4),
        p_payment_date,
        'Monthly Salary Journal & Statutory Provisions for ' || p_month_year || ' (' || v_emp_count || ' employees)'
    ) RETURNING id INTO v_voucher_id;

    -- 4. Debits: Gross Salary & Employer Contributions
    INSERT INTO public.voucher_line_items (business_id, voucher_id, account_id, entry_type, amount, item_description)
    VALUES (p_business_id, v_voucher_id, v_sal_exp_ledger, 'Dr', (v_total_gross + v_total_epf_er + v_total_esi_er), 'Gross Salaries and Statutory Employer Dues for ' || p_month_year);

    -- 5. Credits: Net Salary Payable and Statutory Dues
    INSERT INTO public.voucher_line_items (business_id, voucher_id, account_id, entry_type, amount, item_description)
    VALUES (p_business_id, v_voucher_id, v_sal_pay_ledger, 'Cr', v_total_net, 'Net Salary Payable to Employees for ' || p_month_year);

    IF v_total_epf_comb > 0 THEN
        INSERT INTO public.voucher_line_items (business_id, voucher_id, account_id, entry_type, amount, item_description)
        VALUES (p_business_id, v_voucher_id, v_epf_pay_ledger, 'Cr', v_total_epf_comb, 'Combined EPF Statutory Due (12% EE + 12% ER)');
    END IF;

    IF v_total_esi_comb > 0 THEN
        INSERT INTO public.voucher_line_items (business_id, voucher_id, account_id, entry_type, amount, item_description)
        VALUES (p_business_id, v_voucher_id, v_esi_pay_ledger, 'Cr', v_total_esi_comb, 'Combined ESI Statutory Due (0.75% EE + 3.25% ER)');
    END IF;

    IF v_total_pt > 0 THEN
        INSERT INTO public.voucher_line_items (business_id, voucher_id, account_id, entry_type, amount, item_description)
        VALUES (p_business_id, v_voucher_id, v_pt_pay_ledger, 'Cr', v_total_pt, 'Professional Tax Payable');
    END IF;

    IF v_total_tds > 0 THEN
        INSERT INTO public.voucher_line_items (business_id, voucher_id, account_id, entry_type, amount, item_description)
        VALUES (p_business_id, v_voucher_id, v_tds_pay_ledger, 'Cr', v_total_tds, 'TDS under Section 192 (Salaries)');
    END IF;

    RETURN v_voucher_id;
END;
$$;

-- ------------------------------------------------------------------------------
-- 4. Form 24Q Quarterly TDS on Salary Stored Function
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_form_24q_payload(
    p_business_id UUID,
    p_financial_year VARCHAR(9), -- '2026-2027'
    p_quarter VARCHAR(2)         -- 'Q1', 'Q2', 'Q3', 'Q4'
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'financial_year', p_financial_year,
        'quarter', p_quarter,
        'form_type', '24Q',
        'employee_records', COALESCE(jsonb_agg(
            jsonb_build_object(
                'employee_code', e.employee_code,
                'full_name', e.full_name,
                'pan', e.pan,
                'tax_regime', e.tax_regime,
                'basic_salary', e.basic_salary,
                'gross_salary', (e.basic_salary + e.hra + e.special_allowance),
                'pf_deduction', CASE WHEN e.pf_applicable THEN ROUND((LEAST(e.basic_salary, 15000.00) * 0.12), 2) ELSE 0.00 END,
                'monthly_tds', e.monthly_tds
            )
        ), '[]'::JSONB)
    ) INTO v_result
    FROM public.employees_payroll e
    WHERE e.business_id = p_business_id
      AND e.is_active = TRUE;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_monthly_payroll(UUID, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_monthly_payroll_voucher(UUID, VARCHAR, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_form_24q_payload(UUID, VARCHAR, VARCHAR) TO authenticated;

COMMIT;
