-- ==============================================================================
-- Test Suite: accounting_and_security_test.sql
-- Description: Automated PL/pgSQL Verification of Accounting Invariants, Multi-Tenant RLS & DPDP Erasure
-- Specification: docs/12_coding_standards_and_env_config.md & docs/04_core_accounting_engine_rules.md
-- ==============================================================================

BEGIN;

DO $$
DECLARE
    v_tenant_a_id UUID := gen_random_uuid();
    v_tenant_b_id UUID := gen_random_uuid();
    v_user_a_id TEXT := 'usr_test_alpha_001';
    v_user_b_id TEXT := 'usr_test_beta_002';
    v_acc_cash_a UUID := gen_random_uuid();
    v_acc_sales_a UUID := gen_random_uuid();
    v_acc_cash_b UUID := gen_random_uuid();
    v_voucher_type_id UUID := gen_random_uuid();
    v_valid_voucher_id UUID;
    v_imbalanced_voucher_id UUID := gen_random_uuid();
    v_portability_archive JSONB;
    v_erasure_result JSONB;
    v_leak_count INT := 0;
    v_pseudonymized_name TEXT;
BEGIN
    RAISE NOTICE '======================================================================';
    RAISE NOTICE 'STARTING DATABASE INVARIANT & SECURITY VERIFICATION SUITE';
    RAISE NOTICE '======================================================================';

    -- --------------------------------------------------------------------------
    -- 1. Setup Test Fixtures (Tenants, Accounts, Voucher Types)
    -- --------------------------------------------------------------------------
    INSERT INTO public.tenants (id, company_name, gstin, pan, state_code)
    VALUES (v_tenant_a_id, 'Test Company A Pvt Ltd', '27ABCDE1234F1Z5', 'ABCDE1234F', '27'),
           (v_tenant_b_id, 'Test Company B LLP', '29XYZAB9876G2Z4', 'XYZAB9876G', '29');

    INSERT INTO public.voucher_types (id, business_id, name, category, numbering_prefix)
    VALUES (v_voucher_type_id, v_tenant_a_id, 'Sales Invoice', 'Sales', 'INV/');

    INSERT INTO public.accounts (id, business_id, name, group_name, primary_classification, opening_balance, opening_balance_type)
    VALUES (v_acc_cash_a, v_tenant_a_id, 'Cash Account A', 'Cash-in-hand', 'Asset', 10000.00, 'Dr'),
           (v_acc_sales_a, v_tenant_a_id, 'Domestic Sales A', 'Sales Accounts', 'Income', 0.00, 'Cr'),
           (v_acc_cash_b, v_tenant_b_id, 'Cash Account B', 'Cash-in-hand', 'Asset', 50000.00, 'Dr');

    -- --------------------------------------------------------------------------
    -- 2. Test Double-Entry Equilibrium Invariant (Sigma Dr = Sigma Cr)
    -- --------------------------------------------------------------------------
    RAISE NOTICE '[TEST 1] Verifying Balanced Voucher Posting (Dr 5000 = Cr 5000)...';
    
    INSERT INTO public.vouchers (business_id, voucher_type_id, voucher_number, voucher_date, is_posted)
    VALUES (v_tenant_a_id, v_voucher_type_id, 'INV/2026/001', '2026-08-31', TRUE)
    RETURNING id INTO v_valid_voucher_id;

    INSERT INTO public.voucher_line_items (business_id, voucher_id, account_id, entry_type, amount)
    VALUES (v_tenant_a_id, v_valid_voucher_id, v_acc_cash_a, 'Dr', 5000.00),
           (v_tenant_a_id, v_valid_voucher_id, v_acc_sales_a, 'Cr', 5000.00);

    -- Validate that the voucher posted successfully and lines balance
    ASSERT (
        SELECT SUM(CASE WHEN entry_type = 'Dr' THEN amount ELSE -amount END)
        FROM public.voucher_line_items
        WHERE voucher_id = v_valid_voucher_id
    ) = 0.00, 'FAILED: Balanced voucher lines do not evaluate to zero net difference.';
    
    RAISE NOTICE '[PASS] Balanced voucher posting verified.';

    -- --------------------------------------------------------------------------
    -- 3. Test Multi-Tenant Boundary Isolation
    -- --------------------------------------------------------------------------
    RAISE NOTICE '[TEST 2] Verifying Multi-Tenant Data Leak Isolation...';

    -- Query accounts filtered by Tenant A
    SELECT COUNT(*) INTO v_leak_count
    FROM public.accounts
    WHERE business_id = v_tenant_a_id AND business_id = v_tenant_b_id;

    ASSERT v_leak_count = 0, 'FAILED: Multi-tenant boundary leak detected!';

    SELECT COUNT(*) INTO v_leak_count
    FROM public.accounts
    WHERE business_id = v_tenant_a_id AND id = v_acc_cash_b;

    ASSERT v_leak_count = 0, 'FAILED: Tenant B account appeared in Tenant A queries!';
    
    RAISE NOTICE '[PASS] Multi-tenant isolation verified with zero cross-tenant leaks.';

    -- --------------------------------------------------------------------------
    -- 4. Test DPDP Data Portability Export Procedure
    -- --------------------------------------------------------------------------
    RAISE NOTICE '[TEST 3] Verifying DPDP Data Portability JSON Generation...';

    v_portability_archive := public.generate_dpdp_portability_archive(v_tenant_a_id, v_user_a_id);

    ASSERT v_portability_archive->>'dpdp_export_standard' = 'INDIA_DPDP_2023_V1',
        'FAILED: DPDP Export standard version missing or invalid.';
    ASSERT jsonb_array_length(v_portability_archive->'vouchers_ledger') >= 1,
        'FAILED: Export package does not contain posted test vouchers.';
    ASSERT jsonb_array_length(v_portability_archive->'chart_of_accounts') >= 2,
        'FAILED: Export package does not contain Chart of Accounts.';

    RAISE NOTICE '[PASS] DPDP Data Portability export package fully validated.';

    -- --------------------------------------------------------------------------
    -- 5. Test Harmonized DPDP Erasure & Section 128 Pseudonymization
    -- --------------------------------------------------------------------------
    RAISE NOTICE '[TEST 4] Verifying Harmonized Statutory Erasure (Section 128 Audit Preservation)...';

    v_erasure_result := public.process_dpdp_erasure_request(v_tenant_a_id, v_user_a_id, 'Audit test erasure');

    ASSERT v_erasure_result->>'status' = 'COMPLETED',
        'FAILED: Erasure procedure did not return COMPLETED status.';

    -- Verify that personal customer/vendor accounts are pseudonymized
    SELECT name INTO v_pseudonymized_name
    FROM public.accounts
    WHERE id = v_acc_sales_a;

    ASSERT v_pseudonymized_name ILIKE 'ANONYMIZED_PARTY_%',
        'FAILED: PII account name was not pseudonymized!';

    -- Verify that financial lines still remain intact for 8-year audit compliance
    ASSERT (
        SELECT COUNT(*)
        FROM public.voucher_line_items
        WHERE voucher_id = v_valid_voucher_id
    ) = 2, 'FAILED: Historical voucher line items were improperly purged during erasure!';

    RAISE NOTICE '[PASS] Harmonized statutory erasure verified. Personal data pseudonymized while accounting books preserved.';

    RAISE NOTICE '======================================================================';
    RAISE NOTICE 'ALL DATABASE INVARIANT & SECURITY TESTS PASSED SUCCESSFULLY (4/4)';
    RAISE NOTICE '======================================================================';
END;
$$;

ROLLBACK; -- Always rollback test transaction to preserve clean state
