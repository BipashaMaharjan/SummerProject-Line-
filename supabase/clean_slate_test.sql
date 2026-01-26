-- ============================================
-- 🧹 CLEAN SLATE FOR PROXIMITY TEST
-- ============================================
-- Run this in Supabase SQL Editor to clear today's queue
-- and reset everything for a fresh test.
-- ============================================

-- 1. Delete today's notifications
DELETE FROM user_notifications 
WHERE created_at::date = CURRENT_DATE;

-- 2. Delete today's tokens
DELETE FROM tokens 
WHERE created_at::date = CURRENT_DATE 
   OR scheduled_date::date = CURRENT_DATE;

-- 3. Reset token counters for today
DELETE FROM token_counters 
WHERE last_reset_date = CURRENT_DATE;

-- 4. Re-run the master fix to ensure all triggers are fresh
-- (You can copy-paste the contents of fix_auto_rejection_and_notifications.sql here 
-- or just run this script first, then re-run that one).

COMMIT;
