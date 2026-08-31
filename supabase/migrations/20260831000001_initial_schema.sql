-- ==============================================================================
-- Migration: 20260831000001_initial_schema.sql
-- Description: Initial PostgreSQL DDL Migration for Ledgify (22 Core Tables)
-- Specification: docs/02_database_schema_ddl_and_indexes.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. PostgreSQL Extensions
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "fuzzystrmatch";

-- ------------------------------------------------------------------------------
-- 2. Custom PostgreSQL Types (ENUMs)
-- ------------------------------------------------------------------------------
DO $$ BEGIN
    CREATE TYPE voucher_type_category AS ENUM (
        'Sales', 'Purchase', 'Payment', 'Receipt', 
        'Contra', 'Journal', 'Debit Note', 'Credit Note', 
        'Stock Journal', 'Physical Stock'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE supply_category_type AS ENUM (
        'B2B', 'B2C', 'SEZWP', 'SEZWOP', 'EXPWP', 'EXPWOP', 'DEXP'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE inventory_valuation_method AS ENUM (
        'FIFO', 'WEIGHTED_AVERAGE'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE subscription_status_type AS ENUM (
        'ACTIVE', 'CANCELLED', 'IN_GRACE_PERIOD', 'ON_HOLD', 'PAUSED', 'EXPIRED'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE ims_action_status AS ENUM (
        'PENDING', 'ACCEPTED', 'REJECTED'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- ------------------------------------------------------------------------------
-- 3. Core Tables (Strict Dependency Ordering)
-- ------------------------------------------------------------------------------

-- 1. Tenants / Companies
CREATE TABLE IF NOT EXISTS public.tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid VARCHAR(128) NOT NULL,
    company_name VARCHAR(255) NOT NULL,
    trade_name VARCHAR(255),
    pan_number VARCHAR(10) NOT NULL CHECK (pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]{1}$'),
    financial_year_start DATE NOT NULL,
    books_beginning_from DATE NOT NULL,
    currency_symbol VARCHAR(10) DEFAULT '₹',
    auto_load BOOLEAN DEFAULT TRUE,
    f11_features JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- 2. Multi-GST Registrations
CREATE TABLE IF NOT EXISTS public.gst_registrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    gstin VARCHAR(15) NOT NULL CHECK (gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$'),
    legal_name VARCHAR(255) NOT NULL,
    trade_name VARCHAR(255),
    state_code INTEGER NOT NULL CHECK (state_code BETWEEN 1 AND 38),
    principal_address TEXT NOT NULL,
    pincode INTEGER NOT NULL CHECK (pincode BETWEEN 100000 AND 999999),
    is_composition BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT clock_timestamp(),
    CONSTRAINT unq_business_gstin UNIQUE(business_id, gstin)
);

-- 3. Accounts / Ledgers Master
CREATE TABLE IF NOT EXISTS public.accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES public.accounts(id) ON DELETE RESTRICT,
    name VARCHAR(255) NOT NULL,
    alias VARCHAR(255),
    group_name VARCHAR(100) NOT NULL, -- Primary 28 Tally groups mapping
    primary_classification VARCHAR(50) NOT NULL CHECK (primary_classification IN ('Asset', 'Liability', 'Equity', 'Income', 'Expense')),
    is_sub_ledger BOOLEAN DEFAULT FALSE,
    opening_balance NUMERIC(15, 2) DEFAULT 0.00,
    opening_balance_type VARCHAR(2) DEFAULT 'Dr' CHECK (opening_balance_type IN ('Dr', 'Cr')),
    party_gstin VARCHAR(15),
    party_pan VARCHAR(10),
    hsn_sac_code VARCHAR(8),
    credit_period_days INTEGER DEFAULT 0,
    daitch_mokotoff_code TEXT[], -- Phonetic search array generated via trigger
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ DEFAULT clock_timestamp(),
    CONSTRAINT unq_business_account_name UNIQUE(business_id, name)
);

-- 4. Voucher Types
CREATE TABLE IF NOT EXISTS public.voucher_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE, -- NULL indicates system-default
    name VARCHAR(100) NOT NULL,
    category voucher_type_category NOT NULL,
    is_system_default BOOLEAN DEFAULT FALSE,
    e_invoice_applicable BOOLEAN DEFAULT FALSE,
    numbering_method VARCHAR(50) DEFAULT 'Automatic',
    restart_numbering_period VARCHAR(20) DEFAULT 'Yearly',
    created_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- 5. Stock Groups and Categories
CREATE TABLE IF NOT EXISTS public.stock_groups_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES public.stock_groups_categories(id),
    name VARCHAR(255) NOT NULL,
    is_group BOOLEAN DEFAULT TRUE, -- TRUE for Stock Group, FALSE for Stock Category
    created_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- 6. Stock Items
CREATE TABLE IF NOT EXISTS public.stock_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    group_id UUID REFERENCES public.stock_groups_categories(id),
    name VARCHAR(255) NOT NULL,
    alias VARCHAR(255),
    uqc VARCHAR(10) NOT NULL, -- PCS, KGS, NOS, etc.
    hsn_sac_code VARCHAR(8) NOT NULL,
    gst_rate_slab NUMERIC(5, 2) NOT NULL CHECK (gst_rate_slab IN (0, 0.1, 0.25, 3, 5, 12, 18, 28)),
    costing_method inventory_valuation_method DEFAULT 'FIFO',
    opening_quantity NUMERIC(12, 3) DEFAULT 0.000,
    opening_rate NUMERIC(15, 2) DEFAULT 0.00,
    opening_value NUMERIC(15, 2) DEFAULT 0.00,
    daitch_mokotoff_code TEXT[],
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- 7. Godowns / Multi-Location Warehouses
CREATE TABLE IF NOT EXISTS public.godowns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES public.godowns(id),
    name VARCHAR(255) NOT NULL,
    address TEXT,
    pincode INTEGER CHECK (pincode BETWEEN 100000 AND 999999),
    state_code INTEGER CHECK (state_code BETWEEN 1 AND 38),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- 8. Stock Batches & Expiry Tracking
CREATE TABLE IF NOT EXISTS public.stock_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    stock_item_id UUID NOT NULL REFERENCES public.stock_items(id) ON DELETE CASCADE,
    batch_number VARCHAR(100) NOT NULL,
    manufacturing_date DATE,
    expiry_date DATE,
    created_at TIMESTAMPTZ DEFAULT clock_timestamp(),
    CONSTRAINT unq_item_batch UNIQUE(business_id, stock_item_id, batch_number)
);

-- 9. Vouchers Header
CREATE TABLE IF NOT EXISTS public.vouchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    voucher_type_id UUID NOT NULL REFERENCES public.voucher_types(id),
    voucher_number VARCHAR(50) NOT NULL,
    voucher_date DATE NOT NULL,
    narration TEXT,
    reference_number VARCHAR(100),
    reference_date DATE,
    original_voucher_number VARCHAR(50), -- Retained on alteration/cancellation
    is_cancelled BOOLEAN DEFAULT FALSE,
    ai_confidence_score NUMERIC(5, 4),
    -- E-Invoice Header Tracking
    irn VARCHAR(64),
    qr_code TEXT,
    ack_no VARCHAR(50),
    ack_date TIMESTAMPTZ,
    e_way_bill_no VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ DEFAULT clock_timestamp(),
    CONSTRAINT unq_tenant_voucher_number UNIQUE(business_id, voucher_type_id, voucher_number)
);

-- 10. Voucher Line Items (Debits & Credits)
CREATE TABLE IF NOT EXISTS public.voucher_line_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    voucher_id UUID NOT NULL REFERENCES public.vouchers(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES public.accounts(id) ON DELETE RESTRICT,
    entry_type VARCHAR(2) NOT NULL CHECK (entry_type IN ('Dr', 'Cr')),
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    item_description TEXT,
    stock_item_id UUID REFERENCES public.stock_items(id),
    godown_id UUID REFERENCES public.godowns(id),
    batch_id UUID REFERENCES public.stock_batches(id),
    -- GST Split Calculations
    cgst_amt NUMERIC(15, 2) DEFAULT 0.00,
    sgst_amt NUMERIC(15, 2) DEFAULT 0.00,
    igst_amt NUMERIC(15, 2) DEFAULT 0.00,
    cess_amt NUMERIC(15, 2) DEFAULT 0.00,
    created_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- 11. Fixed Assets Register
CREATE TABLE IF NOT EXISTS public.fixed_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    asset_account_id UUID NOT NULL REFERENCES public.accounts(id) ON DELETE RESTRICT,
    asset_name VARCHAR(255) NOT NULL,
    category VARCHAR(100) NOT NULL,
    purchase_date DATE NOT NULL,
    original_cost NUMERIC(15, 2) NOT NULL CHECK (original_cost > 0),
    residual_value NUMERIC(15, 2) NOT NULL CHECK (residual_value <= (original_cost * 0.05)), -- Max 5% residual rule
    useful_life_years NUMERIC(5, 2) NOT NULL,
    is_nesd BOOLEAN DEFAULT FALSE, -- No Extra Shift Depreciation flag
    shift_working VARCHAR(20) DEFAULT 'Single' CHECK (shift_working IN ('Single', 'Double', 'Triple')),
    itc_claimed_flag BOOLEAN DEFAULT FALSE, -- CGST Sec 16(3) constraint
    accumulated_depreciation NUMERIC(15, 2) DEFAULT 0.00,
    is_disposed BOOLEAN DEFAULT FALSE,
    disposal_date DATE,
    created_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- 12. E-Invoice Logs (FORM GST INV-01)
CREATE TABLE IF NOT EXISTS public.einvoice_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    voucher_id UUID NOT NULL REFERENCES public.vouchers(id) ON DELETE CASCADE,
    irn VARCHAR(64) NOT NULL,
    ack_no VARCHAR(50) NOT NULL,
    ack_date TIMESTAMPTZ NOT NULL,
    signed_invoice TEXT NOT NULL,
    signed_qr_code TEXT NOT NULL,
    payload_json JSONB NOT NULL,
    irp_response JSONB NOT NULL,
    status VARCHAR(50) DEFAULT 'SUCCESS',
    created_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- 13. E-Way Bills (FORM GST EWB-01)
CREATE TABLE IF NOT EXISTS public.eway_bills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    voucher_id UUID NOT NULL REFERENCES public.vouchers(id) ON DELETE CASCADE,
    ewb_number VARCHAR(20) NOT NULL,
    ewb_date TIMESTAMPTZ NOT NULL,
    valid_upto TIMESTAMPTZ NOT NULL,
    transporter_party_id UUID REFERENCES public.accounts(id),
    vehicle_number VARCHAR(50),
    distance_km NUMERIC(8, 2) NOT NULL,
    part_a_data JSONB NOT NULL,
    part_b_data JSONB,
    status VARCHAR(50) DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- 14. GSTR Returns & Inward Supplies Management (IMS)
CREATE TABLE IF NOT EXISTS public.gstr_returns_ims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    return_type VARCHAR(20) NOT NULL CHECK (return_type IN ('GSTR1', 'GSTR3B', 'IMS')),
    return_period VARCHAR(10) NOT NULL, -- e.g., '082026' (MMYYYY)
    voucher_id UUID REFERENCES public.vouchers(id),
    ims_status ims_action_status DEFAULT 'PENDING',
    ims_remarks TEXT,
    payload_summary JSONB NOT NULL,
    filed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- 15. Bank Accounts
CREATE TABLE IF NOT EXISTS public.bank_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    ledger_id UUID NOT NULL REFERENCES public.accounts(id) ON DELETE RESTRICT,
    bank_name VARCHAR(100) NOT NULL,
    account_number VARCHAR(50) NOT NULL,
    ifsc_code VARCHAR(11) NOT NULL,
    branch_name VARCHAR(100),
    is_connected BOOLEAN DEFAULT FALSE,
    integration_provider VARCHAR(50), -- ICICI, Axis, SBI, RazorpayX
    created_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- 16. Bank Statements & BRS
CREATE TABLE IF NOT EXISTS public.bank_statements_brs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    bank_account_id UUID NOT NULL REFERENCES public.bank_accounts(id) ON DELETE CASCADE,
    transaction_date DATE NOT NULL,
    description TEXT NOT NULL,
    cheque_reference_no VARCHAR(50),
    withdrawal_amount NUMERIC(15, 2) DEFAULT 0.00,
    deposit_amount NUMERIC(15, 2) DEFAULT 0.00,
    balance NUMERIC(15, 2) NOT NULL,
    matched_voucher_id UUID REFERENCES public.vouchers(id),
    trgm_similarity_score REAL,
    is_reconciled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- 17. Employees & Payroll
CREATE TABLE IF NOT EXISTS public.employees_payroll (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    employee_code VARCHAR(50) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    salary_ledger_id UUID NOT NULL REFERENCES public.accounts(id),
    tax_regime VARCHAR(10) DEFAULT 'NEW' CHECK (tax_regime IN ('OLD', 'NEW')),
    basic_salary NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    hra NUMERIC(15, 2) DEFAULT 0.00,
    special_allowance NUMERIC(15, 2) DEFAULT 0.00,
    pf_applicable BOOLEAN DEFAULT TRUE,
    esi_applicable BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- 18. TDS & TCS Entries
CREATE TABLE IF NOT EXISTS public.tds_tcs_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    voucher_id UUID NOT NULL REFERENCES public.vouchers(id) ON DELETE CASCADE,
    section_code VARCHAR(20) NOT NULL, -- e.g., '194Q', '206C(1H)'
    party_pan VARCHAR(10) NOT NULL,
    assessed_amount NUMERIC(15, 2) NOT NULL,
    tds_tcs_rate NUMERIC(5, 3) NOT NULL,
    tax_amount NUMERIC(15, 2) NOT NULL,
    challan_number VARCHAR(50),
    challan_date DATE,
    form_type VARCHAR(10) CHECK (form_type IN ('26Q', '27EQ')),
    created_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- 19. User Subscriptions (Google Play)
CREATE TABLE IF NOT EXISTS public.user_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL, -- Matches Supabase Auth / Firebase UID mapping
    business_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    product_id VARCHAR(100) NOT NULL,
    purchase_token TEXT NOT NULL UNIQUE,
    order_id VARCHAR(100),
    status subscription_status_type NOT NULL DEFAULT 'ACTIVE',
    expiry_time TIMESTAMPTZ NOT NULL,
    auto_renewing BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- 20. Billing Webhook Logs (RTDN Pub/Sub)
CREATE TABLE IF NOT EXISTS public.billing_webhook_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id VARCHAR(100) NOT NULL UNIQUE,
    event_type VARCHAR(100) NOT NULL,
    purchase_token TEXT NOT NULL,
    payload JSONB NOT NULL,
    processed_status VARCHAR(50) DEFAULT 'PROCESSED',
    created_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- 21. Edit Logs (Statutory Audit Trail)
CREATE TABLE IF NOT EXISTS public.edit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    table_name VARCHAR(100) NOT NULL,
    record_id UUID NOT NULL,
    action VARCHAR(10) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data JSONB,
    new_data JSONB,
    performed_by VARCHAR(128) NOT NULL, -- Firebase UID
    performed_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- 22. DPDP Consent Logs (Data Principal Rights)
CREATE TABLE IF NOT EXISTS public.dpdp_consent_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    data_principal_id VARCHAR(128) NOT NULL,
    purpose VARCHAR(255) NOT NULL,
    notice_version VARCHAR(20) NOT NULL,
    consent_granted BOOLEAN NOT NULL,
    withdrawn_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT clock_timestamp()
);

COMMIT;
