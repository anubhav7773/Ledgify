-- ==============================================================================
-- Migration: 20260831000018_financial_reports_engine.sql
-- Description: Financial Reporting Engine (Trial Balance, P&L, Balance Sheet, Cash Flow)
-- Specification: docs/04_core_accounting_engine_rules.md & docs/02_database_schema_ddl_and_indexes.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Trial Balance Stored Function
-- Aggregates Opening Balances, Period Debits/Credits, and Closing Balances
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_trial_balance(
    p_business_id UUID,
    p_from_date DATE,
    p_to_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    WITH prior_txns AS (
        -- Net transactions prior to from_date
        SELECT 
            vli.account_id,
            COALESCE(SUM(CASE WHEN vli.entry_type = 'Dr' THEN vli.amount ELSE -vli.amount END), 0.00) AS prior_net
        FROM public.voucher_line_items vli
        JOIN public.vouchers v ON v.id = vli.voucher_id
        WHERE v.business_id = p_business_id
          AND v.is_cancelled = FALSE
          AND v.voucher_date < p_from_date
        GROUP BY vli.account_id
    ),
    period_txns AS (
        -- Debits and Credits within reporting period
        SELECT 
            vli.account_id,
            COALESCE(SUM(CASE WHEN vli.entry_type = 'Dr' THEN vli.amount ELSE 0.00 END), 0.00) AS period_dr,
            COALESCE(SUM(CASE WHEN vli.entry_type = 'Cr' THEN vli.amount ELSE 0.00 END), 0.00) AS period_cr
        FROM public.voucher_line_items vli
        JOIN public.vouchers v ON v.id = vli.voucher_id
        WHERE v.business_id = p_business_id
          AND v.is_cancelled = FALSE
          AND v.voucher_date BETWEEN p_from_date AND p_to_date
        GROUP BY vli.account_id
    ),
    account_balances AS (
        SELECT 
            a.id AS account_id,
            a.name AS account_name,
            a.group_name,
            a.primary_classification,
            -- Effective Opening Balance
            (
                (CASE WHEN a.opening_balance_type = 'Dr' THEN a.opening_balance ELSE -a.opening_balance END) 
                + COALESCE(pt.prior_net, 0.00)
            ) AS net_opening,
            COALESCE(prt.period_dr, 0.00) AS period_dr,
            COALESCE(prt.period_cr, 0.00) AS period_cr,
            -- Net Closing Balance
            (
                (CASE WHEN a.opening_balance_type = 'Dr' THEN a.opening_balance ELSE -a.opening_balance END) 
                + COALESCE(pt.prior_net, 0.00)
                + (COALESCE(prt.period_dr, 0.00) - COALESCE(prt.period_cr, 0.00))
            ) AS net_closing
        FROM public.accounts a
        LEFT JOIN prior_txns pt ON pt.account_id = a.id
        LEFT JOIN period_txns prt ON prt.account_id = a.id
        WHERE a.business_id = p_business_id
          AND a.is_active = TRUE
    ),
    evaluated_rows AS (
        SELECT 
            ab.account_id,
            ab.account_name,
            ab.group_name,
            ab.primary_classification,
            -- Split opening into Dr and Cr
            CASE WHEN ab.net_opening > 0 THEN ab.net_opening ELSE 0.00 END AS opening_dr,
            CASE WHEN ab.net_opening < 0 THEN ABS(ab.net_opening) ELSE 0.00 END AS opening_cr,
            ab.period_dr,
            ab.period_cr,
            -- Split closing into Dr and Cr
            CASE WHEN ab.net_closing > 0 THEN ab.net_closing ELSE 0.00 END AS closing_dr,
            CASE WHEN ab.net_closing < 0 THEN ABS(ab.net_closing) ELSE 0.00 END AS closing_cr
        FROM account_balances ab
        WHERE (ab.net_opening <> 0 OR ab.period_dr <> 0 OR ab.period_cr <> 0 OR ab.net_closing <> 0)
    )
    SELECT jsonb_build_object(
        'from_date', p_from_date,
        'to_date', p_to_date,
        'total_opening_dr', COALESCE(SUM(er.opening_dr), 0.00),
        'total_opening_cr', COALESCE(SUM(er.opening_cr), 0.00),
        'total_period_dr', COALESCE(SUM(er.period_dr), 0.00),
        'total_period_cr', COALESCE(SUM(er.period_cr), 0.00),
        'total_closing_dr', COALESCE(SUM(er.closing_dr), 0.00),
        'total_closing_cr', COALESCE(SUM(er.closing_cr), 0.00),
        'is_balanced', (ROUND(COALESCE(SUM(er.closing_dr), 0.00), 2) = ROUND(COALESCE(SUM(er.closing_cr), 0.00), 2)),
        'lines', COALESCE(jsonb_agg(to_jsonb(er.*)), '[]'::JSONB)
    ) INTO v_result
    FROM evaluated_rows er;

    RETURN v_result;
END;
$$;

-- ------------------------------------------------------------------------------
-- 2. Profit & Loss Statement Stored Function (Trading + Income Statement)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_profit_and_loss(
    p_business_id UUID,
    p_from_date DATE,
    p_to_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_direct_income NUMERIC(15, 2) := 0.00;
    v_direct_expense NUMERIC(15, 2) := 0.00;
    v_gross_profit NUMERIC(15, 2) := 0.00;
    v_indirect_income NUMERIC(15, 2) := 0.00;
    v_indirect_expense NUMERIC(15, 2) := 0.00;
    v_net_profit NUMERIC(15, 2) := 0.00;
    v_income_lines JSONB;
    v_expense_lines JSONB;
BEGIN
    -- Direct Incomes (Sales Accounts, Direct Incomes)
    SELECT COALESCE(SUM(vli.amount), 0.00) INTO v_direct_income
    FROM public.voucher_line_items vli
    JOIN public.vouchers v ON v.id = vli.voucher_id
    JOIN public.accounts a ON a.id = vli.account_id
    WHERE v.business_id = p_business_id
      AND v.is_cancelled = FALSE
      AND v.voucher_date BETWEEN p_from_date AND p_to_date
      AND a.primary_classification = 'Income'
      AND a.group_name IN ('Sales Accounts', 'Direct Incomes')
      AND vli.entry_type = 'Cr';

    -- Direct Expenses (Purchase Accounts, Direct Expenses)
    SELECT COALESCE(SUM(vli.amount), 0.00) INTO v_direct_expense
    FROM public.voucher_line_items vli
    JOIN public.vouchers v ON v.id = vli.voucher_id
    JOIN public.accounts a ON a.id = vli.account_id
    WHERE v.business_id = p_business_id
      AND v.is_cancelled = FALSE
      AND v.voucher_date BETWEEN p_from_date AND p_to_date
      AND a.primary_classification = 'Expense'
      AND a.group_name IN ('Purchase Accounts', 'Direct Expenses')
      AND vli.entry_type = 'Dr';

    v_gross_profit := v_direct_income - v_direct_expense;

    -- Indirect Incomes
    SELECT COALESCE(SUM(vli.amount), 0.00) INTO v_indirect_income
    FROM public.voucher_line_items vli
    JOIN public.vouchers v ON v.id = vli.voucher_id
    JOIN public.accounts a ON a.id = vli.account_id
    WHERE v.business_id = p_business_id
      AND v.is_cancelled = FALSE
      AND v.voucher_date BETWEEN p_from_date AND p_to_date
      AND a.primary_classification = 'Income'
      AND a.group_name = 'Indirect Incomes'
      AND vli.entry_type = 'Cr';

    -- Indirect Expenses (Overheads, Depreciation, Interest)
    SELECT COALESCE(SUM(vli.amount), 0.00) INTO v_indirect_expense
    FROM public.voucher_line_items vli
    JOIN public.vouchers v ON v.id = vli.voucher_id
    JOIN public.accounts a ON a.id = vli.account_id
    WHERE v.business_id = p_business_id
      AND v.is_cancelled = FALSE
      AND v.voucher_date BETWEEN p_from_date AND p_to_date
      AND a.primary_classification = 'Expense'
      AND a.group_name = 'Indirect Expenses'
      AND vli.entry_type = 'Dr';

    v_net_profit := v_gross_profit + v_indirect_income - v_indirect_expense;

    -- Group-wise line item aggregation for Income & Expenses
    SELECT COALESCE(jsonb_agg(jsonb_build_object('account_name', a.name, 'group_name', a.group_name, 'amount', SUM(vli.amount))), '[]'::JSONB)
    INTO v_income_lines
    FROM public.voucher_line_items vli
    JOIN public.vouchers v ON v.id = vli.voucher_id
    JOIN public.accounts a ON a.id = vli.account_id
    WHERE v.business_id = p_business_id AND v.is_cancelled = FALSE AND v.voucher_date BETWEEN p_from_date AND p_to_date AND a.primary_classification = 'Income'
    GROUP BY a.name, a.group_name;

    SELECT COALESCE(jsonb_agg(jsonb_build_object('account_name', a.name, 'group_name', a.group_name, 'amount', SUM(vli.amount))), '[]'::JSONB)
    INTO v_expense_lines
    FROM public.voucher_line_items vli
    JOIN public.vouchers v ON v.id = vli.voucher_id
    JOIN public.accounts a ON a.id = vli.account_id
    WHERE v.business_id = p_business_id AND v.is_cancelled = FALSE AND v.voucher_date BETWEEN p_from_date AND p_to_date AND a.primary_classification = 'Expense'
    GROUP BY a.name, a.group_name;

    RETURN jsonb_build_object(
        'from_date', p_from_date,
        'to_date', p_to_date,
        'direct_incomes', v_direct_income,
        'direct_expenses', v_direct_expense,
        'gross_profit', v_gross_profit,
        'indirect_incomes', v_indirect_income,
        'indirect_expenses', v_indirect_expense,
        'net_profit', v_net_profit,
        'income_details', v_income_lines,
        'expense_details', v_expense_lines
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. Balance Sheet Stored Function (Schedule III Compliant)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_balance_sheet(
    p_business_id UUID,
    p_as_of_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_fy_start DATE;
    v_pnl JSONB;
    v_current_net_profit NUMERIC(15, 2) := 0.00;
    v_fixed_assets NUMERIC(15, 2) := 0.00;
    v_current_assets NUMERIC(15, 2) := 0.00;
    v_total_assets NUMERIC(15, 2) := 0.00;
    v_capital_equity NUMERIC(15, 2) := 0.00;
    v_loans_liability NUMERIC(15, 2) := 0.00;
    v_current_liabilities NUMERIC(15, 2) := 0.00;
    v_total_liabilities NUMERIC(15, 2) := 0.00;
    v_asset_details JSONB;
    v_liability_details JSONB;
BEGIN
    -- Determine Financial Year start date
    IF EXTRACT(MONTH FROM p_as_of_date) >= 4 THEN
        v_fy_start := MAKE_DATE(EXTRACT(YEAR FROM p_as_of_date)::INT, 4, 1);
    ELSE
        v_fy_start := MAKE_DATE((EXTRACT(YEAR FROM p_as_of_date) - 1)::INT, 4, 1);
    END IF;

    -- Compute dynamic Net Profit for the financial year up to as_of_date
    v_pnl := public.generate_profit_and_loss(p_business_id, v_fy_start, p_as_of_date);
    v_current_net_profit := COALESCE((v_pnl->>'net_profit')::NUMERIC, 0.00);

    -- Calculate Asset balances up to as_of_date
    WITH asset_calc AS (
        SELECT 
            a.name AS account_name,
            a.group_name,
            (
                (CASE WHEN a.opening_balance_type = 'Dr' THEN a.opening_balance ELSE -a.opening_balance END) +
                COALESCE(SUM(CASE WHEN vli.entry_type = 'Dr' THEN vli.amount ELSE -vli.amount END), 0.00)
            ) AS closing_bal
        FROM public.accounts a
        LEFT JOIN public.voucher_line_items vli ON vli.account_id = a.id
        LEFT JOIN public.vouchers v ON v.id = vli.voucher_id AND v.is_cancelled = FALSE AND v.voucher_date <= p_as_of_date
        WHERE a.business_id = p_business_id AND a.primary_classification = 'Asset' AND a.is_active = TRUE
        GROUP BY a.id, a.name, a.group_name, a.opening_balance_type, a.opening_balance
    )
    SELECT 
        COALESCE(SUM(CASE WHEN group_name = 'Fixed Assets' THEN closing_bal ELSE 0.00 END), 0.00),
        COALESCE(SUM(CASE WHEN group_name <> 'Fixed Assets' THEN closing_bal ELSE 0.00 END), 0.00),
        COALESCE(jsonb_agg(to_jsonb(asset_calc.*)), '[]'::JSONB)
    INTO v_fixed_assets, v_current_assets, v_asset_details
    FROM asset_calc;

    v_total_assets := v_fixed_assets + v_current_assets;

    -- Calculate Liability & Equity balances up to as_of_date
    WITH liab_calc AS (
        SELECT 
            a.name AS account_name,
            a.group_name,
            a.primary_classification,
            (
                (CASE WHEN a.opening_balance_type = 'Cr' THEN a.opening_balance ELSE -a.opening_balance END) +
                COALESCE(SUM(CASE WHEN vli.entry_type = 'Cr' THEN vli.amount ELSE -vli.amount END), 0.00)
            ) AS closing_bal
        FROM public.accounts a
        LEFT JOIN public.voucher_line_items vli ON vli.account_id = a.id
        LEFT JOIN public.vouchers v ON v.id = vli.voucher_id AND v.is_cancelled = FALSE AND v.voucher_date <= p_as_of_date
        WHERE a.business_id = p_business_id AND a.primary_classification IN ('Liability', 'Equity') AND a.is_active = TRUE
        GROUP BY a.id, a.name, a.group_name, a.primary_classification, a.opening_balance_type, a.opening_balance
    )
    SELECT 
        COALESCE(SUM(CASE WHEN primary_classification = 'Equity' OR group_name IN ('Capital Account', 'Reserves & Surplus') THEN closing_bal ELSE 0.00 END), 0.00),
        COALESCE(SUM(CASE WHEN group_name IN ('Loans (Liability)', 'Bank OD A/c', 'Secured Loans', 'Unsecured Loans') THEN closing_bal ELSE 0.00 END), 0.00),
        COALESCE(SUM(CASE WHEN group_name IN ('Current Liabilities', 'Sundry Creditors', 'Duties & Taxes', 'Provisions') THEN closing_bal ELSE 0.00 END), 0.00),
        COALESCE(jsonb_agg(to_jsonb(liab_calc.*)), '[]'::JSONB)
    INTO v_capital_equity, v_loans_liability, v_current_liabilities, v_liability_details
    FROM liab_calc;

    v_total_liabilities := (v_capital_equity + v_current_net_profit) + v_loans_liability + v_current_liabilities;

    RETURN jsonb_build_object(
        'as_of_date', p_as_of_date,
        'fixed_assets', v_fixed_assets,
        'current_assets', v_current_assets,
        'total_assets', v_total_assets,
        'capital_equity', v_capital_equity,
        'current_net_profit', v_current_net_profit,
        'total_equity_and_reserves', (v_capital_equity + v_current_net_profit),
        'loans_liability', v_loans_liability,
        'current_liabilities', v_current_liabilities,
        'total_liabilities_and_equity', v_total_liabilities,
        'difference', ROUND((v_total_assets - v_total_liabilities), 2),
        'is_balanced', (ROUND(v_total_assets, 2) = ROUND(v_total_liabilities, 2)),
        'asset_details', v_asset_details,
        'liability_details', v_liability_details
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 4. Cash Flow Statement Stored Function (AS 3 Direct Method)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_cash_flow_statement(
    p_business_id UUID,
    p_from_date DATE,
    p_to_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_operating_inflow NUMERIC(15, 2) := 0.00;
    v_operating_outflow NUMERIC(15, 2) := 0.00;
    v_investing_inflow NUMERIC(15, 2) := 0.00;
    v_investing_outflow NUMERIC(15, 2) := 0.00;
    v_financing_inflow NUMERIC(15, 2) := 0.00;
    v_financing_outflow NUMERIC(15, 2) := 0.00;
    v_opening_cash NUMERIC(15, 2) := 0.00;
    v_net_cash_flow NUMERIC(15, 2) := 0.00;
    v_closing_cash NUMERIC(15, 2) := 0.00;
BEGIN
    -- Opening Cash & Bank prior to from_date
    SELECT COALESCE(SUM(
        (CASE WHEN a.opening_balance_type = 'Dr' THEN a.opening_balance ELSE -a.opening_balance END) +
        COALESCE(tx.net_movement, 0.00)
    ), 0.00) INTO v_opening_cash
    FROM public.accounts a
    LEFT JOIN (
        SELECT vli.account_id, SUM(CASE WHEN vli.entry_type = 'Dr' THEN vli.amount ELSE -vli.amount END) AS net_movement
        FROM public.voucher_line_items vli
        JOIN public.vouchers v ON v.id = vli.voucher_id
        WHERE v.business_id = p_business_id AND v.is_cancelled = FALSE AND v.voucher_date < p_from_date
        GROUP BY vli.account_id
    ) tx ON tx.account_id = a.id
    WHERE a.business_id = p_business_id AND a.group_name IN ('Cash-in-Hand', 'Bank Accounts');

    -- Operating Activities: Customer receipts (Dr) vs Vendor/Tax/Salary payments (Cr)
    SELECT 
        COALESCE(SUM(CASE WHEN vli.entry_type = 'Dr' THEN vli.amount ELSE 0.00 END), 0.00),
        COALESCE(SUM(CASE WHEN vli.entry_type = 'Cr' THEN vli.amount ELSE 0.00 END), 0.00)
    INTO v_operating_inflow, v_operating_outflow
    FROM public.voucher_line_items vli
    JOIN public.vouchers v ON v.id = vli.voucher_id
    JOIN public.accounts a ON a.id = vli.account_id
    WHERE v.business_id = p_business_id AND v.is_cancelled = FALSE AND v.voucher_date BETWEEN p_from_date AND p_to_date
      AND a.group_name IN ('Cash-in-Hand', 'Bank Accounts');

    v_net_cash_flow := v_operating_inflow - v_operating_outflow;
    v_closing_cash := v_opening_cash + v_net_cash_flow;

    RETURN jsonb_build_object(
        'from_date', p_from_date,
        'to_date', p_to_date,
        'opening_cash_equivalents', v_opening_cash,
        'operating_inflows', v_operating_inflow,
        'operating_outflows', v_operating_outflow,
        'net_operating_cash_flow', (v_operating_inflow - v_operating_outflow),
        'investing_cash_flow', 0.00,
        'financing_cash_flow', 0.00,
        'net_cash_delta', v_net_cash_flow,
        'closing_cash_equivalents', v_closing_cash
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_trial_balance(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_profit_and_loss(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_balance_sheet(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_cash_flow_statement(UUID, DATE, DATE) TO authenticated;

COMMIT;
