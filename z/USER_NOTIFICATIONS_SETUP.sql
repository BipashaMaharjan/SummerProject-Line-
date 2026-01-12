-- ============================================
-- 🔔 USER NOTIFICATIONS SYSTEM SETUP
-- ============================================
-- This script sets up the complete user notification
-- system for token transfers and status changes
-- ============================================

-- STEP 1: Create user_notifications table
CREATE TABLE IF NOT EXISTS user_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  token_id UUID REFERENCES tokens(id) ON DELETE CASCADE NOT NULL,
  token_number TEXT NOT NULL,
  type TEXT NOT NULL, -- 'room_transfer', 'status_change', 'queue_alert'
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  
  -- Room transfer details
  previous_room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  previous_room_name TEXT,
  new_room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  new_room_name TEXT,
  
  -- Status change details
  previous_status TEXT,
  new_status TEXT,
  
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- STEP 2: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_notifications_user_id 
  ON user_notifications(user_id);

CREATE INDEX IF NOT EXISTS idx_user_notifications_token_id 
  ON user_notifications(token_id);

CREATE INDEX IF NOT EXISTS idx_user_notifications_created_at 
  ON user_notifications(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_notifications_is_read 
  ON user_notifications(is_read);

CREATE INDEX IF NOT EXISTS idx_user_notifications_user_created 
  ON user_notifications(user_id, created_at DESC);

-- STEP 3: Enable Row Level Security
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;

-- STEP 4: Create RLS Policies
-- Allow users to view their own notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON user_notifications;
CREATE POLICY "Users can view own notifications" ON user_notifications 
  FOR SELECT 
  USING (auth.uid() = user_id);

-- Allow system to insert notifications
DROP POLICY IF EXISTS "System can insert notifications" ON user_notifications;
CREATE POLICY "System can insert notifications" ON user_notifications 
  FOR INSERT 
  WITH CHECK (true);

-- Allow users to update their own notifications (mark as read)
DROP POLICY IF EXISTS "Users can update own notifications" ON user_notifications;
CREATE POLICY "Users can update own notifications" ON user_notifications 
  FOR UPDATE 
  USING (auth.uid() = user_id) 
  WITH CHECK (auth.uid() = user_id);

-- Allow users to delete their own notifications
DROP POLICY IF EXISTS "Users can delete own notifications" ON user_notifications;
CREATE POLICY "Users can delete own notifications" ON user_notifications 
  FOR DELETE 
  USING (auth.uid() = user_id);

-- STEP 5: Create trigger function for room transfer notifications
CREATE OR REPLACE FUNCTION notify_user_on_room_transfer()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_new_room_name TEXT;
  v_previous_room_name TEXT;
BEGIN
  -- Only trigger when current_room_id changes
  IF NEW.current_room_id IS DISTINCT FROM OLD.current_room_id THEN
    -- Get the user who owns this token
    v_user_id := NEW.user_id;
    
    -- Skip if no user (shouldn't happen, but safety check)
    IF v_user_id IS NULL THEN
      RETURN NEW;
    END IF;
    
    -- Get new room name
    IF NEW.current_room_id IS NOT NULL THEN
      SELECT name INTO v_new_room_name FROM rooms WHERE id = NEW.current_room_id;
    END IF;
    
    -- Get previous room name
    IF OLD.current_room_id IS NOT NULL THEN
      SELECT name INTO v_previous_room_name FROM rooms WHERE id = OLD.current_room_id;
    END IF;
    
    -- Create notification for the user
    INSERT INTO user_notifications (
      user_id, token_id, token_number, type, title, message,
      previous_room_id, previous_room_name,
      new_room_id, new_room_name,
      previous_status, new_status,
      is_read, created_at
    ) VALUES (
      v_user_id,
      NEW.id,
      NEW.token_number,
      'room_transfer',
      'Token Transferred 🔄',
      'Token ' || NEW.token_number || ' transferred from ' ||
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
    
    RAISE NOTICE 'User notification created for token % room transfer', NEW.token_number;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_notify_user_on_room_transfer ON tokens;

-- Create trigger for room transfer notifications
CREATE TRIGGER trg_notify_user_on_room_transfer
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_user_on_room_transfer();

-- STEP 6: Create trigger function for status change notifications
CREATE OR REPLACE FUNCTION notify_user_on_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_room_name TEXT;
  v_title TEXT;
  v_message TEXT;
BEGIN
  -- Only trigger when status changes
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    -- Skip if status changed from NULL to waiting (initial creation)
    IF OLD.status IS NULL AND NEW.status = 'waiting' THEN
      RETURN NEW;
    END IF;
    
    -- Get the user who owns this token
    v_user_id := NEW.user_id;
    
    -- Skip if no user
    IF v_user_id IS NULL THEN
      RETURN NEW;
    END IF;
    
    -- Get current room name
    IF NEW.current_room_id IS NOT NULL THEN
      SELECT name INTO v_room_name FROM rooms WHERE id = NEW.current_room_id;
    END IF;
    
    -- Create appropriate title and message based on status
    CASE NEW.status
      WHEN 'processing' THEN
        v_title := 'Your Turn! 🎯';
        v_message := 'Token ' || NEW.token_number || ' is now being served' ||
                     CASE WHEN v_room_name IS NOT NULL 
                          THEN ' in ' || v_room_name 
                          ELSE '' 
                     END;
      WHEN 'completed' THEN
        v_title := 'Service Completed ✅';
        v_message := 'Token ' || NEW.token_number || ' has been completed successfully';
      WHEN 'hold' THEN
        v_title := 'Token On Hold ⏸️';
        v_message := 'Token ' || NEW.token_number || ' is on hold. Please wait for further instructions.';
      WHEN 'rejected' THEN
        v_title := 'Token Rejected ❌';
        v_message := 'Token ' || NEW.token_number || ' was rejected. Please contact staff.';
      WHEN 'no_show' THEN
        v_title := 'Missed Turn ⚠️';
        v_message := 'Token ' || NEW.token_number || ' was marked as no-show';
      ELSE
        v_title := 'Status Update';
        v_message := 'Token ' || NEW.token_number || ' status changed to ' || NEW.status;
    END CASE;
    
    -- Create notification for the user
    INSERT INTO user_notifications (
      user_id, token_id, token_number, type, title, message,
      new_room_id, new_room_name,
      previous_status, new_status,
      is_read, created_at
    ) VALUES (
      v_user_id,
      NEW.id,
      NEW.token_number,
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
    
    RAISE NOTICE 'User notification created for token % status change', NEW.token_number;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_notify_user_on_status_change ON tokens;

-- Create trigger for status change notifications
CREATE TRIGGER trg_notify_user_on_status_change
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_user_on_status_change();

-- STEP 7: Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON user_notifications TO authenticated;

-- STEP 8: Create function to get unread count for a user
CREATE OR REPLACE FUNCTION get_user_unread_notification_count(p_user_id UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM user_notifications
    WHERE user_id = p_user_id AND is_read = FALSE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 9: Create function to mark all notifications as read
CREATE OR REPLACE FUNCTION mark_all_user_notifications_read(p_user_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE user_notifications
  SET is_read = TRUE, updated_at = NOW()
  WHERE user_id = p_user_id AND is_read = FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 10: Test the system
-- You can use this query to verify the setup
SELECT 
  'user_notifications' as table_name,
  COUNT(*) as total_rows,
  COUNT(CASE WHEN is_read = FALSE THEN 1 END) as unread,
  COUNT(DISTINCT user_id) as unique_users,
  MAX(created_at) as latest_notification
FROM user_notifications;

-- ============================================
-- ✅ SETUP COMPLETE!
-- ============================================
-- The user notification system is now ready.
-- - Room transfers will automatically create notifications
-- - Status changes will automatically create notifications
-- - Users will receive real-time updates
-- - All notifications are stored for history
-- ============================================
