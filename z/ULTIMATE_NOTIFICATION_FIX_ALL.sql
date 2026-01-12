-- ============================================
-- 🚀 ULTIMATE NOTIFICATION FIX (ALL-IN-ONE)
-- ============================================
-- This script restores BOTH Staff and User notifications
-- and ensures they work perfectly with real-time updates.
-- ============================================

-- STEP 1: CLEAN SLATE - DROP ALL EXISTING TRIGGERS
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (SELECT trigger_name FROM information_schema.triggers WHERE event_object_table = 'tokens') 
    LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || r.trigger_name || ' ON tokens CASCADE';
    END LOOP;
END $$;

-- STEP 2: ENSURE TABLES EXIST WITH CORRECT COLUMNS
-- Staff Notifications Table
CREATE TABLE IF NOT EXISTS staff_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  token_id UUID REFERENCES tokens(id) ON DELETE CASCADE,
  token_number TEXT,
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

-- User Notifications Table
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

-- STEP 3: ENABLE RLS AND POLICIES
ALTER TABLE staff_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;

-- Staff Policies
DROP POLICY IF EXISTS "Staff can view own notifications" ON staff_notifications;
CREATE POLICY "Staff can view own notifications" ON staff_notifications FOR SELECT USING (auth.uid() = staff_id OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));
DROP POLICY IF EXISTS "System can insert staff notifications" ON staff_notifications;
CREATE POLICY "System can insert staff notifications" ON staff_notifications FOR INSERT WITH CHECK (true);

-- User Policies
DROP POLICY IF EXISTS "Users can view own notifications" ON user_notifications;
CREATE POLICY "Users can view own notifications" ON user_notifications FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "System can insert user notifications" ON user_notifications;
CREATE POLICY "System can insert user notifications" ON user_notifications FOR INSERT WITH CHECK (true);

-- STEP 4: DEFINE STAFF NOTIFICATION FUNCTIONS
-- Token Transfer (Staff)
CREATE OR REPLACE FUNCTION notify_on_token_transfer()
RETURNS TRIGGER AS $$
DECLARE
  v_new_staff_id UUID;
  v_previous_staff_id UUID;
  v_new_room_name TEXT;
  v_previous_room_name TEXT;
  v_token_num TEXT;
BEGIN
  v_token_num := COALESCE(NEW.token_number, 'UNKNOWN');
  IF NEW.current_room_id IS DISTINCT FROM OLD.current_room_id THEN
    SELECT name INTO v_new_room_name FROM rooms WHERE id = NEW.current_room_id;
    IF OLD.current_room_id IS NOT NULL THEN
      SELECT name INTO v_previous_room_name FROM rooms WHERE id = OLD.current_room_id;
    END IF;
    SELECT id INTO v_new_staff_id FROM profiles WHERE assigned_room_id = NEW.current_room_id AND role = 'staff' LIMIT 1;
    IF OLD.current_room_id IS NOT NULL THEN
      SELECT id INTO v_previous_staff_id FROM profiles WHERE assigned_room_id = OLD.current_room_id AND role = 'staff' LIMIT 1;
    END IF;

    IF v_new_staff_id IS NOT NULL THEN
      INSERT INTO staff_notifications (staff_id, token_id, token_number, type, message, previous_room_id, previous_room_name, new_room_id, new_room_name, previous_status, new_status, is_read)
      VALUES (v_new_staff_id, NEW.id, v_token_num, 'tokenTransfer', 'New token received — Token #' || v_token_num || ' has been transferred to you', OLD.current_room_id, v_previous_room_name, NEW.current_room_id, v_new_room_name, OLD.status, NEW.status, FALSE);
    END IF;

    IF v_previous_staff_id IS NOT NULL AND v_previous_staff_id != v_new_staff_id THEN
      INSERT INTO staff_notifications (staff_id, token_id, token_number, type, message, previous_room_id, previous_room_name, new_room_id, new_room_name, previous_status, new_status, is_read)
      VALUES (v_previous_staff_id, NEW.id, v_token_num, 'transferredOut', 'Token transferred — Token #' || v_token_num || ' has been transferred out', OLD.current_room_id, v_previous_room_name, NEW.current_room_id, v_new_room_name, OLD.status, NEW.status, FALSE);
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Status Change (Staff)
CREATE OR REPLACE FUNCTION notify_on_token_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_staff_id UUID;
  v_token_num TEXT;
BEGIN
  v_token_num := COALESCE(NEW.token_number, 'UNKNOWN');
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF OLD.status IS NULL AND NEW.status = 'waiting' THEN RETURN NEW; END IF;
    SELECT id INTO v_staff_id FROM profiles WHERE id = NEW.assigned_staff_id;
    IF v_staff_id IS NOT NULL THEN
      INSERT INTO staff_notifications (staff_id, token_id, token_number, type, message, previous_status, new_status, is_read)
      VALUES (v_staff_id, NEW.id, v_token_num, 'statusChange', 'Status update — Token #' || v_token_num || ' changed from ' || COALESCE(OLD.status::TEXT, 'waiting') || ' to ' || NEW.status, OLD.status, NEW.status, FALSE);
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 5: DEFINE USER NOTIFICATION FUNCTIONS
CREATE OR REPLACE FUNCTION notify_user_on_all_changes()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_room_name TEXT;
  v_prev_room_name TEXT;
  v_token_num TEXT;
  v_title TEXT;
  v_message TEXT;
BEGIN
  v_user_id := NEW.user_id;
  IF v_user_id IS NULL THEN RETURN NEW; END IF;
  v_token_num := COALESCE(NEW.token_number, 'UNKNOWN');

  -- Case 1: Status Change
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF OLD.status IS NULL AND NEW.status = 'waiting' THEN RETURN NEW; END IF;
    
    SELECT name INTO v_room_name FROM rooms WHERE id = NEW.current_room_id;
    
    CASE NEW.status
      WHEN 'processing' THEN
        v_title := 'Your Turn! 🎯';
        v_message := 'Token ' || v_token_num || ' is now being served' || CASE WHEN v_room_name IS NOT NULL THEN ' in ' || v_room_name ELSE '' END;
      WHEN 'completed' THEN
        v_title := 'Service Completed ✅';
        v_message := 'Token ' || v_token_num || ' has been completed successfully';
      WHEN 'hold' THEN
        v_title := 'Token On Hold ⏸️';
        v_message := 'Token ' || v_token_num || ' is on hold. Please wait.';
      WHEN 'no_show' THEN
        v_title := 'Missed Turn ⚠️';
        v_message := 'Token ' || v_token_num || ' was marked as no-show';
      ELSE
        v_title := 'Status Update';
        v_message := 'Token ' || v_token_num || ' status changed to ' || NEW.status;
    END CASE;

    INSERT INTO user_notifications (user_id, token_id, token_number, type, title, message, new_status, previous_status, is_read)
    VALUES (v_user_id, NEW.id, v_token_num, 'status_change', v_title, v_message, NEW.status, OLD.status, FALSE);
  END IF;

  -- Case 2: Room Transfer
  IF NEW.current_room_id IS DISTINCT FROM OLD.current_room_id THEN
    SELECT name INTO v_room_name FROM rooms WHERE id = NEW.current_room_id;
    SELECT name INTO v_prev_room_name FROM rooms WHERE id = OLD.current_room_id;
    
    INSERT INTO user_notifications (user_id, token_id, token_number, type, title, message, previous_room_name, new_room_name, is_read)
    VALUES (v_user_id, NEW.id, v_token_num, 'room_transfer', 'Token Transferred 🔄', 'Token ' || v_token_num || ' moved to ' || COALESCE(v_room_name, 'next room'), v_prev_room_name, v_room_name, FALSE);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 6: CREATE TRIGGERS
CREATE TRIGGER trg_staff_notify_transfer AFTER UPDATE ON tokens FOR EACH ROW EXECUTE FUNCTION notify_on_token_transfer();
CREATE TRIGGER trg_staff_notify_status AFTER UPDATE ON tokens FOR EACH ROW EXECUTE FUNCTION notify_on_token_status_change();
CREATE TRIGGER trg_user_notify_all AFTER UPDATE ON tokens FOR EACH ROW EXECUTE FUNCTION notify_user_on_all_changes();

-- STEP 7: ENABLE REALTIME
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'user_notifications') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE user_notifications;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'staff_notifications') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE staff_notifications;
  END IF;
EXCEPTION WHEN OTHERS THEN 
  RAISE NOTICE 'Publication setup skipped: %', SQLERRM;
END $$;

-- STEP 8: GRANT PERMISSIONS
GRANT ALL ON staff_notifications TO authenticated, service_role;
GRANT ALL ON user_notifications TO authenticated, service_role;

SELECT '✅ ULTIMATE NOTIFICATION FIX APPLIED! Both staff and user notifications are now active.' as status;
