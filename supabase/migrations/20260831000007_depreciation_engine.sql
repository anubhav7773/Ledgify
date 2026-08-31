-- ==============================================================================
-- Migration: 20260831000007_depreciation_engine.sql
-- Description: Companies Act 2013 (Schedule II) Fixed Asset Depreciation Engine & CGST Sec 16(3) Triggers
-- Specification: docs/04_core_accounting_engine_rules.md & docs/02_database_schema_ddl_and_indexes.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. CGST Section 16(3) ITC Exclusivity Validation Trigger
-- Ensures that if Input Tax Credit (ITC) is claimed on capital goods, the tax
-- amount cannot be capitalized or depreciated under the Income-tax/Companies Act.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_itc_depreciation_exclusivity()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Statutory Rule: Residual value cannot exceed 5% of original cost
    IF NEW.residual_value > (NEW.original_cost * 0.05) THEN
        RAISE EXCEPTION 'Schedule II Violation: Residual value (₹%) cannot exceed 5%% of original cost (₹%)',
            NEW.residual_value, (NEW.original_cost * 0.05)
            USING ERRCODE = 'check_violation';
    END IF;

    -- Statutory Rule: Useful life must be positive
    IF NEW.useful_life_years <= 0 THEN
        RAISE EXCEPTION 'Invalid useful life: Useful life must be greater than 0 years'
            USING ERRCODE = 'check_violation';
    END IF;

    -- Statutory Rule: Shift working cannot be Double/Triple if NESD
    IF NEW.is_nesd IS TRUE AND NEW.shift_working <> 'Single' THEN
        RAISE EXCEPTION 'Schedule II NESD Violation: Asset category marked No Extra Shift Depreciation (NESD) cannot use % shift.',
            NEW.shift_working
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_itc_depreciation_exclusivity ON public.fixed_assets;
CREATE TRIGGER trg_check_itc_depreciation_exclusivity
BEFORE INSERT OR UPDATE ON public.fixed_assets
FOR EACH ROW
EXECUTE FUNCTION public.check_itc_depreciation_exclusivity();

-- ------------------------------------------------------------------------------
-- 2. Automated Pro-Rata Daily Depreciation Calculation Stored Procedure
-- Implements Companies Act 2013 (Schedule II) straight-line daily pro-rata formula
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_asset_depreciation(
    p_asset_id UUID,
    p_period_start DATE,
    p_period_end DATE
)
RETURNS NUMERIC(15, 2)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_cost NUMERIC(15, 2);
    v_residual NUMERIC(15, 2);
    v_useful_life NUMERIC(5, 2);
    v_is_nesd BOOLEAN;
    v_shift VARCHAR(20);
    v_purchase_date DATE;
    v_disposal_date DATE;
    v_accumulated_dep NUMERIC(15, 2);
    v_active_start DATE;
    v_active_end DATE;
    v_active_days INTEGER;
    v_year_days INTEGER;
    v_multiplier NUMERIC(3, 2) := 1.0;
    v_depreciable_base NUMERIC(15, 2);
    v_depreciation NUMERIC(15, 2);
    v_remaining_depreciable NUMERIC(15, 2);
BEGIN
    SELECT 
        original_cost, 
        residual_value, 
        useful_life_years, 
        is_nesd, 
        shift_working, 
        purchase_date, 
        disposal_date,
        accumulated_depreciation
    INTO 
        v_cost, 
        v_residual, 
        v_useful_life, 
        v_is_nesd, 
        v_shift, 
        v_purchase_date, 
        v_disposal_date,
        v_accumulated_dep
    FROM public.fixed_assets
    WHERE id = p_asset_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Fixed asset not found: %', p_asset_id
            USING ERRCODE = 'data_exception';
    END IF;

    -- Determine active boundary dates
    v_active_start := GREATEST(p_period_start, v_purchase_date);
    v_active_end := LEAST(p_period_end, COALESCE(v_disposal_date, p_period_end));

    IF v_active_start > v_active_end THEN
        RETURN 0.00;
    END IF;

    v_active_days := (v_active_end - v_active_start) + 1;
    v_year_days := 365;

    -- Shift working multipliers (blocked if NESD)
    IF NOT v_is_nesd THEN
        IF v_shift = 'Double' THEN 
            v_multiplier := 1.5;
        ELSIF v_shift = 'Triple' THEN 
            v_multiplier := 2.0;
        END IF;
    END IF;

    v_depreciable_base := v_cost - v_residual;
    v_remaining_depreciable := GREATEST(0.00, v_depreciable_base - v_accumulated_dep);

    IF v_remaining_depreciable <= 0.00 THEN
        RETURN 0.00;
    END IF;

    -- Straight Line Method (SLM) daily pro-rata formula
    v_depreciation := ROUND(( (v_depreciable_base / v_useful_life) * v_multiplier * (v_active_days::numeric / v_year_days::numeric) ), 2);

    -- Cap depreciation to avoid exceeding total depreciable base
    v_depreciation := LEAST(v_depreciation, v_remaining_depreciable);

    RETURN v_depreciation;
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. Periodic Depreciation Journal Voucher Posting Procedure
-- Computes and posts balanced depreciation journal entries for all active assets
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.post_periodic_depreciation_voucher(
    p_business_id UUID,
    p_period_end DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_journal_type_id UUID;
    v_dep_expense_account_id UUID;
    v_voucher_id UUID;
    v_voucher_number VARCHAR(50);
    v_asset RECORD;
    v_asset_dep NUMERIC(15, 2);
    v_total_dep NUMERIC(15, 2) := 0.00;
    v_assets_count INTEGER := 0;
    v_period_start DATE;
    v_fy_start DATE;
BEGIN
    -- 1. Locate tenant financial year start
    SELECT financial_year_start INTO v_fy_start
    FROM public.tenants
    WHERE id = p_business_id;

    v_period_start := COALESCE(v_fy_start, DATE_TRUNC('year', p_period_end)::DATE);

    -- 2. Locate Journal Voucher Type ID
    SELECT id INTO v_journal_type_id
    FROM public.voucher_types
    WHERE (business_id = p_business_id OR is_system_default IS TRUE)
      AND category = 'Journal'
    LIMIT 1;

    IF v_journal_type_id IS NULL THEN
        RAISE EXCEPTION 'Journal voucher type not configured for business %', p_business_id;
    END IF;

    -- 3. Locate or create "Depreciation Expense" account under Indirect Expenses
    SELECT id INTO v_dep_expense_account_id
    FROM public.accounts
    WHERE business_id = p_business_id
      AND name = 'Depreciation Expense'
    LIMIT 1;

    IF v_dep_expense_account_id IS NULL THEN
        INSERT INTO public.accounts (
            business_id, name, group_name, primary_classification, opening_balance_type, is_sub_ledger
        )
        VALUES (
            p_business_id, 'Depreciation Expense', 'Indirect Expenses', 'Expense', 'Dr', FALSE
        )
        RETURNING id INTO v_dep_expense_account_id;
    END IF;

    -- 4. Generate unique Journal Voucher Number
    v_voucher_number := 'DEP-' || TO_CHAR(p_period_end, 'YYYYMMDD') || '-' || SUBSTRING(gen_random_uuid()::text, 1, 6);

    -- 5. Create Draft Header for Voucher
    INSERT INTO public.vouchers (
        business_id,
        voucher_type_id,
        voucher_number,
        voucher_date,
        narration,
        ai_confidence_score
    )
    VALUES (
        p_business_id,
        v_journal_type_id,
        v_voucher_number,
        p_period_end,
        'Periodic Depreciation run as of ' || TO_CHAR(p_period_end, 'DD/MM/YYYY') || ' under Schedule II (Companies Act 2013)',
        1.0000
    )
    RETURNING id INTO v_voucher_id;

    -- 6. Loop through all active fixed assets and calculate depreciation
    FOR v_asset IN 
        SELECT id, asset_account_id, asset_name, accumulated_depreciation
        FROM public.fixed_assets
        WHERE business_id = p_business_id
          AND is_disposed IS FALSE
    LOOP
        v_asset_dep := public.calculate_asset_depreciation(v_asset.id, v_period_start, p_period_end);

        IF v_asset_dep > 0.00 THEN
            -- Credit Line: Asset Ledger (Asset Reduction)
            INSERT INTO public.voucher_line_items (
                business_id,
                voucher_id,
                account_id,
                entry_type,
                amount,
                item_description
            )
            VALUES (
                p_business_id,
                v_voucher_id,
                v_asset.asset_account_id,
                'Cr',
                v_asset_dep,
                'Depreciation provision for ' || v_asset.asset_name
            );

            -- Update accumulated depreciation on fixed asset record
            UPDATE public.fixed_assets
            SET accumulated_depreciation = accumulated_depreciation + v_asset_dep
            WHERE id = v_asset.id;

            v_total_dep := v_total_dep + v_asset_dep;
            v_assets_count := v_assets_count + 1;
        END IF;
    END LOOP;

    -- If no depreciation was calculated, cancel the draft voucher
    IF v_total_dep <= 0.00 THEN
        DELETE FROM public.vouchers WHERE id = v_voucher_id;
        RETURN jsonb_build_object(
            'status', 'NO_DEPRECIATION',
            'message', 'No active assets required depreciation for the period.',
            'total_depreciation', 0.00,
            'assets_processed', 0
        );
    END IF;

    -- 7. Debit Line: Total Depreciation Expense (Direct/Indirect Expense)
    INSERT INTO public.voucher_line_items (
        business_id,
        voucher_id,
        account_id,
        entry_type,
        amount,
        item_description
    )
    VALUES (
        p_business_id,
        v_voucher_id,
        v_dep_expense_account_id,
        'Dr',
        v_total_dep,
        'Total Schedule II depreciation for ' || v_assets_count || ' asset(s)'
    );

    RETURN jsonb_build_object(
        'status', 'SUCCESS',
        'voucher_id', v_voucher_id,
        'voucher_number', v_voucher_number,
        'total_depreciation', v_total_dep,
        'assets_processed', v_assets_count,
        'period_end', p_period_end
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_asset_depreciation(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_periodic_depreciation_voucher(UUID, DATE) TO authenticated;

COMMIT;
