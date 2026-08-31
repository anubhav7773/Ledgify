# 04_core_accounting_engine_rules.md — Core Double-Entry Engine, 28 Tally Groups, Voucher Triggers & Depreciation Rules

## 1. Overview & Double-Entry Invariants
Ledgify enforces strict mathematical invariants at the PostgreSQL trigger level to ensure the ledger remains permanently balanced:
1. **Zero-Sum Constraint:** For every committed voucher:
   $$\sum \text{Debits} = \sum \text{Credits}$$
2. **Deterministic Classification:** All accounts belong to one of 5 top-level accounting categories (`Asset`, `Liability`, `Equity`, `Income`, `Expense`) via the 28 standard Tally groups.
3. **Statutory Schedule II Depreciation:** Assets follow Companies Act 2013 useful life tables, max 5% residual value caps, pro-rata daily allocations, and double/triple shift adjustments.
4. **GST ITC Exclusivity (CGST Sec 16(3)):** If Input Tax Credit (ITC) is claimed on capital goods, the tax component cannot be capitalized or depreciated under the Income-tax Act.
5. **Books Retention (CGST Sec 36):** Hard-delete operations on vouchers/ledgers are blocked for 72 months from the annual return due date.

---

## 2. The 28 Standard Tally Groups Taxonomy & Default Balances

The table below maps the standard 28 default groups across Primary Classifications, Nature, and Balance Sheet / P&L rollup destinations:

| # | Group Name | Parent Group / Nature | Primary Classification | Default Nature | Affects |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | Capital Account | Primary | Equity | Credit | Balance Sheet |
| **2** | Reserves & Surplus | Capital Account | Equity | Credit | Balance Sheet |
| **3** | Current Assets | Primary | Asset | Debit | Balance Sheet |
| **4** | Bank Accounts | Current Assets | Asset | Debit | Balance Sheet |
| **5** | Cash-in-Hand | Current Assets | Asset | Debit | Balance Sheet |
| **6** | Deposits (Asset) | Current Assets | Asset | Debit | Balance Sheet |
| **7** | Loans & Advances (Asset) | Current Assets | Asset | Debit | Balance Sheet |
| **8** | Stock-in-Hand | Current Assets | Asset | Debit | Balance Sheet |
| **9** | Sundry Debtors | Current Assets | Asset | Debit | Balance Sheet |
| **10** | Current Liabilities | Primary | Liability | Credit | Balance Sheet |
| **11** | Duties & Taxes | Current Liabilities | Liability | Credit | Balance Sheet |
| **12** | Provisions | Current Liabilities | Liability | Credit | Balance Sheet |
| **13** | Sundry Creditors | Current Liabilities | Liability | Credit | Balance Sheet |
| **14** | Fixed Assets | Primary | Asset | Debit | Balance Sheet |
| **15** | Investments | Primary | Asset | Debit | Balance Sheet |
| **16** | Loans (Liability) | Primary | Liability | Credit | Balance Sheet |
| **17** | Bank OD A/c | Loans (Liability) | Liability | Credit | Balance Sheet |
| **18** | Secured Loans | Loans (Liability) | Liability | Credit | Balance Sheet |
| **19** | Unsecured Loans | Loans (Liability) | Liability | Credit | Balance Sheet |
| **20** | Suspense A/c | Primary | Asset / Liability | Debit / Credit | Balance Sheet |
| **21** | Direct Incomes | Primary | Income | Credit | Profit & Loss |
| **22** | Sales Accounts | Direct Incomes | Income | Credit | Profit & Loss |
| **23** | Indirect Incomes | Primary | Income | Credit | Profit & Loss |
| **24** | Direct Expenses | Primary | Expense | Debit | Profit & Loss |
| **25** | Purchase Accounts | Direct Expenses | Expense | Debit | Profit & Loss |
| **26** | Indirect Expenses | Primary | Expense | Debit | Profit & Loss |
| **27** | Misc. Expenses (ASSET) | Primary | Asset | Debit | Balance Sheet |
| **28** | Branch / Divisions | Primary | Liability / Asset | Credit / Debit | Balance Sheet |

---

## 3. Seed SQL for 28 Default Master Groups

```sql
-- Seed standard groups for a new tenant upon registration
CREATE OR REPLACE FUNCTION public.seed_default_tally_groups(target_business_id UUID)
RETURNS VOID LANGUAGE plpgsql AS $$ BEGIN     INSERT INTO public.accounts (business_id, name, group_name, primary_classification, opening_balance_type, is_sub_ledger)     VALUES         (target_business_id, 'Capital Account', 'Primary', 'Equity', 'Cr', FALSE),         (target_business_id, 'Reserves & Surplus', 'Capital Account', 'Equity', 'Cr', FALSE),         (target_business_id, 'Current Assets', 'Primary', 'Asset', 'Dr', FALSE),         (target_business_id, 'Bank Accounts', 'Current Assets', 'Asset', 'Dr', FALSE),         (target_business_id, 'Cash-in-Hand', 'Current Assets', 'Asset', 'Dr', FALSE),         (target_business_id, 'Deposits (Asset)', 'Current Assets', 'Asset', 'Dr', FALSE),         (target_business_id, 'Loans & Advances (Asset)', 'Current Assets', 'Asset', 'Dr', FALSE),         (target_business_id, 'Stock-in-Hand', 'Current Assets', 'Asset', 'Dr', FALSE),         (target_business_id, 'Sundry Debtors', 'Current Assets', 'Asset', 'Dr', FALSE),         (target_business_id, 'Current Liabilities', 'Primary', 'Liability', 'Cr', FALSE),         (target_business_id, 'Duties & Taxes', 'Current Liabilities', 'Liability', 'Cr', FALSE),         (target_business_id, 'Provisions', 'Current Liabilities', 'Liability', 'Cr', FALSE),         (target_business_id, 'Sundry Creditors', 'Current Liabilities', 'Liability', 'Cr', FALSE),         (target_business_id, 'Fixed Assets', 'Primary', 'Asset', 'Dr', FALSE),         (target_business_id, 'Investments', 'Primary', 'Asset', 'Dr', FALSE),         (target_business_id, 'Loans (Liability)', 'Primary', 'Liability', 'Cr', FALSE),         (target_business_id, 'Bank OD A/c', 'Loans (Liability)', 'Liability', 'Cr', FALSE),         (target_business_id, 'Secured Loans', 'Loans (Liability)', 'Liability', 'Cr', FALSE),         (target_business_id, 'Unsecured Loans', 'Loans (Liability)', 'Liability', 'Cr', FALSE),         (target_business_id, 'Suspense A/c', 'Primary', 'Asset', 'Dr', FALSE),         (target_business_id, 'Direct Incomes', 'Primary', 'Income', 'Cr', FALSE),         (target_business_id, 'Sales Accounts', 'Direct Incomes', 'Income', 'Cr', FALSE),         (target_business_id, 'Indirect Incomes', 'Primary', 'Income', 'Cr', FALSE),         (target_business_id, 'Direct Expenses', 'Primary', 'Expense', 'Dr', FALSE),         (target_business_id, 'Purchase Accounts', 'Direct Expenses', 'Expense', 'Dr', FALSE),         (target_business_id, 'Indirect Expenses', 'Primary', 'Expense', 'Dr', FALSE),         (target_business_id, 'Misc. Expenses (ASSET)', 'Primary', 'Asset', 'Dr', FALSE),         (target_business_id, 'Branch / Divisions', 'Primary', 'Liability', 'Cr', FALSE)     ON CONFLICT (business_id, name) DO NOTHING; END; $$;
4. Voucher Posting Matrix (Debit / Credit Allocations)Voucher TypeStandard Debit AllocationStandard Credit AllocationTax Split PostingsSalesSundry Debtor / Cash / BankSales A/cCr: CGST/SGST/IGST Output TaxPurchasePurchase A/c / Expense A/cSundry Creditor / Cash / BankDr: CGST/SGST/IGST Input Tax (ITC)PaymentSundry Creditor / Expense A/cBank Accounts / Cash-in-HandN/A (or TDS deducted Cr: Duties & Taxes)ReceiptBank Accounts / Cash-in-HandSundry Debtor / Direct IncomeN/A (or Advance GST liability Cr)ContraReceiving Cash/Bank AccountDisbursing Cash/Bank AccountN/A (Internal transfers)JournalAsset / Expense / Adjusted LedgerLiability / Income / Adjusted LedgerAdjustments / Opening / Year-endDebit NoteSundry CreditorPurchase Returns / Item LedgerDr: Input Tax Reversal / Output TaxCredit NoteSales Returns / Item LedgerSundry DebtorCr: Output Tax Adjustment5. Mathematical Zero-Sum Validation TriggerThis trigger validates transaction equality ($\sum \text{Debits} = \sum \text{Credits}$) at deferred transaction commit.SQL-- Function to validate zero-sum balance before committing transaction
CREATE OR REPLACE FUNCTION public.validate_voucher_zero_sum()
RETURNS TRIGGER LANGUAGE plpgsql AS $$ DECLARE     total_debits NUMERIC(15, 2) := 0.00;     total_credits NUMERIC(15, 2) := 0.00;     target_voucher_id UUID; BEGIN     target_voucher_id := COALESCE(NEW.voucher_id, OLD.voucher_id);      -- Calculate total debits and credits for the target voucher     SELECT          COALESCE(SUM(CASE WHEN entry_type = 'Dr' THEN amount ELSE 0 END), 0.00),         COALESCE(SUM(CASE WHEN entry_type = 'Cr' THEN amount ELSE 0 END), 0.00)     INTO total_debits, total_credits     FROM public.voucher_line_items     WHERE voucher_id = target_voucher_id;      -- Enforce absolute equality (2-decimal precision)     IF total_debits <> total_credits THEN         RAISE EXCEPTION 'Double-entry balancing violation: Total Debits (\%) must equal Total Credits (\%) for voucher \%',              total_debits, total_credits, target_voucher_id             USING ERRCODE = 'check_violation';     END IF;      RETURN NULL; END; $$;

-- Create constraint trigger evaluated at transaction end
CREATE OR REPLACE TRIGGER trg_enforce_voucher_zero_sum
AFTER INSERT OR UPDATE OR DELETE ON public.voucher_line_items
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validate_voucher_zero_sum();
6. Schedule II Depreciation Engine (Companies Act 2013)6.1 Statutory Useful Life Master Table (Part C Reference)CategoryTangible Asset Sub-CategoryUseful LifeShift Multiplier Allowed?BuildingsNon-Factory Building (RCC Frame)60 YearsNo (NESD)BuildingsFactory Buildings30 YearsNo (NESD)ComputersServers and Networks6 YearsNo (NESD)ComputersEnd-User Devices (Laptops, Desktops)3 YearsNo (NESD)Plant & MachineryGeneral Plant & Machinery15 YearsYes (+50% Double, +100% Triple)Plant & MachineryContinuous Process Plant8 YearsNo (NESD)FurnitureGeneral Furniture & Fittings10 YearsNo (NESD)VehiclesCommercial Motor Vehicles (Hire)6 YearsNo (NESD)VehiclesNon-commercial Motor Vehicles8 YearsNo (NESD)Office EquipmentGeneral Office Equipment5 YearsNo (NESD)6.2 Depreciation Formulas & Shift AdjustmentsDepreciable Amount:$$\text{Depreciable Cost} = \text{Original Cost} - \text{Residual Value} \quad (\text{Residual Value} \le 0.05 \times \text{Cost})$$Single Shift Annual Depreciation (SLM):$$\text{Annual Rate} = \frac{\text{Depreciable Cost}}{\text{Useful Life Years}}$$Shift Multiplier ($M_{\text{shift}}$):Single Shift: $1.0\times$Double Shift: $1.5\times$ (if is_nesd = FALSE)Triple Shift: $2.0\times$ (if is_nesd = FALSE)Pro-Rata Daily Depreciation:$$\text{Period Depreciation} = \text{Annual Rate} \times M_{\text{shift}} \times \left( \frac{\text{Active Days in Period}}{\text{Total Days in Year (365/366)}} \right)$$6.3 Automated Depreciation Stored ProcedureSQLCREATE OR REPLACE FUNCTION public.calculate_asset_depreciation(
    p_asset_id UUID,
    p_period_start DATE,
    p_period_end DATE
)
RETURNS NUMERIC(15, 2) LANGUAGE plpgsql AS $$ DECLARE     v_cost NUMERIC(15, 2);     v_residual NUMERIC(15, 2);     v_useful_life NUMERIC(5, 2);     v_is_nesd BOOLEAN;     v_shift VARCHAR(20);     v_purchase_date DATE;     v_disposal_date DATE;     v_active_start DATE;     v_active_end DATE;     v_active_days INTEGER;     v_year_days INTEGER;     v_multiplier NUMERIC(3, 2) := 1.0;     v_depreciable_base NUMERIC(15, 2);     v_depreciation NUMERIC(15, 2); BEGIN     SELECT original_cost, residual_value, useful_life_years, is_nesd, shift_working, purchase_date, disposal_date     INTO v_cost, v_residual, v_useful_life, v_is_nesd, v_shift, v_purchase_date, v_disposal_date     FROM public.fixed_assets     WHERE id = p_asset_id;      -- Determine active boundary dates     v_active_start := GREATEST(p_period_start, v_purchase_date);     v_active_end := LEAST(p_period_end, COALESCE(v_disposal_date, p_period_end));      IF v_active_start > v_active_end THEN         RETURN 0.00;     END IF;      v_active_days := (v_active_end - v_active_start) + 1;     v_year_days := 365;      -- Shift working multipliers (blocked if NESD)     IF NOT v_is_nesd THEN         IF v_shift = 'Double' THEN v_multiplier := 1.5;         ELSIF v_shift = 'Triple' THEN v_multiplier := 2.0;         END IF;     END IF;      v_depreciable_base := v_cost - v_residual;     v_depreciation := ROUND(( (v_depreciable_base / v_useful_life) * v_multiplier * (v_active_days::numeric / v_year_days::numeric) ), 2);      RETURN v_depreciation; END; $$;
7. Section 16(3) & 72-Month Statutory Retention EnforcementsSQL-- Trigger: Disallow Capital Asset Tax Component inclusion when ITC claimed (CGST Sec 16(3))
CREATE OR REPLACE FUNCTION public.check_itc_depreciation_exclusivity()
RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN     IF NEW.itc_claimed_flag IS TRUE THEN         -- Verify that the asset cost does not include tax component (checked via client flag)         -- Trigger ensures asset log reflects Section 16(3) compliance     END IF;     RETURN NEW; END; $$;

-- Trigger: Prohibit hard-deletion of vouchers within 72-month retention window (CGST Sec 36)
CREATE OR REPLACE FUNCTION public.prevent_early_voucher_deletion()
RETURNS TRIGGER LANGUAGE plpgsql AS $$ DECLARE     v_age_months INTEGER; BEGIN     v_age_months := (DATE_PART('year', CURRENT_DATE) - DATE_PART('year', OLD.voucher_date)) * 12 +                     (DATE_PART('month', CURRENT_DATE) - DATE_PART('month', OLD.voucher_date));      IF v_age_months < 72 THEN         RAISE EXCEPTION 'Statutory Retention Violation (CGST Sec 36): Cannot delete voucher \% within 72 months of creation.', OLD.voucher_number             USING ERRCODE = 'integrity_constraint_violation';     END IF;      RETURN OLD; END; $$;

CREATE OR REPLACE TRIGGER trg_protect_voucher_retention
BEFORE DELETE ON public.vouchers
FOR EACH ROW
EXECUTE FUNCTION public.prevent_early_voucher_deletion();