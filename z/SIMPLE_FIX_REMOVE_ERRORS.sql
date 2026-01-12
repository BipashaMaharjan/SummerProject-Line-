-- ============================================
-- 🔧 SIMPLIFIED FIX - Remove Missing Functions
-- ============================================
-- This script finds and removes references to
-- current_user_email() function that doesn't exist
-- ============================================

-- STEP 1: Add missing token_number column (if needed)
ALTER TABLE staff_notifications 
ADD COLUMN IF NOT EXISTS token_number TEXT;

-- STEP 2: Find all functions that reference current_user_email
-- Run this to see what needs to be fixed
SELECT 
  routine_name,
  routine_type,
  routine_definition
FROM information_schema.routines
WHERE routine_definition ILIKE '%current_user_email%'
  AND routine_schema = 'public';

-- STEP 3: Find all triggers that might be calling it
SELECT 
  trigger_name,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE action_statement ILIKE '%current_user_email%';

-- STEP 4: Find all RLS policies that might be using it
SELECT 
  schemaname,
  tablename,
  policyname,
  qual,
  with_check
FROM pg_policies
WHERE qual::text ILIKE '%current_user_email%'
   OR with_check::text ILIKE '%current_user_email%';

-- ============================================
-- STEP 5: Drop any problematic functions
-- ============================================
-- If you find any functions above that use current_user_email,
-- you can drop them here. Common ones might be:

-- Example (uncomment if needed):
-- DROP FUNCTION IF EXISTS some_function_name CASCADE;

-- ============================================
-- STEP 6: Recreate notification triggers WITHOUT current_user_email
-- ============================================
-- These are the safe versions from REALTIME_NOTIFICATIONS_SETUP.sql
-- They don't use current_user_email()

-- Token Transfer Notification Trigger
CREATE OR REPLACE FUNCTION notify_on_token_transfer()
RETURNS TRIGGER AS $$
DECLARE
  v_new_staff_id UUID;
  v_previous_staff_id UUID;
  v_new_room_name TEXT;
  v_previous_room_name TEXT;
BEGIN
  IF NEW.current_room_id IS DISTINCT FROM OLD.current_room_id THEN
    SELECT name INTO v_new_room_name FROM rooms WHERE id = NEW.current_room_id;
    
    IF OLD.current_room_id IS NOT NULL THEN
      SELECT name INTO v_previous_room_name FROM rooms WHERE id = OLD.current_room_id;
    END IF;

    SELECT id INTO v_new_staff_id 
    FROM profiles 
    WHERE assigned_room_id = NEW.current_room_id AND role = 'staff'
    LIMIT 1;

    IF OLD.current_room_id IS NOT NULL THEN
      SELECT id INTO v_previous_staff_id 
      FROM profiles 
      WHERE assigned_room_id = OLD.current_room_id AND role = 'staff'
      LIMIT 1;
    END IF;

    IF v_new_staff_id IS NOT NULL THEN
      INSERT INTO staff_notifications (
        staff_id, token_id, token_number, type, message,
        previous_room_id, previous_room_name,
        new_room_id, new_room_name,
        previous_status, new_status, is_read, created_at
      ) VALUES (
        v_new_staff_id,
        NEW.id,
        NEW.token_number,
        'tokenTransfer',
        'New token received — Token #' || NEW.token_number || ' has been transferred to you' ||
        CASE WHEN v_previous_room_name IS NOT NULL 
             THEN ' from ' || v_previous_room_name 
             ELSE '' 
        END,
        OLD.current_room_id,
        v_previous_room_name,
        NEW.current_room_id,
        v_new_room_name,
        OLD.status,
        NEW.status,
        FALSE,
        NOW()
      );
    END IF;

    IF v_previous_staff_id IS NOT NULL AND v_previous_staff_id != v_new_staff_id THEN
      INSERT INTO staff_notifications (
        staff_id, token_id, token_number, type, message,
        previous_room_id, previous_room_name,
        new_room_id, new_room_name,
        previous_status, new_status, is_read, created_at
      ) VALUES (
        v_previous_staff_id,
        NEW.id,
        NEW.token_number,
        'transferredOut',
        'Token transferred — Token #' || NEW.token_number || ' has been transferred to ' || 
        COALESCE(v_new_room_name, 'next room'),
        OLD.current_room_id,
        v_previous_room_name,
        NEW.current_room_id,
        v_new_room_name,
        OLD.status,
        NEW.status,
        FALSE,
        NOW()
      );
    END IF;

    INSERT INTO staff_notifications (
      staff_id, token_id, token_number, type, message,
      previous_room_id, previous_room_name,
      new_room_id, new_room_name,
      previous_status, new_status, is_read, created_at
    )
    SELECT 
      p.id,
      NEW.id,
      NEW.token_number,
      'admin',
      'Token transferred — Token #' || NEW.token_number || ' moved from ' ||
      COALESCE(v_previous_room_name, 'N/A') || ' to ' ||
      COALESCE(v_new_room_name, 'N/A'),
      OLD.current_room_id,
      v_previous_room_name,
      NEW.current_room_id,
      v_new_room_name,
      OLD.status,
      NEW.status,
      FALSE,
      NOW()
    FROM profiles p
    WHERE p.role = 'admin';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Token Status Change Notification Trigger
CREATE OR REPLACE FUNCTION notify_on_token_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_staff_id UUID;
  v_room_name TEXT;
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF OLD.status IS NULL AND NEW.status = 'waiting' THEN
      RETURN NEW;
    END IF;

    SELECT id INTO v_staff_id FROM profiles WHERE id = NEW.assigned_staff_id;
    SELECT name INTO v_room_name FROM rooms WHERE id = NEW.current_room_id;

    IF v_staff_id IS NOT NULL THEN
      INSERT INTO staff_notifications (
        staff_id, token_id, token_number, type, message,
        new_room_id, new_room_name,
        previous_status, new_status, is_read, created_at
      ) VALUES (
        v_staff_id,
        NEW.id,
        NEW.token_number,
        'statusChange',
        'Status update — Token #' || NEW.token_number || ' status changed from ' ||
        OLD.status || ' to ' || NEW.status,
        NEW.current_room_id,
        v_room_name,
        OLD.status,
        NEW.status,
        FALSE,
        NOW()
      );
    END IF;

    INSERT INTO staff_notifications (
      staff_id, token_id, token_number, type, message,
      new_room_id, new_room_name,
      previous_status, new_status, is_read, created_at
    )
    SELECT 
      p.id,
      NEW.id,
      NEW.token_number,
      'admin',
      'Status update — Token #' || NEW.token_number || ' status changed from ' ||
      OLD.status || ' to ' || NEW.status,
      NEW.current_room_id,
      v_room_name,
      OLD.status,
      NEW.status,
      FALSE,
      NOW()
    FROM profiles p
    WHERE p.role = 'admin';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Token Assignment Notification Trigger
CREATE OR REPLACE FUNCTION notify_on_token_assignment()
RETURNS TRIGGER AS $$
DECLARE
  v_room_name TEXT;
BEGIN
  IF NEW.assigned_staff_id IS DISTINCT FROM OLD.assigned_staff_id AND NEW.assigned_staff_id IS NOT NULL THEN
    SELECT name INTO v_room_name FROM rooms WHERE id = NEW.current_room_id;

    INSERT INTO staff_notifications (
      staff_id, token_id, token_number, type, message,
      new_room_id, new_room_name,
      previous_status, new_status, is_read, created_at
    ) VALUES (
      NEW.assigned_staff_id,
      NEW.id,
      NEW.token_number,
      'tokenAssigned',
      'Token assigned — Token #' || NEW.token_number || ' has been assigned to you',
      NEW.current_room_id,
      v_room_name,
      OLD.status,
      NEW.status,
      FALSE,
      NOW()
    );

    IF OLD.assigned_staff_id IS NOT NULL AND OLD.assigned_staff_id != NEW.assigned_staff_id THEN
      INSERT INTO staff_notifications (
        staff_id, token_id, token_number, type, message,
        new_room_id, new_room_name,
        previous_status, new_status, is_read, created_at
      ) VALUES (
        OLD.assigned_staff_id,
        NEW.id,
        NEW.token_number,
        'transferredOut',
        'Token reassigned — Token #' || NEW.token_number || ' has been reassigned',
        NEW.current_room_id,
        v_room_name,
        OLD.status,
        NEW.status,
        FALSE,
        NOW()
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 7: Verify the fixes
-- ============================================

-- Check if token_number column exists
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'staff_notifications' 
        AND column_name = 'token_number'
    ) THEN '✅ token_number column exists'
    ELSE '❌ token_number column NOT found'
  END as status;

-- List all triggers on tokens table
SELECT 
  trigger_name,
  event_manipulation,
  action_timing
FROM information_schema.triggers
WHERE event_object_table = 'tokens'
ORDER BY trigger_name;

-- ============================================
-- ✅ FIX COMPLETE!
-- ============================================
-- Next steps:
-- 1. Hard refresh your Flutter app (Ctrl+Shift+R)
-- 2. Try the operation that was failing
-- 3. Check browser console (F12) for any errors
-- ============================================
