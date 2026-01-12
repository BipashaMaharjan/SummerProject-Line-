-- ============================================
-- 🔧 FIX ALL NOTIFICATION ERRORS
-- ============================================
-- This script fixes common notification system errors:
-- 1. Missing current_user_email() function
-- 2. Missing token_number column in staff_notifications
-- 3. Verifies all triggers are working
-- ============================================

-- STEP 1: Create the missing current_user_email() function
-- This function is used to get the email of the currently authenticated user
CREATE OR REPLACE FUNCTION current_user_email()
RETURNS TEXT AS $$
BEGIN
  RETURN (SELECT email FROM auth.users WHERE id = auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 2: Add missing token_number column to staff_notifications table
-- This column is required by the notification triggers
ALTER TABLE staff_notifications 
ADD COLUMN IF NOT EXISTS token_number TEXT;

-- STEP 3: Verify the fixes
-- Check if current_user_email function exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.routines 
    WHERE routine_name = 'current_user_email'
  ) THEN
    RAISE NOTICE '✅ current_user_email() function exists';
  ELSE
    RAISE WARNING '❌ current_user_email() function NOT found';
  END IF;
END $$;

-- Check if token_number column exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'staff_notifications' 
      AND column_name = 'token_number'
  ) THEN
    RAISE NOTICE '✅ token_number column exists in staff_notifications';
  ELSE
    RAISE WARNING '❌ token_number column NOT found in staff_notifications';
  END IF;
END $$;

-- STEP 4: List all triggers on the tokens table
-- This helps verify that all notification triggers are in place
SELECT 
  trigger_name,
  event_manipulation,
  action_timing,
  action_statement
FROM information_schema.triggers
WHERE event_object_table = 'tokens'
ORDER BY trigger_name;

-- STEP 5: Test query - Show recent notifications
-- Run this after testing to verify notifications are being created
SELECT 
  id,
  staff_id,
  token_id,
  token_number,
  type,
  message,
  is_read,
  created_at
FROM staff_notifications
ORDER BY created_at DESC
LIMIT 10;

-- ============================================
-- ✅ FIX COMPLETE!
-- ============================================
-- Next steps:
-- 1. Hard refresh your Flutter app (Ctrl+Shift+R)
-- 2. Try the operation that was failing
-- 3. Check browser console (F12) for any errors
-- 4. Verify notifications appear in staff dashboard
-- ============================================
