-- ============================================
-- 🎯 MASTER TOKEN EXPIRY & AUTO-REJECTION (v3 - BULLETPROOF)
-- ============================================
-- This script ensures that stale tokens from previous days 
-- are explicitly marked as 'no_show'.
-- ============================================

CREATE OR REPLACE FUNCTION public.auto_reject_no_show_tokens()
RETURNS INTEGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rejected_count INTEGER;
BEGIN
    -- Reject tokens where:
    -- 1. Status is 'waiting', 'arrived', or 'hold'
    -- 2. Scheduled date or booking date is older than today (UTC-aware)
    
    WITH rejected_tokens AS (
        UPDATE public.tokens
        SET 
            status = 'no_show',
            notes = COALESCE(notes || ' | ', '') || 'System: Auto-marked as no-show (Process Date: ' || CURRENT_DATE || ')',
            updated_at = NOW()
        WHERE status IN ('waiting', 'arrived', 'hold')
          AND (
            -- Case 1: Past scheduled date
            (scheduled_date IS NOT NULL AND scheduled_date < CURRENT_DATE)
            OR
            -- Case 2: Past booking date or creation date (for walk-ins)
            (scheduled_date IS NULL AND (
                COALESCE(booked_at, created_at)::date < CURRENT_DATE
            ))
          )
          -- Insurance: Ensure we don't touch tokens already being served or done
          AND status NOT IN ('processing', 'completed', 'cancelled', 'rejected')
        RETURNING id
    )
    SELECT COUNT(*) INTO v_rejected_count FROM rejected_tokens;
    
    -- Log result for Supabase SQL Editor visibility
    IF v_rejected_count > 0 THEN
        RAISE NOTICE 'SUCCESS: Marked % stale tokens as no-show.', v_rejected_count;
    ELSE
        RAISE NOTICE 'INFO: No stale tokens found to expire.';
    END IF;
    
    RETURN v_rejected_count;
END;
$$;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION public.auto_reject_no_show_tokens() TO authenticated;
GRANT EXECUTE ON FUNCTION public.auto_reject_no_show_tokens() TO service_role;

-- Notify PostgREST to refresh schema cache
NOTIFY pgrst, 'reload schema';

-- ============================================
-- 🚀 MANUAL EXECUTION (Run this to fix existing tokens immediately)
-- ============================================
SELECT auto_reject_no_show_tokens() as rejected_count;
