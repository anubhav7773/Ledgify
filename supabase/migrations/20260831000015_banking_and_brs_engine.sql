-- ==============================================================================
-- Migration: 20260831000015_banking_and_brs_engine.sql
-- Description: Automated BRS Engine, Trigram Similarity Reconciliation & 1-Click Voucher Posting
-- Specification: docs/08_banking_brs_payroll_direct_tax.md & docs/02_database_schema_ddl_and_indexes.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Automated BRS Trigram Matching Stored Function
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.auto_reconcile_bank_statement(
    p_business_id UUID,
    p_bank_account_id UUID
)
RETURNS TABLE (
    statement_id UUID,
    matched_voucher_id UUID,
    similarity_score REAL,
    reconciliation_action VARCHAR(20)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    rec RECORD;
    v_target_voucher_id UUID;
    v_score REAL;
BEGIN
    FOR rec IN 
        SELECT bs.id, bs.transaction_date, bs.description, bs.cheque_reference_no,
               bs.withdrawal_amount, bs.deposit_amount
        FROM public.bank_statements_brs bs
        WHERE bs.business_id = p_business_id
          AND bs.bank_account_id = p_bank_account_id
          AND bs.is_reconciled = FALSE
    LOOP
        -- Search matching voucher line item within a 7-day window and identical amount
        SELECT 
            v.id,
            GREATEST(
                similarity(COALESCE(v.narration, ''), rec.description),
                word_similarity(COALESCE(rec.cheque_reference_no, ''), COALESCE(v.reference_number, ''))
            ) AS match_score
        INTO v_target_voucher_id, v_score
        FROM public.vouchers v
        JOIN public.voucher_line_items vli ON vli.voucher_id = v.id
        JOIN public.bank_accounts ba ON ba.ledger_id = vli.account_id
        WHERE v.business_id = p_business_id
          AND ba.id = p_bank_account_id
          AND v.is_cancelled = FALSE
          AND v.voucher_date BETWEEN (rec.transaction_date - INTERVAL '7 days') AND (rec.transaction_date + INTERVAL '7 days')
          AND (
              (rec.withdrawal_amount > 0 AND vli.entry_type = 'Cr' AND vli.amount = rec.withdrawal_amount)
              OR
              (rec.deposit_amount > 0 AND vli.entry_type = 'Dr' AND vli.amount = rec.deposit_amount)
          )
        ORDER BY match_score DESC
        LIMIT 1;

        IF v_target_voucher_id IS NOT NULL AND v_score >= 0.60 THEN
            -- Update statement record with match candidate
            UPDATE public.bank_statements_brs
            SET matched_voucher_id = v_target_voucher_id,
                trgm_similarity_score = v_score,
                is_reconciled = (CASE WHEN v_score >= 0.85 THEN TRUE ELSE FALSE END)
            WHERE id = rec.id;

            statement_id := rec.id;
            matched_voucher_id := v_target_voucher_id;
            similarity_score := v_score;
            reconciliation_action := (CASE WHEN v_score >= 0.85 THEN 'AUTO_RECONCILED' ELSE 'SUGGESTION' END);
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$$;

-- ------------------------------------------------------------------------------
-- 2. 1-Click Double-Entry Voucher Creation from Bank Statement Line
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_voucher_from_bank_line(
    p_business_id UUID,
    p_statement_id UUID,
    p_contra_account_id UUID, -- Expense ledger for charges, Income ledger for interest, Party ledger for payments
    p_voucher_type VARCHAR(20) DEFAULT 'Payment' -- 'Payment', 'Receipt', or 'Contra'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_stmt RECORD;
    v_voucher_id UUID;
    v_vtype_id UUID;
    v_amt NUMERIC(15, 2);
    v_voucher_num VARCHAR(50);
BEGIN
    SELECT bs.*, ba.ledger_id INTO v_stmt
    FROM public.bank_statements_brs bs
    JOIN public.bank_accounts ba ON ba.id = bs.bank_account_id
    WHERE bs.id = p_statement_id AND bs.business_id = p_business_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Bank statement entry not found.';
    END IF;

    -- Lookup voucher type ID
    SELECT id INTO v_vtype_id FROM public.voucher_types 
    WHERE (business_id = p_business_id OR is_system_default = TRUE)
      AND name ILIKE p_voucher_type LIMIT 1;

    IF v_vtype_id IS NULL THEN
        SELECT id INTO v_vtype_id FROM public.voucher_types WHERE is_system_default = TRUE LIMIT 1;
    END IF;

    v_amt := GREATEST(v_stmt.withdrawal_amount, v_stmt.deposit_amount);
    v_voucher_num := 'BNK-' || TO_CHAR(v_stmt.transaction_date, 'YYMM') || '-' || SUBSTRING(gen_random_uuid()::TEXT, 1, 6);

    -- Insert Voucher Header
    INSERT INTO public.vouchers (
        business_id, voucher_type_id, voucher_number, voucher_date, 
        narration, reference_number
    ) VALUES (
        p_business_id, v_vtype_id, v_voucher_num,
        v_stmt.transaction_date, v_stmt.description, v_stmt.cheque_reference_no
    ) RETURNING id INTO v_voucher_id;

    -- Insert Line Items based on Withdrawal vs Deposit
    IF v_stmt.withdrawal_amount > 0 THEN
        -- Payment: Debit Contra Account (Expense/Vendor), Credit Bank Ledger
        INSERT INTO public.voucher_line_items (business_id, voucher_id, account_id, entry_type, amount, item_description)
        VALUES (p_business_id, v_voucher_id, p_contra_account_id, 'Dr', v_amt, 'Payment from bank statement line');
        
        INSERT INTO public.voucher_line_items (business_id, voucher_id, account_id, entry_type, amount, item_description)
        VALUES (p_business_id, v_voucher_id, v_stmt.ledger_id, 'Cr', v_amt, 'Bank payout: ' || v_stmt.description);
    ELSE
        -- Receipt: Debit Bank Ledger, Credit Contra Account (Income/Customer)
        INSERT INTO public.voucher_line_items (business_id, voucher_id, account_id, entry_type, amount, item_description)
        VALUES (p_business_id, v_voucher_id, v_stmt.ledger_id, 'Dr', v_amt, 'Bank credit: ' || v_stmt.description);
        
        INSERT INTO public.voucher_line_items (business_id, voucher_id, account_id, entry_type, amount, item_description)
        VALUES (p_business_id, v_voucher_id, p_contra_account_id, 'Cr', v_amt, 'Receipt allocation from bank statement');
    END IF;

    -- Mark Bank Statement as Reconciled
    UPDATE public.bank_statements_brs
    SET is_reconciled = TRUE, 
        matched_voucher_id = v_voucher_id, 
        trgm_similarity_score = 1.0
    WHERE id = p_statement_id;

    RETURN v_voucher_id;
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. Manual BRS Link / Unlink Helper Procedure
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.manual_reconcile_brs_entry(
    p_business_id UUID,
    p_statement_id UUID,
    p_voucher_id UUID,
    p_action VARCHAR(10) DEFAULT 'LINK' -- 'LINK' or 'UNLINK'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF p_action = 'LINK' THEN
        UPDATE public.bank_statements_brs
        SET matched_voucher_id = p_voucher_id,
            is_reconciled = TRUE,
            trgm_similarity_score = 1.0
        WHERE id = p_statement_id AND business_id = p_business_id;
    ELSIF p_action = 'UNLINK' THEN
        UPDATE public.bank_statements_brs
        SET matched_voucher_id = NULL,
            is_reconciled = FALSE,
            trgm_similarity_score = NULL
        WHERE id = p_statement_id AND business_id = p_business_id;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_reconcile_bank_statement(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_voucher_from_bank_line(UUID, UUID, UUID, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION public.manual_reconcile_brs_entry(UUID, UUID, UUID, VARCHAR) TO authenticated;

COMMIT;
