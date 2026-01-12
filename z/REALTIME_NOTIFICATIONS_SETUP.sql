-- ============================================
-- 🚀 Real-Time Notification System Setup
-- ============================================
-- This script sets up the complete real-time
-- notification system for token transfers
-- and status changes

-- STEP 1: Create staff_notifications table if not exists
CREATE TABLE IF NOT EXISTS staff_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  token_id UUID REFERENCES tokens(id) ON DELETE CASCADE,
  token_number TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'statusChange', -- tokenTransfer, statusChange, tokenAssigned, transferredOut, admin
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

-- STEP 2: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_staff_notifications_staff_id 
  ON staff_notifications(staff_id);

CREATE INDEX IF NOT EXISTS idx_staff_notifications_token_id 
  ON staff_notifications(token_id);

CREATE INDEX IF NOT EXISTS idx_staff_notifications_created_at 
  ON staff_notifications(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_staff_notifications_is_read 
  ON staff_notifications(is_read);

CREATE INDEX IF NOT EXISTS idx_staff_notifications_staff_created 
  ON staff_notifications(staff_id, created_at DESC);

-- STEP 3: Enable Row Level Security
ALTER TABLE staff_notifications ENABLE ROW LEVEL SECURITY;

-- STEP 4: Create RLS Policies
-- Allow staff to view their own notifications
DROP POLICY IF EXISTS "Staff can view own notifications" ON staff_notifications;
CREATE POLICY "Staff can view own notifications" ON staff_notifications 
  FOR SELECT 
  USING (auth.uid() = staff_id OR EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  ));

-- Allow system to insert notifications
DROP POLICY IF EXISTS "System can insert notifications" ON staff_notifications;
CREATE POLICY "System can insert notifications" ON staff_notifications 
  FOR INSERT 
  WITH CHECK (true);

-- Allow staff to update their own notifications (mark as read)
DROP POLICY IF EXISTS "Staff can update own notifications" ON staff_notifications;
CREATE POLICY "Staff can update own notifications" ON staff_notifications 
  FOR UPDATE 
  USING (auth.uid() = staff_id) 
  WITH CHECK (auth.uid() = staff_id);

-- Allow staff to delete their own notifications
DROP POLICY IF EXISTS "Staff can delete own notifications" ON staff_notifications;
CREATE POLICY "Staff can delete own notifications" ON staff_notifications 
  FOR DELETE 
  USING (auth.uid() = staff_id OR EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  ));

-- STEP 5: Create trigger function for token transfer notifications
CREATE OR REPLACE FUNCTION notify_on_token_transfer()
RETURNS TRIGGER AS $$
DECLARE
  v_new_staff_id UUID;
  v_previous_staff_id UUID;
  v_new_room_name TEXT;
  v_previous_room_name TEXT;
BEGIN
  -- Only trigger when current_room_id changes
  IF NEW.current_room_id IS DISTINCT FROM OLD.current_room_id THEN
    -- Get new room details
    SELECT name INTO v_new_room_name FROM rooms WHERE id = NEW.current_room_id;
    
    -- Get previous room details
    IF OLD.current_room_id IS NOT NULL THEN
      SELECT name INTO v_previous_room_name FROM rooms WHERE id = OLD.current_room_id;
    END IF;

    -- Get staff assigned to new room
    SELECT id INTO v_new_staff_id 
    FROM profiles 
    WHERE assigned_room_id = NEW.current_room_id AND role = 'staff'
    LIMIT 1;

    -- Get staff assigned to previous room
    IF OLD.current_room_id IS NOT NULL THEN
      SELECT id INTO v_previous_staff_id 
      FROM profiles 
      WHERE assigned_room_id = OLD.current_room_id AND role = 'staff'
      LIMIT 1;
    END IF;

    -- Create notification for new staff member
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

    -- Create notification for previous staff member
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

    -- Create notification for all admin users
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

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_notify_on_token_transfer ON tokens;

-- Create trigger for token transfer notifications
CREATE TRIGGER trg_notify_on_token_transfer
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_on_token_transfer();

-- STEP 6: Create trigger function for status change notifications
CREATE OR REPLACE FUNCTION notify_on_token_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_staff_id UUID;
  v_room_name TEXT;
BEGIN
  -- Only trigger when status changes
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    -- Skip if status changed from NULL to waiting (initial creation)
    IF OLD.status IS NULL AND NEW.status = 'waiting' THEN
      RETURN NEW;
    END IF;

    -- Get staff assigned to this token
    SELECT id INTO v_staff_id FROM profiles WHERE id = NEW.assigned_staff_id;

    -- Get current room name
    SELECT name INTO v_room_name FROM rooms WHERE id = NEW.current_room_id;

    -- Create notification for assigned staff member
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

    -- Create notification for all admin users
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

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_notify_on_token_status_change ON tokens;

-- Create trigger for status change notifications
CREATE TRIGGER trg_notify_on_token_status_change
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_on_token_status_change();

-- STEP 7: Create trigger function for token assignment notifications
CREATE OR REPLACE FUNCTION notify_on_token_assignment()
RETURNS TRIGGER AS $$
DECLARE
  v_room_name TEXT;
BEGIN
  -- Only trigger when assigned_staff_id changes and is not NULL
  IF NEW.assigned_staff_id IS DISTINCT FROM OLD.assigned_staff_id AND NEW.assigned_staff_id IS NOT NULL THEN
    -- Get current room name
    SELECT name INTO v_room_name FROM rooms WHERE id = NEW.current_room_id;

    -- Create notification for newly assigned staff member
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

    -- Create notification for previously assigned staff member
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

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_notify_on_token_assignment ON tokens;

-- Create trigger for assignment notifications
CREATE TRIGGER trg_notify_on_token_assignment
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_on_token_assignment();

-- STEP 8: Create function to clean up old notifications (optional)
-- This helps with database maintenance
CREATE OR REPLACE FUNCTION cleanup_old_notifications()
RETURNS void AS $$
BEGIN
  DELETE FROM staff_notifications
  WHERE created_at < NOW() - INTERVAL '30 days';
  
  RAISE NOTICE 'Cleaned up notifications older than 30 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 9: Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON staff_notifications TO authenticated;
GRANT SELECT ON profiles TO authenticated;
GRANT SELECT ON rooms TO authenticated;
GRANT SELECT ON tokens TO authenticated;

-- STEP 10: Test the system
-- You can use this query to verify the setup
SELECT 
  'staff_notifications' as table_name,
  COUNT(*) as total_rows,
  COUNT(CASE WHEN is_read = FALSE THEN 1 END) as unread,
  COUNT(DISTINCT staff_id) as unique_staff,
  MAX(created_at) as latest_notification
FROM staff_notifications;

-- ============================================
-- Setup Complete!
-- ============================================
-- The notification system is now ready to use.
-- - Tokens transfers will automatically create notifications
-- - Status changes will automatically create notifications
-- - Staff and admin users will receive real-time updates
-- - All notifications are stored for history
