-- ============================================
-- 🔧 COMPLETE NOTIFICATION SYSTEM FIX
-- ============================================
-- This script fixes ALL notification issues for
-- BOTH staff and user notifications
-- Run this ONCE in Supabase SQL Editor
-- ============================================

-- ============================================
-- PART 1: FIX MISSING FUNCTIONS
-- ============================================

-- Create current_user_email function (needed by some triggers)
CREATE OR REPLACE FUNCTION current_user_email()
RETURNS TEXT AS $$
BEGIN
  RETURN (SELECT email FROM auth.users WHERE id = auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- PART 2: FIX STAFF NOTIFICATIONS TABLE
-- ============================================

-- Ensure staff_notifications table exists with all columns
CREATE TABLE IF NOT EXISTS staff_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  token_id UUID REFERENCES tokens(id) ON DELETE CASCADE,
  token_number TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'statusChange',
  message TEXT NOT NULL,
  previous_room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  previous_room_name TEXT,
  new_room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  new_room_name TEXT,
  previous_status TEXT,
  new_status TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add token_number column if it doesn't exist
ALTER TABLE staff_notifications 
ADD COLUMN IF NOT EXISTS token_number TEXT;

-- Update existing rows that might have NULL token_number
UPDATE staff_notifications 
SET token_number = COALESCE(token_number, 'UNKNOWN')
WHERE token_number IS NULL;

-- Make token_number NOT NULL after fixing existing data
ALTER TABLE staff_notifications 
ALTER COLUMN token_number SET NOT NULL;

-- ============================================
-- PART 3: FIX USER NOTIFICATIONS TABLE
-- ============================================

-- Create user_notifications table with all required columns
CREATE TABLE IF NOT EXISTS user_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  token_id UUID REFERENCES tokens(id) ON DELETE CASCADE NOT NULL,
  token_number TEXT, -- Allow NULL initially
  type TEXT NOT NULL,
  title TEXT, -- Allow NULL initially
  message TEXT NOT NULL,
  previous_room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  previous_room_name TEXT,
  new_room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  new_room_name TEXT,
  previous_status TEXT,
  new_status TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add missing columns if table already exists
ALTER TABLE user_notifications 
ADD COLUMN IF NOT EXISTS token_number TEXT;

ALTER TABLE user_notifications 
ADD COLUMN IF NOT EXISTS title TEXT;

-- Update existing rows with default values
UPDATE user_notifications 
SET token_number = COALESCE(token_number, 'UNKNOWN')
WHERE token_number IS NULL;

UPDATE user_notifications 
SET title = COALESCE(title, 'Notification')
WHERE title IS NULL;

-- Now make columns NOT NULL (only if they don't have the constraint already)
DO $$
BEGIN
  -- Set token_number to NOT NULL if not already
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'user_notifications' 
    AND column_name = 'token_number' 
    AND is_nullable = 'YES'
  ) THEN
    ALTER TABLE user_notifications ALTER COLUMN token_number SET NOT NULL;
  END IF;
  
  -- Set title to NOT NULL if not already
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'user_notifications' 
    AND column_name = 'title' 
    AND is_nullable = 'YES'
  ) THEN
    ALTER TABLE user_notifications ALTER COLUMN title SET NOT NULL;
  END IF;
END $$;

-- ============================================
-- PART 4: CREATE INDEXES
-- ============================================

-- Staff notifications indexes
CREATE INDEX IF NOT EXISTS idx_staff_notifications_staff_id ON staff_notifications(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_notifications_token_id ON staff_notifications(token_id);
CREATE INDEX IF NOT EXISTS idx_staff_notifications_created_at ON staff_notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_staff_notifications_is_read ON staff_notifications(is_read);

-- User notifications indexes
CREATE INDEX IF NOT EXISTS idx_user_notifications_user_id ON user_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_user_notifications_token_id ON user_notifications(token_id);
CREATE INDEX IF NOT EXISTS idx_user_notifications_created_at ON user_notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_notifications_is_read ON user_notifications(is_read);

-- ============================================
-- PART 5: ENABLE RLS AND CREATE POLICIES
-- ============================================

-- Staff notifications RLS
ALTER TABLE staff_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff can view own notifications" ON staff_notifications;
CREATE POLICY "Staff can view own notifications" ON staff_notifications 
  FOR SELECT 
  USING (auth.uid() = staff_id OR EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  ));

DROP POLICY IF EXISTS "System can insert notifications" ON staff_notifications;
CREATE POLICY "System can insert notifications" ON staff_notifications 
  FOR INSERT 
  WITH CHECK (true);

DROP POLICY IF EXISTS "Staff can update own notifications" ON staff_notifications;
CREATE POLICY "Staff can update own notifications" ON staff_notifications 
  FOR UPDATE 
  USING (auth.uid() = staff_id) 
  WITH CHECK (auth.uid() = staff_id);

DROP POLICY IF EXISTS "Staff can delete own notifications" ON staff_notifications;
CREATE POLICY "Staff can delete own notifications" ON staff_notifications 
  FOR DELETE 
  USING (auth.uid() = staff_id OR EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  ));

-- User notifications RLS
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own notifications" ON user_notifications;
CREATE POLICY "Users can view own notifications" ON user_notifications 
  FOR SELECT 
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "System can insert user notifications" ON user_notifications;
CREATE POLICY "System can insert user notifications" ON user_notifications 
  FOR INSERT 
  WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update own notifications" ON user_notifications;
CREATE POLICY "Users can update own notifications" ON user_notifications 
  FOR UPDATE 
  USING (auth.uid() = user_id) 
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own notifications" ON user_notifications;
CREATE POLICY "Users can delete own notifications" ON user_notifications 
  FOR DELETE 
  USING (auth.uid() = user_id);

-- ============================================
-- PART 6: CREATE/UPDATE TRIGGERS
-- ============================================

-- User notification triggers (from USER_NOTIFICATIONS_SETUP.sql)
CREATE OR REPLACE FUNCTION notify_user_on_room_transfer()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_new_room_name TEXT;
  v_previous_room_name TEXT;
BEGIN
  IF NEW.current_room_id IS DISTINCT FROM OLD.current_room_id THEN
    v_user_id := NEW.user_id;
    
    IF v_user_id IS NULL THEN
      RETURN NEW;
    END IF;
    
    IF NEW.current_room_id IS NOT NULL THEN
      SELECT name INTO v_new_room_name FROM rooms WHERE id = NEW.current_room_id;
    END IF;
    
    IF OLD.current_room_id IS NOT NULL THEN
      SELECT name INTO v_previous_room_name FROM rooms WHERE id = OLD.current_room_id;
    END IF;
    
    INSERT INTO user_notifications (
      user_id, token_id, token_number, type, title, message,
      previous_room_id, previous_room_name,
      new_room_id, new_room_name,
      previous_status, new_status,
      is_read, created_at
    ) VALUES (
      v_user_id,
      NEW.id,
      COALESCE(NEW.token_number, 'UNKNOWN'),
      'room_transfer',
      'Token Transferred 🔄',
      'Token ' || COALESCE(NEW.token_number, 'UNKNOWN') || ' transferred from ' ||
      COALESCE(v_previous_room_name, 'waiting area') || ' to ' ||
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
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_user_on_room_transfer ON tokens;
CREATE TRIGGER trg_notify_user_on_room_transfer
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_user_on_room_transfer();

-- User status change trigger
CREATE OR REPLACE FUNCTION notify_user_on_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_room_name TEXT;
  v_title TEXT;
  v_message TEXT;
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF OLD.status IS NULL AND NEW.status = 'waiting' THEN
      RETURN NEW;
    END IF;
    
    v_user_id := NEW.user_id;
    
    IF v_user_id IS NULL THEN
      RETURN NEW;
    END IF;
    
    IF NEW.current_room_id IS NOT NULL THEN
      SELECT name INTO v_room_name FROM rooms WHERE id = NEW.current_room_id;
    END IF;
    
    CASE NEW.status
      WHEN 'processing' THEN
        v_title := 'Your Turn! 🎯';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'UNKNOWN') || ' is now being served' ||
                     CASE WHEN v_room_name IS NOT NULL 
                          THEN ' in ' || v_room_name 
                          ELSE '' 
                     END;
      WHEN 'completed' THEN
        v_title := 'Service Completed ✅';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'UNKNOWN') || ' has been completed successfully';
      WHEN 'hold' THEN
        v_title := 'Token On Hold ⏸️';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'UNKNOWN') || ' is on hold. Please wait for further instructions.';
      WHEN 'rejected' THEN
        v_title := 'Token Rejected ❌';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'UNKNOWN') || ' was rejected. Please contact staff.';
      WHEN 'no_show' THEN
        v_title := 'Missed Turn ⚠️';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'UNKNOWN') || ' was marked as no-show';
      ELSE
        v_title := 'Status Update';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'UNKNOWN') || ' status changed to ' || NEW.status;
    END CASE;
    
    INSERT INTO user_notifications (
      user_id, token_id, token_number, type, title, message,
      new_room_id, new_room_name,
      previous_status, new_status,
      is_read, created_at
    ) VALUES (
      v_user_id,
      NEW.id,
      COALESCE(NEW.token_number, 'UNKNOWN'),
      'status_change',
      v_title,
      v_message,
      NEW.current_room_id,
      v_room_name,
      OLD.status,
      NEW.status,
      FALSE,
      NOW()
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_user_on_status_change ON tokens;
CREATE TRIGGER trg_notify_user_on_status_change
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_user_on_status_change();

-- ============================================
-- PART 7: GRANT PERMISSIONS
-- ============================================

GRANT SELECT, INSERT, UPDATE, DELETE ON staff_notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON user_notifications TO authenticated;
GRANT SELECT ON profiles TO authenticated;
GRANT SELECT ON rooms TO authenticated;
GRANT SELECT ON tokens TO authenticated;

-- ============================================
-- PART 8: VERIFICATION
-- ============================================

-- Check current_user_email function
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

-- Check staff_notifications columns
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

-- Check user_notifications columns
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'user_notifications' 
      AND column_name = 'token_number'
  ) THEN
    RAISE NOTICE '✅ token_number column exists in user_notifications';
  ELSE
    RAISE WARNING '❌ token_number column NOT found in user_notifications';
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'user_notifications' 
      AND column_name = 'title'
  ) THEN
    RAISE NOTICE '✅ title column exists in user_notifications';
  ELSE
    RAISE WARNING '❌ title column NOT found in user_notifications';
  END IF;
END $$;

-- List all triggers on tokens table
SELECT 
  '✅ Trigger: ' || trigger_name as status
FROM information_schema.triggers
WHERE event_object_table = 'tokens'
ORDER BY trigger_name;

-- ============================================
-- ✅ COMPLETE! BOTH SYSTEMS FIXED!
-- ============================================
-- Staff notifications: READY ✅
-- User notifications: READY ✅
-- All triggers: ACTIVE ✅
-- All RLS policies: ENABLED ✅
-- ============================================
