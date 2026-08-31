# 07_fuzzy_entity_matching_spec.md — 2-Stage Entity Disambiguation, Trigram Search & Phonetic Matching Engine

## 1. Overview & Disambiguation Problem Statement
When bills are scanned via OCR or spoken via voice commands, extracted customer/vendor names rarely match existing Chart of Accounts ledger names verbatim (e.g., OCR extracts "Shree Ganesh Enterprises Pvt Ltd" while the database stores "Sri Ganesh Ent", or voice mishears spelling variations).

To achieve zero manual data entry without misallocating accounting vouchers, Ledgify implements an in-database **Two-Stage Disambiguation Pipeline** using PostgreSQL native extensions:
1. **Stage 1 (Fast Indexed Shortlist Generation):** Trigram similarity (`pg_trgm`) accelerated via GIST index (`gist_trgm_ops(siglen=32)`) to rapidly narrow tens of thousands of party names down to the top 20 candidate records[cite: 2].
2. **Stage 2 (Precise Edit-Distance & Phonetic Re-ranking):** Bounded Levenshtein distance (`levenshtein_less_equal`) combined with Daitch-Mokotoff Soundex array overlap (`daitch_mokotoff` + `&&`) to re-rank shortlisted candidates[cite: 2].

---

## 2. PostgreSQL Extensions & Technical Architecture

### 2.1 Extension Capabilities & Limitations
- **`pg_trgm`:** Computes trigram overlap ratio (0.0 to 1.0) and word-level similarity (`word_similarity`)[cite: 2]. Supports GIST/GIN indexing and nearest-neighbor distance ordering (`<->`)[cite: 2].
- **`fuzzystrmatch`:**
  - `levenshtein_less_equal(str1, str2, max_d)`: Calculates character edit distances with early-exit abortion when distance exceeds `max_d`[cite: 2]. Maximum string length supported is **255 characters**[cite: 2].
  - `daitch_mokotoff(str)`: Generates 6-digit phonetic code arrays for multilingual/UTF-8 names (unlike English-only standard Soundex)[cite: 2].

---

## 3. Two-Stage Disambiguation Algorithm & Decision Thresholds

                  [OCR / Voice Extracted Party Name]
                                  │
                                  ▼
         [Stage 1: pg_trgm Candidate Retrieval via GIST]
          (Filters on business_id + Trigram distance < 0.7)
          (Retrieves Top 20 Candidates using Index Scan)
                                  │
                                  ▼
         [Stage 2: Precision Re-ranking (Postgres Function)]
          (Computes Bounded Levenshtein + Daitch-Mokotoff Overlap)
                                  │
                                  ▼
                     [Composite Similarity Score]
                                  │
    ┌─────────────────────────────┼─────────────────────────────┐
    ▼                             ▼                             ▼
[Score >= 0.85]             [0.60 <= Score < 0.85]            [Score < 0.60]
Auto-Link to Ledger        Flag for User Review In UI        Suggest Create Master
(Zero User Prompt)          (High-Confidence Suggestion)     (Draft New Ledger Form)


---

## 4. Stored Triggers for Pre-Calculated Phonetic Codes

To eliminate runtime phonetic calculation overhead on large tables, phonetic codes are automatically maintained via database triggers[cite: 2].

```sql
-- Function to maintain Daitch-Mokotoff phonetic code arrays on accounts
CREATE OR REPLACE FUNCTION public.trg_maintain_account_phonetic_codes()
RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN     NEW.daitch_mokotoff_code := daitch_mokotoff(NEW.name);     RETURN NEW; END; $$;

CREATE OR REPLACE TRIGGER trg_accounts_phonetic_sync
BEFORE INSERT OR UPDATE OF name ON public.accounts
FOR EACH ROW
EXECUTE FUNCTION public.trg_maintain_account_phonetic_codes();

-- Function to maintain Daitch-Mokotoff phonetic code arrays on stock_items
CREATE OR REPLACE FUNCTION public.trg_maintain_stock_phonetic_codes()
RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN     NEW.daitch_mokotoff_code := daitch_mokotoff(NEW.name);     RETURN NEW; END; $$;

CREATE OR REPLACE TRIGGER trg_stock_items_phonetic_sync
BEFORE INSERT OR UPDATE OF name ON public.stock_items
FOR EACH ROW
EXECUTE FUNCTION public.trg_maintain_stock_phonetic_codes();
5. PostgreSQL Stored Procedure: Two-Stage Entity Resolution
This function executes the complete 2-stage lookup within a single database roundtrip, honoring tenant RLS scoping[cite: 1, 2].

SQL
CREATE OR REPLACE FUNCTION public.match_ledger_party(
    p_business_id UUID,
    p_search_name VARCHAR(255),
    p_party_gstin VARCHAR(15) DEFAULT NULL,
    p_party_pan VARCHAR(10) DEFAULT NULL
)
RETURNS TABLE (
    account_id UUID,
    account_name VARCHAR(255),
    group_name VARCHAR(100),
    party_gstin VARCHAR(15),
    trgm_score REAL,
    edit_distance INTEGER,
    phonetic_match BOOLEAN,
    final_confidence NUMERIC(5, 4),
    decision_action VARCHAR(20)
) 
LANGUAGE plpgsql STABLE AS $$ DECLARE     v_clean_search VARCHAR(255);     v_search_phonetics TEXT[]; BEGIN     -- 1. Deterministic Match Priority: Exact GSTIN match     IF p_party_gstin IS NOT NULL AND LENGTH(p_party_gstin) = 15 THEN         RETURN QUERY         SELECT              a.id, a.name, a.group_name, a.party_gstin,             1.0::REAL, 0, TRUE, 1.0000::NUMERIC(5, 4),             'AUTO_LINK'::VARCHAR(20)         FROM public.accounts a         WHERE a.business_id = p_business_id            AND a.party_gstin = p_party_gstin           AND a.is_active = TRUE         LIMIT 1;                  IF FOUND THEN RETURN; END IF;     END IF;      -- Clean search string and generate query phonetics     v_clean_search := TRIM(p_search_name);     v_search_phonetics := daitch_mokotoff(v_clean_search);      -- 2. Stage 1 & Stage 2 Execution Pipeline     RETURN QUERY     WITH stage1_shortlist AS (         -- Stage 1: Accelerated Trigram candidate retrieval using GIST index         SELECT              a.id,             a.name,             a.group_name,             a.party_gstin,             a.daitch_mokotoff_code,             similarity(a.name, v_clean_search) AS sim_score,             word_similarity(v_clean_search, a.name) AS word_sim_score         FROM public.accounts a         WHERE a.business_id = p_business_id           AND a.is_active = TRUE           AND (a.name \% v_clean_search OR a.name ILIKE '\%' \vert{}\vert{} v_clean_search \vert{}\vert{} '\%')         ORDER BY a.name <-> v_clean_search ASC         LIMIT 20     ),     stage2_evaluated AS (         -- Stage 2: Precision scoring with bounded Levenshtein and phonetic overlap         SELECT              s.id,             s.name,             s.group_name,             s.party_gstin,             GREATEST(s.sim_score, s.word_sim_score) AS best_trgm,             levenshtein_less_equal(SUBSTRING(s.name, 1, 255), SUBSTRING(v_clean_search, 1, 255), 10) AS lev_dist,             (s.daitch_mokotoff_code && v_search_phonetics) AS is_phonetic         FROM stage1_shortlist s     )     SELECT          e.id AS account_id,         e.name AS account_name,         e.group_name,         e.party_gstin,         e.best_trgm AS trgm_score,         e.lev_dist AS edit_distance,         e.is_phonetic AS phonetic_match,         -- Weighted composite confidence formula         ROUND(             (                 (e.best_trgm * 0.60) +                  (CASE WHEN e.lev_dist <= 2 THEN 0.30 WHEN e.lev_dist <= 5 THEN 0.15 ELSE 0.0 END) +                 (CASE WHEN e.is_phonetic THEN 0.10 ELSE 0.0 END)             )::NUMERIC, 4         ) AS final_confidence,         -- Action determination         CASE              WHEN (e.best_trgm >= 0.85 OR e.lev_dist <= 2) THEN 'AUTO_LINK'::VARCHAR(20)             WHEN (e.best_trgm >= 0.60 OR e.is_phonetic) THEN 'USER_REVIEW'::VARCHAR(20)             ELSE 'CREATE_NEW'::VARCHAR(20)         END AS decision_action     FROM stage2_evaluated e     ORDER BY final_confidence DESC     LIMIT 5; END; $$;
6. Stock Item Disambiguation Function
The same 2-stage methodology is applied to inventory item lookups during bill OCR ingestion[cite: 1, 2].

SQL
CREATE OR REPLACE FUNCTION public.match_stock_item(
    p_business_id UUID,
    p_item_description VARCHAR(255),
    p_hsn_code VARCHAR(8) DEFAULT NULL
)
RETURNS TABLE (
    item_id UUID,
    item_name VARCHAR(255),
    hsn_sac_code VARCHAR(8),
    gst_rate_slab NUMERIC(5, 2),
    confidence_score NUMERIC(5, 4),
    decision_action VARCHAR(20)
)
LANGUAGE plpgsql STABLE AS $$ DECLARE     v_clean_desc VARCHAR(255);     v_desc_phonetics TEXT[]; BEGIN     v_clean_desc := TRIM(p_item_description);     v_desc_phonetics := daitch_mokotoff(v_clean_desc);      RETURN QUERY     WITH item_candidates AS (         SELECT              si.id,             si.name,             si.hsn_sac_code,             si.gst_rate_slab,             GREATEST(similarity(si.name, v_clean_desc), word_similarity(v_clean_desc, si.name)) AS trgm_sim,             levenshtein_less_equal(SUBSTRING(si.name, 1, 255), SUBSTRING(v_clean_desc, 1, 255), 8) AS lev_dist,             (si.daitch_mokotoff_code && v_desc_phonetics) AS phonetic_overlap         FROM public.stock_items si         WHERE si.business_id = p_business_id           AND si.is_active = TRUE           AND (si.name \% v_clean_desc OR (p_hsn_code IS NOT NULL AND si.hsn_sac_code = p_hsn_code))         ORDER BY si.name <-> v_clean_desc ASC         LIMIT 10     )     SELECT          c.id AS item_id,         c.name AS item_name,         c.hsn_sac_code,         c.gst_rate_slab,         ROUND(             (                 (c.trgm_sim * 0.65) +                  (CASE WHEN c.lev_dist <= 2 THEN 0.25 ELSE 0.0 END) +                 (CASE WHEN c.phonetic_overlap THEN 0.10 ELSE 0.0 END)             )::NUMERIC, 4         ) AS confidence_score,         CASE              WHEN (c.trgm_sim >= 0.85 OR c.lev_dist <= 2) THEN 'AUTO_LINK'::VARCHAR(20)             WHEN (c.trgm_sim >= 0.55) THEN 'USER_REVIEW'::VARCHAR(20)             ELSE 'CREATE_NEW'::VARCHAR(20)         END AS decision_action     FROM item_candidates c     ORDER BY confidence_score DESC     LIMIT 1; END; $$;