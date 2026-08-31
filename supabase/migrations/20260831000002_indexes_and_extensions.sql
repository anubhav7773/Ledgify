-- ==============================================================================
-- Migration: 20260831000002_indexes_and_extensions.sql
-- Description: Performance Indexing Blueprint for Ledgify
-- Specification: docs/02_database_schema_ddl_and_indexes.md & docs/07_fuzzy_entity_matching_spec.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Standard B-Tree Indexes on RLS Tenant Filter (`business_id` & `user_id`)
-- Prevents sequential table scans when RLS evaluates tenant isolation queries
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_accounts_business_id 
    ON public.accounts(business_id);

CREATE INDEX IF NOT EXISTS idx_vouchers_business_id 
    ON public.vouchers(business_id);

CREATE INDEX IF NOT EXISTS idx_voucher_line_items_business_id 
    ON public.voucher_line_items(business_id);

CREATE INDEX IF NOT EXISTS idx_fixed_assets_business_id 
    ON public.fixed_assets(business_id);

CREATE INDEX IF NOT EXISTS idx_einvoice_logs_business_id 
    ON public.einvoice_logs(business_id);

CREATE INDEX IF NOT EXISTS idx_eway_bills_business_id 
    ON public.eway_bills(business_id);

CREATE INDEX IF NOT EXISTS idx_gstr_returns_ims_business_id 
    ON public.gstr_returns_ims(business_id);

CREATE INDEX IF NOT EXISTS idx_stock_groups_categories_business_id 
    ON public.stock_groups_categories(business_id);

CREATE INDEX IF NOT EXISTS idx_stock_items_business_id 
    ON public.stock_items(business_id);

CREATE INDEX IF NOT EXISTS idx_godowns_business_id 
    ON public.godowns(business_id);

CREATE INDEX IF NOT EXISTS idx_stock_batches_business_id 
    ON public.stock_batches(business_id);

CREATE INDEX IF NOT EXISTS idx_bank_accounts_business_id 
    ON public.bank_accounts(business_id);

CREATE INDEX IF NOT EXISTS idx_bank_statements_brs_business_id 
    ON public.bank_statements_brs(business_id);

CREATE INDEX IF NOT EXISTS idx_employees_payroll_business_id 
    ON public.employees_payroll(business_id);

CREATE INDEX IF NOT EXISTS idx_tds_tcs_entries_business_id 
    ON public.tds_tcs_entries(business_id);

CREATE INDEX IF NOT EXISTS idx_edit_logs_business_id 
    ON public.edit_logs(business_id);

CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id 
    ON public.user_subscriptions(user_id);

CREATE INDEX IF NOT EXISTS idx_dpdp_consent_logs_user_id 
    ON public.dpdp_consent_logs(user_id);

-- ------------------------------------------------------------------------------
-- 2. Foreign Key & Query Performance Optimization Indexes
-- Optimizes high-frequency joins, hierarchy traversals, and chronological filters
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_voucher_line_items_voucher_id 
    ON public.voucher_line_items(voucher_id);

CREATE INDEX IF NOT EXISTS idx_voucher_line_items_account_id 
    ON public.voucher_line_items(account_id);

CREATE INDEX IF NOT EXISTS idx_vouchers_date 
    ON public.vouchers(business_id, voucher_date DESC);

CREATE INDEX IF NOT EXISTS idx_accounts_parent_id 
    ON public.accounts(parent_id);

CREATE INDEX IF NOT EXISTS idx_stock_items_group_id 
    ON public.stock_items(group_id);

CREATE INDEX IF NOT EXISTS idx_bank_statements_brs_account_date 
    ON public.bank_statements_brs(bank_account_id, transaction_date DESC);

-- ------------------------------------------------------------------------------
-- 3. Trigram Fuzzy Search Indexes (pg_trgm)
-- Powers Stage 1 fast nearest-neighbor distance ordering (<->) and substring searches
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS trgm_idx_accounts_name_gist 
    ON public.accounts USING GIST (name gist_trgm_ops(siglen=32));

CREATE INDEX IF NOT EXISTS trgm_idx_stock_items_name_gist 
    ON public.stock_items USING GIST (name gist_trgm_ops(siglen=32));

CREATE INDEX IF NOT EXISTS trgm_idx_bank_statements_desc_gin 
    ON public.bank_statements_brs USING GIN (description gin_trgm_ops);

-- ------------------------------------------------------------------------------
-- 4. Phonetic Array GIN Indexes (daitch_mokotoff_code)
-- Powers Stage 2 fast array overlap queries (&&) for phonetic matching
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_accounts_phonetic_gin 
    ON public.accounts USING GIN (daitch_mokotoff_code);

CREATE INDEX IF NOT EXISTS idx_stock_items_phonetic_gin 
    ON public.stock_items USING GIN (daitch_mokotoff_code);

COMMIT;
