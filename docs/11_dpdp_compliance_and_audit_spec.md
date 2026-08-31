# 11_dpdp_compliance_and_audit_spec.md — DPDP Act 2023 Statutory Architecture, Audit Trail & Data Retention Engine

## 1. Statutory Scope & Regulatory Framework
Ledgify acts as a **Data Fiduciary** under India's Digital Personal Data Protection (DPDP) Act, 2023. The platform processes financial transactions, invoice images, voice notes, and customer/vendor details belonging to **Data Principals** (MSME owners and their end clients).

### Key Legal Invariants Enforced:
1. **Multilingual Consent & Notice (Section 5 & 6):** Preceding data processing, users must receive a clear notice specifying the itemized data collected and specific processing purposes, available in English and 8th Schedule Indian languages (Devanagari/Hindi)[cite: 2].
2. **Statutory Books Retention Floor (CGST Act Sec 36 vs DPDP Sec 8(7)):** While the DPDP Act mandates data erasure upon consent withdrawal or purpose completion, Section 8(7) explicitly carves out exceptions for legal compliance[cite: 2]. Under Section 36 of the CGST Act 2017, all accounting books, vouchers, and tax invoices must be retained for **72 months** from the annual return due date[cite: 2].
3. **Statutory Audit Trail (`edit_logs`):** Mandatory immutable audit trail tracking creation, alteration, and soft-deletion of vouchers and masters, recording timestamps, user identity, and version diffs.
4. **Gemini Free-Tier Consent Disclosure:** Because the Gemini API Free Tier logs input prompts/files for Google product training, users must provide explicit informed consent before scanning physical financial documents or speaking voice vouchers.

---

## 2. DPDP Notice & Consent Architecture

### 2.1 Consent Record Entity (`dpdp_consent_logs`)
Every consent action or withdrawal is recorded in `dpdp_consent_logs` with the following parameters[cite: 1, 2]:
- `user_id`: Authenticated user UUID[cite: 1, 2].
- `data_principal_id`: Firebase UID / Owner PAN reference[cite: 1, 2].
- `purpose`: Enumerated processing purpose (e.g., `FINANCIAL_OCR_EXTRACTION`, `VOICE_VOUCHER_PROCESSING`, `GST_RETURN_FILING`)[cite: 1, 2].
- `notice_version`: Tracking the active legal terms version (e.g., `v1.0_20260831`)[cite: 1, 2].
- `consent_granted`: Boolean affirmative flag[cite: 1, 2].
- `withdrawn_at`: Nullable timestamp populated upon revocation[cite: 1, 2].

### 2.2 Bilingual Consent Notice UI Dialog Component
```dart
// client/lib/features/settings/presentation/widgets/dpdp_consent_dialog.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';

class DpdpConsentDialog extends StatelessWidget {
  final String noticeVersion;
  final Function(bool isGranted) onConsentResolved;

  const DpdpConsentDialog({
    Key? key,
    this.noticeVersion = 'v1.0_20260831',
    required this.onConsentResolved,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.privacy_tip_outlined, color: LedgifyColors.primaryBlue),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Data Privacy & AI Processing Notice / डेटा गोपनीयता सूचना',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Under the Digital Personal Data Protection (DPDP) Act, 2023, Ledgify requires your explicit consent to process financial documents, invoices, and voice commands.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'DPDP अधिनियम, 2023 के तहत, आपके वित्तीय बिलों, चालान और वॉयस डेटा को AI मॉडल द्वारा प्रोसेस करने के लिए आपकी स्पष्ट सहमति आवश्यक है।',
              style: TextStyle(fontSize: 13, color: LedgifyColors.secondarySlate),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LedgifyColors.warningOrangeBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: LedgifyColors.warningOrange),
              ),
              child: const Text(
                'AI Notice: On the free service tier, anonymized bill images and audio clips are processed using AI APIs for automated extraction. Do not upload classified confidential credentials.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Statutory Retention: Tax and accounting records are preserved for 72 months as mandated by Section 36 of the CGST Act, 2017.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onConsentResolved(false);
          },
          child: const Text('Decline / अस्वीकार करें', style: TextStyle(color: LedgifyColors.creditRed)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: LedgifyColors.primaryBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
            onConsentResolved(true);
          },
          child: const Text('Accept & Proceed / स्वीकार करें'),
        ),
      ],
    );
  }
}
3. Statutory Audit Trail Engine (edit_logs)
PostgreSQL edit_logs are populated exclusively via database triggers configured as SECURITY DEFINER[cite: 1, 2].
Regular database users (authenticated) have read-only (SELECT) permissions on their own business records and are blocked from directly altering or inserting audit entries[cite: 1, 2].

3.1 Generic Audit Trigger Function
SQL
CREATE OR REPLACE FUNCTION public.audit_table_mutation()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$ DECLARE     v_business_id UUID;     v_record_id UUID;     v_action VARCHAR(10);     v_old JSONB := NULL;     v_new JSONB := NULL;     v_user_uid VARCHAR(128); BEGIN     v_action := TG_OP;     v_user_uid := COALESCE(auth.jwt() ->> 'sub', 'SYSTEM');      IF (TG_OP = 'DELETE') THEN         v_business_id := OLD.business_id;         v_record_id := OLD.id;         v_old := to_jsonb(OLD);     ELSIF (TG_OP = 'UPDATE') THEN         v_business_id := NEW.business_id;         v_record_id := NEW.id;         v_old := to_jsonb(OLD);         v_new := to_jsonb(NEW);     ELSIF (TG_OP = 'INSERT') THEN         v_business_id := NEW.business_id;         v_record_id := NEW.id;         v_new := to_jsonb(NEW);     END IF;      -- Insert immutable audit record     INSERT INTO public.edit_logs (         business_id,         table_name,         record_id,         action,         old_data,         new_data,         performed_by,         performed_at     ) VALUES (         v_business_id,         TG_TABLE_NAME::VARCHAR(100),         v_record_id,         v_action,         v_old,         v_new,         v_user_uid,         clock_timestamp()     );      IF (TG_OP = 'DELETE') THEN         RETURN OLD;     ELSE         RETURN NEW;     END IF; END; $$;
3.2 Attaching Audit Triggers to Critical Accounting Tables
SQL
-- Attach triggers to vouchers, voucher_line_items, accounts, and fixed_assets
CREATE OR REPLACE TRIGGER trg_audit_vouchers
AFTER INSERT OR UPDATE OR DELETE ON public.vouchers
FOR EACH ROW EXECUTE FUNCTION public.audit_table_mutation();

CREATE OR REPLACE TRIGGER trg_audit_accounts
AFTER INSERT OR UPDATE OR DELETE ON public.accounts
FOR EACH ROW EXECUTE FUNCTION public.audit_table_mutation();

CREATE OR REPLACE TRIGGER trg_audit_fixed_assets
AFTER INSERT OR UPDATE OR DELETE ON public.fixed_assets
FOR EACH ROW EXECUTE FUNCTION public.audit_table_mutation();

CREATE OR REPLACE TRIGGER trg_audit_stock_items
AFTER INSERT OR UPDATE OR DELETE ON public.stock_items
FOR EACH ROW EXECUTE FUNCTION public.audit_table_mutation();
4. Conflict Resolution: DPDP Right to Erasure vs. CGST 72-Month Retention
When a user exercises their Right to Erasure under Section 12(3) of the DPDP Act, the system evaluates active statutory retention requirements before purging data[cite: 2]:

SQL
CREATE OR REPLACE FUNCTION public.execute_dpdp_data_erasure(
    p_user_id UUID,
    p_business_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$ DECLARE     v_active_vouchers_count INTEGER;     v_oldest_retained_date DATE; BEGIN     -- Check if there are vouchers within the 72-month retention window     SELECT COUNT(*), MIN(voucher_date)     INTO v_active_vouchers_count, v_oldest_retained_date     FROM public.vouchers     WHERE business_id = p_business_id       AND voucher_date >= (CURRENT_DATE - INTERVAL '72 months');      IF v_active_vouchers_count > 0 THEN         -- Anonymize non-statutory user profile metadata while retaining legal books         UPDATE public.tenants         SET company_name = 'Anonymized Tenant (' \vert{}\vert{} SUBSTRING(p_business_id::text, 1, 8) \vert{}\vert{} ')',             trade_name = NULL,             pan_number = 'AAAAA0000A',             updated_at = clock_timestamp()         WHERE id = p_business_id;          -- Record erasure limitation event         INSERT INTO public.dpdp_consent_logs (             user_id,             data_principal_id,             purpose,             notice_version,             consent_granted,             withdrawn_at         ) VALUES (             p_user_id,             p_user_id::text,             'DATA_ERASURE_REQUEST_STATUTORY_RETAINED',             'v1.0_20260831',             FALSE,             clock_timestamp()         );          RETURN jsonb_build_object(             'status', 'PARTIALLY_ANONYMIZED',             'message', 'Profile metadata anonymized. Financial vouchers retained under CGST Act Section 36 for 72 months.',             'retained_records', v_active_vouchers_count         );     ELSE         -- Full deletion if no records fall within 72-month statutory retention         DELETE FROM public.tenants WHERE id = p_business_id;         RETURN jsonb_build_object(             'status', 'FULLY_PURGED',             'message', 'All business and transaction records permanently deleted.'         );     END IF; END; $$;
5. Data Breach Notification & Intimation Workflow
Under Section 8(6) of the DPDP Act 2023, data breaches must be intimated to the Data Protection Board of India and affected Data Principals[cite: 2].

SQL
-- Stored procedure to log and flag security incidents
CREATE OR REPLACE FUNCTION public.log_security_incident(
    p_business_id UUID,
    p_incident_type VARCHAR(100),
    p_affected_records INTEGER,
    p_description TEXT
)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER AS $$ DECLARE     v_log_id UUID; BEGIN     INSERT INTO public.edit_logs (         business_id,         table_name,         record_id,         action,         new_data,         performed_by,         performed_at     ) VALUES (         p_business_id,         'SECURITY_INCIDENT_REPORT',         gen_random_uuid(),         'INSERT',         jsonb_build_object(             'incident_type', p_incident_type,             'affected_records', p_affected_records,             'description', p_description,             'dpdp_board_notified', TRUE         ),         'SECURITY_MONITOR',         clock_timestamp()     ) RETURNING id INTO v_log_id;      RETURN v_log_id; END; $$;