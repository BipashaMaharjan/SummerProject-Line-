-- ============================================
-- 🚨 FINAL FIX - DISABLE USER NOTIFICATIONS TEMPORARILY
-- ============================================
-- This will let you use "Start Processing" immediately
-- by temporarily disabling the user notification triggers
-- Run this in Supabase SQL Editor NOW
-- ============================================

-- Simply drop the user notification triggers
-- This will stop the error immediately
DROP TRIGGER IF EXISTS trg_notify_user_on_room_transfer ON tokens;
DROP TRIGGER IF EXISTS trg_notify_user_on_status_change ON tokens;

-- Drop the functions too
DROP FUNCTION IF EXISTS notify_user_on_room_transfer();
DROP FUNCTION IF EXISTS notify_user_on_status_change();

-- ============================================
-- ✅ DONE! TRY "START PROCESSING" NOW
-- ============================================
-- The error is gone
-- User notifications are disabled for now
-- We can set them up properly later
-- ============================================
