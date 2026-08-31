-- ==============================================================================
-- Migration: 20260831000005_coa_masters_and_seeding.sql
-- Description: Chart of Accounts Seeding, Phonetic Triggers & Default Voucher Types
-- Specification: docs/04_core_accounting_engine_rules.md & docs/07_fuzzy_entity_matching_spec.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Phonetic Triggers for Accounts and Stock Items (Daitch-Mokotoff Sync)
-- Automatically calculates and indexes phonetic codes upon INSERT or name update
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_maintain_account_phonetic_codes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.daitch_mokotoff_code := daitch_mokotoff(NEW.name);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_accounts_phonetic_sync ON public.accounts;
CREATE TRIGGER trg_accounts_phonetic_sync
BEFORE INSERT OR UPDATE OF name ON public.accounts
FOR EACH ROW
EXECUTE FUNCTION public.trg_maintain_account_phonetic_codes();

CREATE OR REPLACE FUNCTION public.trg_maintain_stock_phonetic_codes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.daitch_mokotoff_code := daitch_mokotoff(NEW.name);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_stock_items_phonetic_sync ON public.stock_items;
CREATE TRIGGER trg_stock_items_phonetic_sync
BEFORE INSERT OR UPDATE OF name ON public.stock_items
FOR EACH ROW
EXECUTE FUNCTION public.trg_maintain_stock_phonetic_codes();

-- ------------------------------------------------------------------------------
-- 2. Seed Stored Procedure for the 28 Default Tally Standard Groups
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.seed_default_tally_groups(target_business_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.accounts (
        business_id, name, group_name, primary_classification, opening_balance_type, is_sub_ledger
    )
    VALUES
        -- Primary Equity
        (target_business_id, 'Capital Account', 'Primary', 'Equity', 'Cr', FALSE),
        (target_business_id, 'Reserves & Surplus', 'Capital Account', 'Equity', 'Cr', FALSE),

        -- Primary Assets & Sub-Groups
        (target_business_id, 'Current Assets', 'Primary', 'Asset', 'Dr', FALSE),
        (target_business_id, 'Bank Accounts', 'Current Assets', 'Asset', 'Dr', FALSE),
        (target_business_id, 'Cash-in-Hand', 'Current Assets', 'Asset', 'Dr', FALSE),
        (target_business_id, 'Deposits (Asset)', 'Current Assets', 'Asset', 'Dr', FALSE),
        (target_business_id, 'Loans & Advances (Asset)', 'Current Assets', 'Asset', 'Dr', FALSE),
        (target_business_id, 'Stock-in-Hand', 'Current Assets', 'Asset', 'Dr', FALSE),
        (target_business_id, 'Sundry Debtors', 'Current Assets', 'Asset', 'Dr', FALSE),
        (target_business_id, 'Fixed Assets', 'Primary', 'Asset', 'Dr', FALSE),
        (target_business_id, 'Investments', 'Primary', 'Asset', 'Dr', FALSE),
        (target_business_id, 'Misc. Expenses (ASSET)', 'Primary', 'Asset', 'Dr', FALSE),
        (target_business_id, 'Suspense A/c', 'Primary', 'Asset', 'Dr', FALSE),

        -- Primary Liabilities & Sub-Groups
        (target_business_id, 'Current Liabilities', 'Primary', 'Liability', 'Cr', FALSE),
        (target_business_id, 'Duties & Taxes', 'Current Liabilities', 'Liability', 'Cr', FALSE),
        (target_business_id, 'Provisions', 'Current Liabilities', 'Liability', 'Cr', FALSE),
        (target_business_id, 'Sundry Creditors', 'Current Liabilities', 'Liability', 'Cr', FALSE),
        (target_business_id, 'Loans (Liability)', 'Primary', 'Liability', 'Cr', FALSE),
        (target_business_id, 'Bank OD A/c', 'Loans (Liability)', 'Liability', 'Cr', FALSE),
        (target_business_id, 'Secured Loans', 'Loans (Liability)', 'Liability', 'Cr', FALSE),
        (target_business_id, 'Unsecured Loans', 'Loans (Liability)', 'Liability', 'Cr', FALSE),
        (target_business_id, 'Branch / Divisions', 'Primary', 'Liability', 'Cr', FALSE),

        -- Primary Incomes
        (target_business_id, 'Direct Incomes', 'Primary', 'Income', 'Cr', FALSE),
        (target_business_id, 'Sales Accounts', 'Direct Incomes', 'Income', 'Cr', FALSE),
        (target_business_id, 'Indirect Incomes', 'Primary', 'Income', 'Cr', FALSE),

        -- Primary Expenses
        (target_business_id, 'Direct Expenses', 'Primary', 'Expense', 'Dr', FALSE),
        (target_business_id, 'Purchase Accounts', 'Direct Expenses', 'Expense', 'Dr', FALSE),
        (target_business_id, 'Indirect Expenses', 'Primary', 'Expense', 'Dr', FALSE)
    ON CONFLICT (business_id, name) DO NOTHING;
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. Automatic Seeding Trigger on Tenant Company Creation
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_handle_new_tenant_seed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    PERFORM public.seed_default_tally_groups(NEW.id);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_seed_tenant_tally_groups ON public.tenants;
CREATE TRIGGER trg_seed_tenant_tally_groups
AFTER INSERT ON public.tenants
FOR EACH ROW
EXECUTE FUNCTION public.trg_handle_new_tenant_seed();

-- ------------------------------------------------------------------------------
-- 4. Default System Master Voucher Types (is_system_default = TRUE)
-- ------------------------------------------------------------------------------
INSERT INTO public.voucher_types (name, category, is_system_default, e_invoice_applicable, numbering_method, restart_numbering_period)
VALUES
    ('Sales', 'Sales', TRUE, TRUE, 'Automatic', 'Yearly'),
    ('Purchase', 'Purchase', TRUE, FALSE, 'Automatic', 'Yearly'),
    ('Payment', 'Payment', TRUE, FALSE, 'Automatic', 'Yearly'),
    ('Receipt', 'Receipt', TRUE, FALSE, 'Automatic', 'Yearly'),
    ('Contra', 'Contra', TRUE, FALSE, 'Automatic', 'Yearly'),
    ('Journal', 'Journal', TRUE, FALSE, 'Automatic', 'Yearly'),
    ('Debit Note', 'Debit Note', TRUE, TRUE, 'Automatic', 'Yearly'),
    ('Credit Note', 'Credit Note', TRUE, TRUE, 'Automatic', 'Yearly'),
    ('Stock Journal', 'Stock Journal', TRUE, FALSE, 'Automatic', 'Yearly'),
    ('Physical Stock', 'Physical Stock', TRUE, FALSE, 'Automatic', 'Yearly')
ON CONFLICT DO NOTHING;

COMMIT;
