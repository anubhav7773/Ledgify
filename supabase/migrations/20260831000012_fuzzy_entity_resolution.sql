-- ==============================================================================
-- Migration: 20260831000012_fuzzy_entity_resolution.sql
-- Description: Two-Stage Hybrid Entity Resolution Engine (Trigram + Levenshtein + Daitch-Mokotoff)
-- Specification: docs/07_fuzzy_entity_matching_spec.md & docs/02_database_schema_ddl_and_indexes.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Two-Stage Hybrid Entity Disambiguation Stored Function
-- Combines GIST Trigram candidate generation with Levenshtein and Phonetic rescoring
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.match_entity_hybrid(
    p_business_id UUID,
    p_query_text TEXT,
    p_entity_type VARCHAR(20) DEFAULT 'ACCOUNT', -- 'ACCOUNT' or 'STOCK_ITEM'
    p_max_candidates INTEGER DEFAULT 5
)
RETURNS TABLE (
    entity_id UUID,
    entity_name TEXT,
    primary_classification TEXT,
    group_name TEXT,
    composite_score REAL,
    match_reason TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_clean_query TEXT;
    v_query_phonetics TEXT[];
    v_query_len INTEGER;
BEGIN
    v_clean_query := TRIM(p_query_text);
    v_query_len := GREATEST(1, LENGTH(v_clean_query));
    v_query_phonetics := daitch_mokotoff(v_clean_query);

    IF p_entity_type = 'ACCOUNT' THEN
        RETURN QUERY
        WITH candidate_pool AS (
            -- Stage 1: Fast Candidate Generation via GIST Trigram index & GIN Phonetic array
            SELECT 
                a.id,
                a.name,
                a.primary_classification,
                a.group_name,
                a.daitch_mokotoff_code,
                similarity(a.name, v_clean_query) AS trgm_sim,
                word_similarity(v_clean_query, a.name) AS word_sim,
                (a.daitch_mokotoff_code && v_query_phonetics) AS phonetic_match
            FROM public.accounts a
            WHERE a.business_id = p_business_id
              AND a.is_active = TRUE
              AND (
                  a.name % v_clean_query 
                  OR a.name ILIKE '%' || v_clean_query || '%'
                  OR (a.daitch_mokotoff_code && v_query_phonetics)
              )
            ORDER BY a.name <-> v_clean_query ASC
            LIMIT 20
        ),
        rescored_candidates AS (
            -- Stage 2: Precision Rescoring with Bounded Levenshtein & Weighted Composite Formula
            SELECT 
                c.id,
                c.name,
                c.primary_classification,
                c.group_name,
                GREATEST(c.trgm_sim, c.word_sim) AS best_trgm,
                1.0 - (LEAST(levenshtein(LOWER(SUBSTRING(c.name, 1, 255)), LOWER(SUBSTRING(v_clean_query, 1, 255))), GREATEST(v_query_len, LENGTH(c.name)))::REAL / GREATEST(v_query_len, LENGTH(c.name))::REAL) AS lev_score,
                CASE WHEN c.phonetic_match THEN 0.20::REAL ELSE 0.00::REAL END AS phon_boost
            FROM candidate_pool c
        )
        SELECT 
            r.id AS entity_id,
            r.name::TEXT AS entity_name,
            r.primary_classification::TEXT,
            r.group_name::TEXT,
            LEAST(1.0::REAL, ((0.50 * r.best_trgm) + (0.30 * r.lev_score) + r.phon_boost))::REAL AS composite_score,
            CASE 
                WHEN r.best_trgm >= 0.85 THEN 'HIGH_TRIGRAM_MATCH'
                WHEN r.phon_boost > 0 THEN 'PHONETIC_SOUNDEX_MATCH'
                ELSE 'PARTIAL_LEVENSHTEIN_MATCH'
            END AS match_reason
        FROM rescored_candidates r
        ORDER BY composite_score DESC
        LIMIT p_max_candidates;

    ELSIF p_entity_type = 'STOCK_ITEM' THEN
        RETURN QUERY
        WITH candidate_pool AS (
            SELECT 
                si.id,
                si.name,
                'Inventory' AS primary_classification,
                si.hsn_sac_code AS group_name,
                si.daitch_mokotoff_code,
                similarity(si.name, v_clean_query) AS trgm_sim,
                word_similarity(v_clean_query, si.name) AS word_sim,
                (si.daitch_mokotoff_code && v_query_phonetics) AS phonetic_match
            FROM public.stock_items si
            WHERE si.business_id = p_business_id
              AND si.is_active = TRUE
              AND (
                  si.name % v_clean_query 
                  OR si.name ILIKE '%' || v_clean_query || '%'
                  OR (si.daitch_mokotoff_code && v_query_phonetics)
              )
            ORDER BY si.name <-> v_clean_query ASC
            LIMIT 20
        ),
        rescored_candidates AS (
            SELECT 
                c.id,
                c.name,
                c.primary_classification,
                c.group_name,
                GREATEST(c.trgm_sim, c.word_sim) AS best_trgm,
                1.0 - (LEAST(levenshtein(LOWER(SUBSTRING(c.name, 1, 255)), LOWER(SUBSTRING(v_clean_query, 1, 255))), GREATEST(v_query_len, LENGTH(c.name)))::REAL / GREATEST(v_query_len, LENGTH(c.name))::REAL) AS lev_score,
                CASE WHEN c.phonetic_match THEN 0.20::REAL ELSE 0.00::REAL END AS phon_boost
            FROM candidate_pool c
        )
        SELECT 
            r.id AS entity_id,
            r.name::TEXT AS entity_name,
            r.primary_classification::TEXT,
            r.group_name::TEXT,
            LEAST(1.0::REAL, ((0.50 * r.best_trgm) + (0.30 * r.lev_score) + r.phon_boost))::REAL AS composite_score,
            CASE 
                WHEN r.best_trgm >= 0.85 THEN 'HIGH_TRIGRAM_MATCH'
                WHEN r.phon_boost > 0 THEN 'PHONETIC_SOUNDEX_MATCH'
                ELSE 'PARTIAL_LEVENSHTEIN_MATCH'
            END AS match_reason
        FROM rescored_candidates r
        ORDER BY composite_score DESC
        LIMIT p_max_candidates;
    END IF;
END;
$$;

-- ------------------------------------------------------------------------------
-- 2. Party Disambiguation Procedure (Direct Ledger Resolution with GSTIN Priority)
-- ------------------------------------------------------------------------------
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
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_clean_search VARCHAR(255);
    v_search_phonetics TEXT[];
BEGIN
    -- 1. Exact GSTIN match priority
    IF p_party_gstin IS NOT NULL AND LENGTH(p_party_gstin) = 15 THEN
        RETURN QUERY
        SELECT 
            a.id, a.name, a.group_name, a.party_gstin,
            1.0::REAL, 0, TRUE, 1.0000::NUMERIC(5, 4),
            'AUTO_LINK'::VARCHAR(20)
        FROM public.accounts a
        WHERE a.business_id = p_business_id 
          AND a.party_gstin = p_party_gstin
          AND a.is_active = TRUE
        LIMIT 1;
        
        IF FOUND THEN RETURN; END IF;
    END IF;

    v_clean_search := TRIM(p_search_name);
    v_search_phonetics := daitch_mokotoff(v_clean_search);

    -- 2. Stage 1 & Stage 2 Execution Pipeline
    RETURN QUERY
    WITH stage1_shortlist AS (
        SELECT 
            a.id,
            a.name,
            a.group_name,
            a.party_gstin,
            a.daitch_mokotoff_code,
            similarity(a.name, v_clean_search) AS sim_score,
            word_similarity(v_clean_search, a.name) AS word_sim_score
        FROM public.accounts a
        WHERE a.business_id = p_business_id
          AND a.is_active = TRUE
          AND (a.name % v_clean_search OR a.name ILIKE '%' || v_clean_search || '%')
        ORDER BY a.name <-> v_clean_search ASC
        LIMIT 20
    ),
    stage2_evaluated AS (
        SELECT 
            s.id,
            s.name,
            s.group_name,
            s.party_gstin,
            GREATEST(s.sim_score, s.word_sim_score) AS best_trgm,
            levenshtein_less_equal(SUBSTRING(s.name, 1, 255), SUBSTRING(v_clean_search, 1, 255), 10) AS lev_dist,
            (s.daitch_mokotoff_code && v_search_phonetics) AS is_phonetic
        FROM stage1_shortlist s
    )
    SELECT 
        e.id AS account_id,
        e.name AS account_name,
        e.group_name,
        e.party_gstin,
        e.best_trgm AS trgm_score,
        e.lev_dist AS edit_distance,
        e.is_phonetic AS phonetic_match,
        ROUND(
            (
                (e.best_trgm * 0.60) + 
                (CASE WHEN e.lev_dist <= 2 THEN 0.30 WHEN e.lev_dist <= 5 THEN 0.15 ELSE 0.0 END) +
                (CASE WHEN e.is_phonetic THEN 0.10 ELSE 0.0 END)
            )::NUMERIC, 4
        ) AS final_confidence,
        CASE 
            WHEN (e.best_trgm >= 0.85 OR e.lev_dist <= 2) THEN 'AUTO_LINK'::VARCHAR(20)
            WHEN (e.best_trgm >= 0.60 OR e.is_phonetic) THEN 'USER_REVIEW'::VARCHAR(20)
            ELSE 'CREATE_NEW'::VARCHAR(20)
        END AS decision_action
    FROM stage2_evaluated e
    ORDER BY final_confidence DESC
    LIMIT 5;
END;
$$;

GRANT EXECUTE ON FUNCTION public.match_entity_hybrid(UUID, TEXT, VARCHAR, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.match_ledger_party(UUID, VARCHAR, VARCHAR, VARCHAR) TO authenticated;

COMMIT;
