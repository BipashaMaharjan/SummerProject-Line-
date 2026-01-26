-- ============================================
-- 🎯 FIX TOKEN AUTO-REJECTION LOGIC
-- ============================================
-- Issue: Tokens are being rejected even if user arrived
-- Fix: Only reject tokens where user did NOT arrive by scheduled date
-- ============================================

-- Update the auto-rejection function to check arrival status
CREATE OR REPLACE FUNCTION auto_reject_no_show_tokens()
RETURNS INTEGER AS $$
DECLARE
    v_rejected_count INTEGER;
BEGIN
    -- Reject tokens where:
    -- 1. Status is still 'waiting' (not arrived, not processing)
    -- 2. Scheduled date has passed (e.g., booked for 5 Magh, now it's 6 Magh)
    -- 3. Grace period of 1 day has passed
    -- 4. ✅ NEW: User never marked themselves as arrived (arrived_at IS NULL)
    
    WITH rejected_tokens AS (
        UPDATE tokens
        SET 
            status = 'rejected',
            notes = 'Auto-rejected: Did not arrive by scheduled date',
            updated_at = NOW()
        WHERE status = 'waiting'
          AND scheduled_date IS NOT NULL
          AND scheduled_date < CURRENT_DATE - INTERVAL '1 day'  -- 1 day grace period
          AND arrived_at IS NULL  -- ✅ CRITICAL FIX: Only reject if user never arrived
        RETURNING id, token_number
    )
    SELECT COUNT(*) INTO v_rejected_count FROM rejected_tokens;
    
    IF v_rejected_count > 0 THEN
        RAISE NOTICE 'Auto-rejected % tokens for no-show (did not arrive by scheduled date)', v_rejected_count;
    END IF;
    
    RETURN v_rejected_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- EXPLANATION OF THE FIX
-- ============================================
-- 
-- BEFORE (BROKEN):
-- - Token booked for Jan 20, status = 'waiting', scheduled_date = '2026-01-20'
-- - User arrives on Jan 20 and marks as arrived (status changes to 'arrived')
-- - Later, status might change back to 'waiting' when processing starts
-- - Auto-rejection runs and rejects the token because scheduled_date < today
-- 
-- AFTER (FIXED):
-- - Token booked for Jan 20, status = 'waiting', scheduled_date = '2026-01-20'
-- - User arrives on Jan 20 and marks as arrived (arrived_at = '2026-01-20 09:00:00')
-- - Even if status changes, arrived_at timestamp remains
-- - Auto-rejection runs but SKIPS this token because arrived_at IS NOT NULL
-- - Only tokens where user never showed up (arrived_at IS NULL) get rejected
-- 
-- ============================================

-- Grant permission to authenticated users (for manual testing)
GRANT EXECUTE ON FUNCTION auto_reject_no_show_tokens() TO authenticated;

-- ✅ FIX COMPLETE!
-- This function now correctly handles the scenario where:
-- 1. User books a token for a future date
-- 2. User arrives on that date and marks themselves as arrived
-- 3. Token should NOT be auto-rejected
-- 
-- Only tokens where the user never arrived (arrived_at IS NULL) 
-- and the scheduled date has passed will be rejected.

SELECT 'SUCCESS: Auto-rejection logic fixed to check arrival status!' as status;
