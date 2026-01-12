-- ============================================
-- 🚀 QUICK FIX - Run This First
-- ============================================
-- This adds the missing column that's causing errors
-- ============================================

-- Add missing token_number column
ALTER TABLE staff_notifications 
ADD COLUMN IF NOT EXISTS token_number TEXT;

-- That's it! Now test your app.
-- If you still get errors, run SIMPLE_FIX_REMOVE_ERRORS.sql
