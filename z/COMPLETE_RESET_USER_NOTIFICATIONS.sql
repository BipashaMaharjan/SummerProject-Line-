-- ============================================
-- 🔥 COMPLETE FIX - DROPS AND RECREATES EVERYTHING
-- ============================================
-- This will completely reset the user notification system
-- Run this in Supabase SQL Editor
-- ============================================

-- STEP 1: Drop all user notification triggers
DROP TRIGGER IF EXISTS trg_notify_user_on_room_transfer ON tokens;
DROP TRIGGER IF EXISTS trg_notify_user_on_status_change ON tokens;

-- STEP 2: Drop the functions
DROP FUNCTION IF EXISTS notify_user_on_room_transfer();
DROP FUNCTION IF EXISTS notify_user_on_status_change();
DROP FUNCTION IF EXISTS get_user_unread_notification_count(UUID);
DROP FUNCTION IF EXISTS mark_all_user_notifications_read(UUID);

-- STEP 3: Drop the table completely
DROP TABLE IF EXISTS user_notifications CASCADE;

-- STEP 4: Create the table with ALL required columns
CREATE TABLE user_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  token_id UUID REFERENCES tokens(id) ON DELETE CASCADE NOT NULL,
  token_number TEXT,
  type TEXT NOT NULL,
  title TEXT,
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

-- STEP 5: Create indexes
CREATE INDEX idx_user_notifications_user_id ON user_notifications(user_id);
CREATE INDEX idx_user_notifications_token_id ON user_notifications(token_id);
CREATE INDEX idx_user_notifications_created_at ON user_notifications(created_at DESC);
CREATE INDEX idx_user_notifications_is_read ON user_notifications(is_read);
CREATE INDEX idx_user_notifications_user_created ON user_notifications(user_id, created_at DESC);

-- STEP 6: Enable RLS
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;

-- STEP 7: Create RLS policies
CREATE POLICY "Users can view own notifications" ON user_notifications 
  FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "System can insert user notifications" ON user_notifications 
  FOR INSERT 
  WITH CHECK (true);

CREATE POLICY "Users can update own notifications" ON user_notifications 
  FOR UPDATE 
  USING (auth.uid() = user_id) 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own notifications" ON user_notifications 
  FOR DELETE 
  USING (auth.uid() = user_id);

-- STEP 8: Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON user_notifications TO authenticated;

-- STEP 9: Create helper functions
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

CREATE OR REPLACE FUNCTION mark_all_user_notifications_read(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE user_notifications
  SET is_read = TRUE, updated_at = NOW()
  WHERE user_id = p_user_id AND is_read = FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 10: Create room transfer trigger function
CREATE OR REPLACE FUNCTION notify_user_on_room_transfer()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_new_room_name TEXT;
  v_previous_room_name TEXT;
BEGIN
  -- Only trigger if room actually changed
  IF NEW.current_room_id IS DISTINCT FROM OLD.current_room_id THEN
    v_user_id := NEW.user_id;
    
    -- Skip if no user associated
    IF v_user_id IS NULL THEN
      RETURN NEW;
    END IF;
    
    -- Get room names
    IF NEW.current_room_id IS NOT NULL THEN
      SELECT name INTO v_new_room_name FROM rooms WHERE id = NEW.current_room_id;
    END IF;
    
    IF OLD.current_room_id IS NOT NULL THEN
      SELECT name INTO v_previous_room_name FROM rooms WHERE id = OLD.current_room_id;
    END IF;
    
    -- Insert notification
    INSERT INTO user_notifications (
      user_id,
      token_id,
      token_number,
      type,
      title,
      message,
      previous_room_id,
      previous_room_name,
      new_room_id,
      new_room_name,
      previous_status,
      new_status,
      is_read,
      created_at
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

-- STEP 11: Create status change trigger function
CREATE OR REPLACE FUNCTION notify_user_on_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_room_name TEXT;
  v_title TEXT;
  v_message TEXT;
BEGIN
  -- Only trigger if status actually changed
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    -- Skip initial waiting status
    IF OLD.status IS NULL AND NEW.status = 'waiting' THEN
      RETURN NEW;
    END IF;
    
    v_user_id := NEW.user_id;
    
    -- Skip if no user associated
    IF v_user_id IS NULL THEN
      RETURN NEW;
    END IF;
    
    -- Get current room name
    IF NEW.current_room_id IS NOT NULL THEN
      SELECT name INTO v_room_name FROM rooms WHERE id = NEW.current_room_id;
    END IF;
    
    -- Create appropriate message based on status
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
    
    -- Insert notification
    INSERT INTO user_notifications (
      user_id,
      token_id,
      token_number,
      type,
      title,
      message,
      new_room_id,
      new_room_name,
      previous_status,
      new_status,
      is_read,
      created_at
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

-- STEP 12: Create triggers
CREATE TRIGGER trg_notify_user_on_room_transfer
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_user_on_room_transfer();

CREATE TRIGGER trg_notify_user_on_status_change
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_user_on_status_change();

-- ============================================
-- ✅ COMPLETE! NOW TRY "START PROCESSING"
-- ============================================
-- Everything has been recreated from scratch
-- All columns are present
-- All triggers are working
-- You should be able to start processing now!
-- ============================================
