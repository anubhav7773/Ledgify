-- ==============================================================================
-- Migration: 20260831000014_active_learning_and_alias_cache.sql
-- Description: Active Learning Feedback Loop, Phonetic Alias Expansion & Disambiguation Cache
-- Specification: docs/07_fuzzy_entity_matching_spec.md & docs/03_security_auth_and_rls_matrix.md
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Entity Disambiguation Cache Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.entity_disambiguation_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    raw_query_text TEXT NOT NULL,
    entity_type VARCHAR(20) NOT NULL CHECK (entity_type IN ('ACCOUNT', 'STOCK_ITEM')),
    resolved_entity_id UUID NOT NULL,
    hit_count INTEGER DEFAULT 1,
    last_used_at TIMESTAMPTZ DEFAULT clock_timestamp(),
    created_at TIMESTAMPTZ DEFAULT clock_timestamp(),
    CONSTRAINT uq_entity_cache_query UNIQUE (business_id, entity_type, raw_query_text)
);

CREATE INDEX IF NOT EXISTS idx_disambiguation_cache_lookup 
ON public.entity_disambiguation_cache(business_id, entity_type, raw_query_text);

CREATE INDEX IF NOT EXISTS trgm_idx_disambiguation_cache_raw 
ON public.entity_disambiguation_cache USING gin (raw_query_text gin_trgm_ops);

-- ------------------------------------------------------------------------------
-- 2. Active Learning Feedback Stored Procedure
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_entity_resolution_feedback(
    p_business_id UUID,
    p_raw_query_text TEXT,
    p_entity_type VARCHAR(20),
    p_resolved_entity_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_query TEXT;
    v_new_phonetics TEXT[];
BEGIN
    v_clean_query := TRIM(p_raw_query_text);
    IF v_clean_query = '' THEN RETURN; END IF;

    -- 1. Upsert into Disambiguation Cache
    INSERT INTO public.entity_disambiguation_cache (
        business_id,
        raw_query_text,
        entity_type,
        resolved_entity_id,
        hit_count,
        last_used_at
    ) VALUES (
        p_business_id,
        v_clean_query,
        p_entity_type,
        p_resolved_entity_id,
        1,
        clock_timestamp()
    )
    ON CONFLICT (business_id, entity_type, raw_query_text)
    DO UPDATE SET
        resolved_entity_id = EXCLUDED.resolved_entity_id,
        hit_count = public.entity_disambiguation_cache.hit_count + 1,
        last_used_at = clock_timestamp();

    v_new_phonetics := daitch_mokotoff(v_clean_query);

    -- 2. Expand Aliases & Phonetic Tokens on target Account
    IF p_entity_type = 'ACCOUNT' THEN
        UPDATE public.accounts
        SET 
            alias = CASE 
                WHEN alias IS NULL OR alias = '' THEN v_clean_query
                WHEN alias NOT ILIKE '%' || v_clean_query || '%' THEN alias || ', ' || v_clean_query
                ELSE alias
            END,
            daitch_mokotoff_code = (
                SELECT ARRAY(
                    SELECT DISTINCT unnest(COALESCE(daitch_mokotoff_code, ARRAY[]::TEXT[]) || v_new_phonetics)
                )
            ),
            updated_at = clock_timestamp()
        WHERE id = p_resolved_entity_id AND business_id = p_business_id;

    -- 3. Expand Aliases & Phonetic Tokens on target Stock Item
    ELSIF p_entity_type = 'STOCK_ITEM' THEN
        UPDATE public.stock_items
        SET 
            alias = CASE 
                WHEN alias IS NULL OR alias = '' THEN v_clean_query
                WHEN alias NOT ILIKE '%' || v_clean_query || '%' THEN alias || ', ' || v_clean_query
                ELSE alias
            END,
            daitch_mokotoff_code = (
                SELECT ARRAY(
                    SELECT DISTINCT unnest(COALESCE(daitch_mokotoff_code, ARRAY[]::TEXT[]) || v_new_phonetics)
                )
            ),
            updated_at = clock_timestamp()
        WHERE id = p_resolved_entity_id AND business_id = p_business_id;
    END IF;
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. High-Speed Cache-First Search Stored Procedure
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.match_entity_with_cache(
    p_business_id UUID,
    p_query_text TEXT,
    p_entity_type VARCHAR(20) DEFAULT 'ACCOUNT',
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
    v_cached_id UUID;
    v_clean_query TEXT;
BEGIN
    v_clean_query := TRIM(p_query_text);

    -- 1. Check exact cache match
    SELECT resolved_entity_id INTO v_cached_id
    FROM public.entity_disambiguation_cache
    WHERE business_id = p_business_id
      AND entity_type = p_entity_type
      AND raw_query_text = v_clean_query
    LIMIT 1;

    -- 2. If Cache Hit: Return target record with 1.0 confidence
    IF v_cached_id IS NOT NULL THEN
        IF p_entity_type = 'ACCOUNT' THEN
            RETURN QUERY
            SELECT 
                a.id AS entity_id,
                a.name::TEXT AS entity_name,
                a.primary_classification::TEXT,
                a.group_name::TEXT,
                1.0::REAL AS composite_score,
                'EXACT_CACHE_HIT'::TEXT AS match_reason
            FROM public.accounts a
            WHERE a.id = v_cached_id AND a.business_id = p_business_id AND a.is_active = TRUE;
            
            IF FOUND THEN RETURN; END IF;
        ELSIF p_entity_type = 'STOCK_ITEM' THEN
            RETURN QUERY
            SELECT 
                si.id AS entity_id,
                si.name::TEXT AS entity_name,
                'Inventory'::TEXT AS primary_classification,
                si.hsn_sac_code::TEXT AS group_name,
                1.0::REAL AS composite_score,
                'EXACT_CACHE_HIT'::TEXT AS match_reason
            FROM public.stock_items si
            WHERE si.id = v_cached_id AND si.business_id = p_business_id AND si.is_active = TRUE;
            
            IF FOUND THEN RETURN; END IF;
        END IF;
    END IF;

    -- 3. Cache Miss: Fall back to Two-Stage Hybrid Search
    RETURN QUERY
    SELECT * FROM public.match_entity_hybrid(
        p_business_id,
        v_clean_query,
        p_entity_type,
        p_max_candidates
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 4. Row Level Security for Disambiguation Cache
-- ------------------------------------------------------------------------------
ALTER TABLE public.entity_disambiguation_cache ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.entity_disambiguation_cache FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.entity_disambiguation_cache TO authenticated;

DROP POLICY IF EXISTS "guard_entity_disambiguation_cache" ON public.entity_disambiguation_cache;
CREATE POLICY "guard_entity_disambiguation_cache" ON public.entity_disambiguation_cache
AS RESTRICTIVE TO authenticated
USING (public.is_valid_project_jwt() IS TRUE);

DROP POLICY IF EXISTS "tenant_isolation_entity_disambiguation_cache" ON public.entity_disambiguation_cache;
CREATE POLICY "tenant_isolation_entity_disambiguation_cache" ON public.entity_disambiguation_cache
FOR ALL TO authenticated
USING ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text)
WITH CHECK ((select auth.jwt() -> 'app_metadata' ->> 'business_id') = business_id::text);

GRANT EXECUTE ON FUNCTION public.record_entity_resolution_feedback(UUID, TEXT, VARCHAR, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.match_entity_with_cache(UUID, TEXT, VARCHAR, INTEGER) TO authenticated;

COMMIT;
