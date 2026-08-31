-- ==============================================================================
-- Migration: 20260831000019_statutory_registers_and_stock.sql
-- Description: Statutory Accounting Registers (Day Book, Sales/Purchase Register, Ledger Statement with Running Balance, Stock Summary)
-- Specification: docs/04_core_accounting_engine_rules.md & docs/02_database_schema_ddl_and_indexes.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Day Book Aggregation Stored Function
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_day_book(
    p_business_id UUID,
    p_date DATE,
    p_voucher_type_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    WITH voucher_entries AS (
        SELECT 
            v.id AS voucher_id,
            v.voucher_number,
            vt.name AS voucher_type_name,
            v.voucher_date,
            v.reference_number,
            v.narration,
            v.is_cancelled,
            COALESCE((
                SELECT SUM(vli.amount) 
                FROM public.voucher_line_items vli 
                WHERE vli.voucher_id = v.id AND vli.entry_type = 'Dr'
            ), 0.00) AS total_amount,
            COALESCE((
                SELECT jsonb_agg(jsonb_build_object(
                    'account_id', vli.account_id,
                    'account_name', a.name,
                    'entry_type', vli.entry_type,
                    'amount', vli.amount,
                    'item_description', vli.item_description
                ))
                FROM public.voucher_line_items vli
                JOIN public.accounts a ON a.id = vli.account_id
                WHERE vli.voucher_id = v.id
            ), '[]'::JSONB) AS line_items
        FROM public.vouchers v
        JOIN public.voucher_types vt ON vt.id = v.voucher_type_id
        WHERE v.business_id = p_business_id
          AND v.voucher_date = p_date
          AND (p_voucher_type_id IS NULL OR v.voucher_type_id = p_voucher_type_id)
        ORDER BY v.created_at ASC
    )
    SELECT jsonb_build_object(
        'date', p_date,
        'total_vouchers', COUNT(ve.voucher_id),
        'total_turnover', COALESCE(SUM(ve.total_amount), 0.00),
        'vouchers', COALESCE(jsonb_agg(to_jsonb(ve.*)), '[]'::JSONB)
    ) INTO v_result
    FROM voucher_entries ve;

    RETURN v_result;
END;
$$;

-- ------------------------------------------------------------------------------
-- 2. Sales & Purchase Trade Register Stored Function
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_trade_register(
    p_business_id UUID,
    p_register_type VARCHAR(10), -- 'SALES' or 'PURCHASE'
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
    WITH register_vouchers AS (
        SELECT 
            v.id AS voucher_id,
            v.voucher_number,
            v.voucher_date,
            party_acc.id AS party_account_id,
            party_acc.name AS party_name,
            party_acc.gstin AS party_gstin,
            v.reference_number,
            v.irn,
            v.e_way_bill_no,
            -- Line Items Breakdown
            COALESCE((
                SELECT SUM(vli.amount)
                FROM public.voucher_line_items vli
                JOIN public.accounts a ON a.id = vli.account_id
                WHERE vli.voucher_id = v.id 
                  AND a.primary_classification = (CASE WHEN p_register_type = 'SALES' THEN 'Income' ELSE 'Expense' END)
            ), 0.00) AS taxable_value,
            COALESCE((
                SELECT SUM(vli.amount)
                FROM public.voucher_line_items vli
                JOIN public.accounts a ON a.id = vli.account_id
                WHERE vli.voucher_id = v.id AND a.name ILIKE '%CGST%'
            ), 0.00) AS cgst_amount,
            COALESCE((
                SELECT SUM(vli.amount)
                FROM public.voucher_line_items vli
                JOIN public.accounts a ON a.id = vli.account_id
                WHERE vli.voucher_id = v.id AND a.name ILIKE '%SGST%'
            ), 0.00) AS sgst_amount,
            COALESCE((
                SELECT SUM(vli.amount)
                FROM public.voucher_line_items vli
                JOIN public.accounts a ON a.id = vli.account_id
                WHERE vli.voucher_id = v.id AND a.name ILIKE '%IGST%'
            ), 0.00) AS igst_amount,
            COALESCE((
                SELECT SUM(vli.amount)
                FROM public.voucher_line_items vli
                WHERE vli.voucher_id = v.id AND vli.entry_type = (CASE WHEN p_register_type = 'SALES' THEN 'Dr' ELSE 'Cr' END)
            ), 0.00) AS net_total
        FROM public.vouchers v
        JOIN public.voucher_types vt ON vt.id = v.voucher_type_id
        LEFT JOIN LATERAL (
            SELECT a.id, a.name, a.gstin
            FROM public.voucher_line_items vli
            JOIN public.accounts a ON a.id = vli.account_id
            WHERE vli.voucher_id = v.id 
              AND vli.entry_type = (CASE WHEN p_register_type = 'SALES' THEN 'Dr' ELSE 'Cr' END)
            LIMIT 1
        ) party_acc ON TRUE
        WHERE v.business_id = p_business_id
          AND v.is_cancelled = FALSE
          AND v.voucher_date BETWEEN p_from_date AND p_to_date
          AND vt.category = (CASE WHEN p_register_type = 'SALES' THEN 'Sales' ELSE 'Purchase' END)
        ORDER BY v.voucher_date ASC, v.created_at ASC
    )
    SELECT jsonb_build_object(
        'register_type', p_register_type,
        'from_date', p_from_date,
        'to_date', p_to_date,
        'total_count', COUNT(rv.voucher_id),
        'total_taxable_value', COALESCE(SUM(rv.taxable_value), 0.00),
        'total_cgst', COALESCE(SUM(rv.cgst_amount), 0.00),
        'total_sgst', COALESCE(SUM(rv.sgst_amount), 0.00),
        'total_igst', COALESCE(SUM(rv.igst_amount), 0.00),
        'total_net_amount', COALESCE(SUM(rv.net_total), 0.00),
        'entries', COALESCE(jsonb_agg(to_jsonb(rv.*)), '[]'::JSONB)
    ) INTO v_result
    FROM register_vouchers rv;

    RETURN v_result;
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. Ledger Statement with Windowed Running Balance Stored Function
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_ledger_statement(
    p_business_id UUID,
    p_account_id UUID,
    p_from_date DATE,
    p_to_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_acc_name TEXT;
    v_acc_group TEXT;
    v_opening_net NUMERIC(15, 2) := 0.00;
    v_prior_txns NUMERIC(15, 2) := 0.00;
    v_effective_opening NUMERIC(15, 2) := 0.00;
    v_effective_op_type VARCHAR(2) := 'Dr';
    v_result JSONB;
BEGIN
    -- 1. Fetch account master details
    SELECT 
        name, group_name,
        CASE WHEN opening_balance_type = 'Dr' THEN opening_balance ELSE -opening_balance END
    INTO v_acc_name, v_acc_group, v_opening_net
    FROM public.accounts
    WHERE id = p_account_id AND business_id = p_business_id;

    -- 2. Net prior movements before p_from_date
    SELECT COALESCE(SUM(CASE WHEN vli.entry_type = 'Dr' THEN vli.amount ELSE -vli.amount END), 0.00)
    INTO v_prior_txns
    FROM public.voucher_line_items vli
    JOIN public.vouchers v ON v.id = vli.voucher_id
    WHERE v.business_id = p_business_id
      AND vli.account_id = p_account_id
      AND v.is_cancelled = FALSE
      AND v.voucher_date < p_from_date;

    v_effective_opening := v_opening_net + v_prior_txns;
    IF v_effective_opening >= 0 THEN
        v_effective_op_type := 'Dr';
    ELSE
        v_effective_op_type := 'Cr';
        v_effective_opening := ABS(v_effective_opening);
    END IF;

    -- 3. Fetch line items and compute running balance
    WITH statement_rows AS (
        SELECT 
            v.id AS voucher_id,
            v.voucher_date,
            vt.name AS voucher_type,
            v.voucher_number,
            contra.contra_name AS particulars,
            CASE WHEN vli.entry_type = 'Dr' THEN vli.amount ELSE 0.00 END AS debit_amount,
            CASE WHEN vli.entry_type = 'Cr' THEN vli.amount ELSE 0.00 END AS credit_amount,
            vli.item_description,
            v.created_at
        FROM public.voucher_line_items vli
        JOIN public.vouchers v ON v.id = vli.voucher_id
        JOIN public.voucher_types vt ON vt.id = v.voucher_type_id
        LEFT JOIN LATERAL (
            SELECT STRING_AGG(a2.name, ', ') AS contra_name
            FROM public.voucher_line_items vli2
            JOIN public.accounts a2 ON a2.id = vli2.account_id
            WHERE vli2.voucher_id = v.id AND vli2.account_id <> p_account_id
        ) contra ON TRUE
        WHERE v.business_id = p_business_id
          AND vli.account_id = p_account_id
          AND v.is_cancelled = FALSE
          AND v.voucher_date BETWEEN p_from_date AND p_to_date
        ORDER BY v.voucher_date ASC, v.created_at ASC
    ),
    running_calc AS (
        SELECT 
            sr.*,
            (
                (CASE WHEN v_effective_op_type = 'Dr' THEN v_effective_opening ELSE -v_effective_opening END) +
                SUM(sr.debit_amount - sr.credit_amount) OVER (ORDER BY sr.voucher_date ASC, sr.created_at ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
            ) AS cumulative_bal
        FROM statement_rows sr
    ),
    formatted_rows AS (
        SELECT 
            rc.voucher_id,
            rc.voucher_date,
            rc.voucher_type,
            rc.voucher_number,
            rc.particulars,
            rc.debit_amount,
            rc.credit_amount,
            rc.item_description,
            ABS(rc.cumulative_bal) AS running_balance,
            CASE WHEN rc.cumulative_bal >= 0 THEN 'Dr' ELSE 'Cr' END AS running_balance_type
        FROM running_calc rc
    )
    SELECT jsonb_build_object(
        'account_id', p_account_id,
        'account_name', v_acc_name,
        'group_name', v_acc_group,
        'from_date', p_from_date,
        'to_date', p_to_date,
        'opening_balance', v_effective_opening,
        'opening_balance_type', v_effective_op_type,
        'total_debit', COALESCE(SUM(fr.debit_amount), 0.00),
        'total_credit', COALESCE(SUM(fr.credit_amount), 0.00),
        'entries', COALESCE(jsonb_agg(to_jsonb(fr.*)), '[]'::JSONB)
    ) INTO v_result
    FROM formatted_rows fr;

    RETURN v_result;
END;
$$;

-- ------------------------------------------------------------------------------
-- 4. Stock Valuation Summary Stored Function
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_stock_summary(
    p_business_id UUID,
    p_as_of_date DATE,
    p_group_id UUID DEFAULT NULL,
    p_godown_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    WITH stock_items_calc AS (
        SELECT 
            si.id AS stock_item_id,
            si.name AS stock_item_name,
            si.hsn_or_sac_code,
            sg.name AS group_name,
            u.symbol AS uom_symbol,
            si.opening_balance_quantity AS opening_qty,
            si.opening_balance_rate AS opening_rate,
            (si.opening_balance_quantity * si.opening_balance_rate) AS opening_val,
            si.current_stock_quantity AS closing_qty,
            si.standard_cost AS closing_rate,
            (si.current_stock_quantity * si.standard_cost) AS closing_val
        FROM public.stock_items si
        LEFT JOIN public.stock_groups_categories sg ON sg.id = si.stock_group_id
        LEFT JOIN public.units_of_measure u ON u.id = si.uom_id
        WHERE si.business_id = p_business_id
          AND (p_group_id IS NULL OR si.stock_group_id = p_group_id)
        ORDER BY si.name ASC
    )
    SELECT jsonb_build_object(
        'as_of_date', p_as_of_date,
        'total_items', COUNT(sic.stock_item_id),
        'total_inventory_value', COALESCE(SUM(sic.closing_val), 0.00),
        'items', COALESCE(jsonb_agg(to_jsonb(sic.*)), '[]'::JSONB)
    ) INTO v_result
    FROM stock_items_calc sic;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_day_book(UUID, DATE, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_trade_register(UUID, VARCHAR, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_ledger_statement(UUID, UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_stock_summary(UUID, DATE, UUID, UUID) TO authenticated;

COMMIT;
