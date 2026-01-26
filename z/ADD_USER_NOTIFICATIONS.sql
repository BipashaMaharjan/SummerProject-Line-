-- ============================================
-- 🎯 ADD USER NOTIFICATIONS (SAFE VERSION)
-- ============================================
-- This adds user notifications WITHOUT breaking staff notifications
-- Run this in Supabase SQL Editor
-- ============================================

-- STEP 1: Create user_notifications table
CREATE TABLE IF NOT EXISTS user_notifications (
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

-- STEP 2: Create indexes
CREATE INDEX IF NOT EXISTS idx_user_notifications_user_id ON user_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_user_notifications_token_id ON user_notifications(token_id);
CREATE INDEX IF NOT EXISTS idx_user_notifications_created_at ON user_notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_notifications_is_read ON user_notifications(is_read);

-- STEP 3: Enable RLS
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;

-- STEP 4: Create RLS policies
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
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own notifications" ON user_notifications;
CREATE POLICY "Users can delete own notifications" ON user_notifications 
  FOR DELETE 
  USING (auth.uid() = user_id);

-- STEP 5: Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON user_notifications TO authenticated;

-- STEP 6: Create user notification trigger for status changes
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
        -- Check if it was an auto-rejection for no-show
        IF NEW.notes LIKE '%Auto-rejected%' THEN
          v_message := 'Your token (' || COALESCE(NEW.token_number, 'N/A') || ') was rejected because you did not arrive on your scheduled date. Please book a new token if you still need service.';
        ELSE
          v_message := 'Token ' || COALESCE(NEW.token_number, 'UNKNOWN') || ' was rejected. Please contact staff for details.';
        END IF;
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

-- STEP 7: Create trigger (only if it doesn't exist)
DROP TRIGGER IF EXISTS trg_notify_user_on_status_change ON tokens;
CREATE TRIGGER trg_notify_user_on_status_change
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_user_on_status_change();

-- ============================================
-- STEP 8: Enable Realtime for user_notifications
-- ============================================
-- NOTE: If this fails, it might be because the publication already includes the table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'user_notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE user_notifications;
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Could not add table to publication: %', SQLERRM;
END $$;

-- ============================================
-- ✅ DONE! USER NOTIFICATIONS ENABLED
-- ============================================
-- Test by having staff start processing a token
-- The user should receive a notification
-- ============================================
