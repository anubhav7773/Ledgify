-- ==============================================================================
-- Migration: 20260831000013_inventory_fuzzy_resolution.sql
-- Description: Inventory Fuzzy Item Resolution, HSN Auto-Linking & Quick Stock Item Creation
-- Specification: docs/07_fuzzy_entity_matching_spec.md & docs/02_database_schema_ddl_and_indexes.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Stock Item Match & HSN Auto-Fill Stored Function
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.resolve_stock_item_and_hsn(
    p_business_id UUID,
    p_item_query TEXT,
    p_extracted_hsn TEXT DEFAULT NULL
)
RETURNS TABLE (
    stock_item_id UUID,
    item_name TEXT,
    hsn_sac_code TEXT,
    gst_rate_slab NUMERIC,
    uqc TEXT,
    composite_score REAL,
    resolution_status TEXT
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
    v_clean_query := TRIM(p_item_query);
    v_query_len := GREATEST(1, LENGTH(v_clean_query));
    v_query_phonetics := daitch_mokotoff(v_clean_query);

    RETURN QUERY
    WITH candidate_pool AS (
        -- Stage 1: Candidate Generation via GIST Trigram & Phonetics & Exact HSN Match
        SELECT 
            si.id,
            si.name,
            si.hsn_sac_code,
            si.gst_rate_slab,
            si.uqc,
            si.daitch_mokotoff_code,
            similarity(si.name, v_clean_query) AS trgm_sim,
            word_similarity(v_clean_query, si.name) AS word_sim,
            (si.daitch_mokotoff_code && v_query_phonetics) AS phonetic_match,
            (p_extracted_hsn IS NOT NULL AND si.hsn_sac_code = p_extracted_hsn) AS hsn_exact_match
        FROM public.stock_items si
        WHERE si.business_id = p_business_id
          AND si.is_active = TRUE
          AND (
              si.name % v_clean_query 
              OR si.name ILIKE '%' || v_clean_query || '%'
              OR (si.daitch_mokotoff_code && v_query_phonetics)
              OR (p_extracted_hsn IS NOT NULL AND si.hsn_sac_code = p_extracted_hsn)
          )
        ORDER BY si.name <-> v_clean_query ASC
        LIMIT 20
    ),
    rescored AS (
        -- Stage 2: Precision scoring with Levenshtein, Phonetics & HSN boost
        SELECT 
            c.id,
            c.name,
            c.hsn_sac_code,
            c.gst_rate_slab,
            c.uqc,
            GREATEST(c.trgm_sim, c.word_sim) AS best_trgm,
            1.0 - (LEAST(levenshtein(LOWER(SUBSTRING(c.name, 1, 255)), LOWER(SUBSTRING(v_clean_query, 1, 255))), GREATEST(v_query_len, LENGTH(c.name)))::REAL / GREATEST(v_query_len, LENGTH(c.name))::REAL) AS lev_score,
            CASE WHEN c.phonetic_match THEN 0.15::REAL ELSE 0.00::REAL END AS phon_boost,
            CASE WHEN c.hsn_exact_match THEN 0.15::REAL ELSE 0.00::REAL END AS hsn_boost
        FROM candidate_pool c
    )
    SELECT 
        r.id AS stock_item_id,
        r.name::TEXT AS item_name,
        r.hsn_sac_code::TEXT,
        r.gst_rate_slab,
        r.uqc::TEXT,
        LEAST(1.0::REAL, ((0.50 * r.best_trgm) + (0.25 * r.lev_score) + r.phon_boost + r.hsn_boost))::REAL AS composite_score,
        CASE 
            WHEN LEAST(1.0::REAL, ((0.50 * r.best_trgm) + (0.25 * r.lev_score) + r.phon_boost + r.hsn_boost)) >= 0.85 THEN 'AUTO_MATCHED'
            WHEN LEAST(1.0::REAL, ((0.50 * r.best_trgm) + (0.25 * r.lev_score) + r.phon_boost + r.hsn_boost)) >= 0.50 THEN 'AMBIGUOUS_SUGGESTION'
            ELSE 'NEEDS_CREATION'
        END AS resolution_status
    FROM rescored r
    ORDER BY composite_score DESC
    LIMIT 5;
END;
$$;

-- ------------------------------------------------------------------------------
-- 2. Quick Stock Item Creation Stored Procedure
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.quick_create_stock_item(
    p_business_id UUID,
    p_name TEXT,
    p_group_id UUID DEFAULT NULL,
    p_hsn_sac_code TEXT DEFAULT '998311',
    p_gst_rate_slab NUMERIC DEFAULT 18.00,
    p_uqc VARCHAR(10) DEFAULT 'NOS',
    p_opening_qty NUMERIC(15, 3) DEFAULT 0.000,
    p_opening_rate NUMERIC(15, 2) DEFAULT 0.00
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_item_id UUID;
    v_opening_val NUMERIC(15, 2);
BEGIN
    -- Statutory GST Rate Slab Validation (0, 0.1, 0.25, 3, 5, 12, 18, 28)
    IF p_gst_rate_slab NOT IN (0.00, 0.10, 0.25, 3.00, 5.00, 12.00, 18.00, 28.00) THEN
        RAISE EXCEPTION 'Invalid GST rate slab %. Must be one of: 0, 0.1, 0.25, 3, 5, 12, 18, 28', p_gst_rate_slab
            USING ERRCODE = '23514';
    END IF;

    v_opening_val := ROUND(p_opening_qty * p_opening_rate, 2);

    INSERT INTO public.stock_items (
        business_id,
        group_id,
        name,
        uqc,
        hsn_sac_code,
        gst_rate_slab,
        costing_method,
        opening_quantity,
        opening_rate,
        opening_value,
        is_active
    ) VALUES (
        p_business_id,
        p_group_id,
        TRIM(p_name),
        UPPER(TRIM(p_uqc)),
        TRIM(p_hsn_sac_code),
        p_gst_rate_slab,
        'FIFO',
        p_opening_qty,
        p_opening_rate,
        v_opening_val,
        TRUE
    )
    RETURNING id INTO v_new_item_id;

    RETURN v_new_item_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_stock_item_and_hsn(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.quick_create_stock_item(UUID, TEXT, UUID, TEXT, NUMERIC, VARCHAR, NUMERIC, NUMERIC) TO authenticated;

COMMIT;
