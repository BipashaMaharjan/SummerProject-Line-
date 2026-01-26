-- ========================================================
-- 🔔 MASTER USER NOTIFICATION SYSTEM (UNIFIED & ROBUST)
-- ========================================================
-- This script is the definitive solution for:
-- 1. Notifications on Status Change (Your Turn, Completed, etc.)
-- 2. Notifications on Room Transfer (Moved to next room)
-- 3. Proximity Alerts (Only 2 people ahead)
-- ========================================================

BEGIN;

-- STEP 1: CLEANUP OLD TRIGGERS & FUNCTIONS
DROP TRIGGER IF EXISTS trg_notify_user_on_room_transfer ON tokens;
DROP TRIGGER IF EXISTS trg_notify_user_on_status_change ON tokens;
DROP TRIGGER IF EXISTS trg_notify_users_on_queue_shift ON tokens;

DROP FUNCTION IF EXISTS notify_user_on_room_transfer() CASCADE;
DROP FUNCTION IF EXISTS notify_user_on_status_change() CASCADE;
DROP FUNCTION IF EXISTS notify_users_on_queue_shift() CASCADE;

-- STEP 2: ENSURE TABLE HAS ALL COLUMNS
-- This ensures the Flutter app can read all details (prev/new rooms, etc.)
CREATE TABLE IF NOT EXISTS public.user_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  token_id UUID REFERENCES public.tokens(id) ON DELETE CASCADE NOT NULL,
  token_number TEXT,
  type TEXT NOT NULL,
  title TEXT,
  message TEXT NOT NULL,
  previous_room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
  previous_room_name TEXT,
  new_room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
  new_room_name TEXT,
  previous_status TEXT,
  new_status TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- STEP 3: STATUS CHANGE TRIGGER
CREATE OR REPLACE FUNCTION notify_user_on_status_change()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_room_name TEXT;
  v_title TEXT;
  v_message TEXT;
BEGIN
  -- Only trigger if status changed and not initial 'waiting'
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    
    -- Get room name for better message
    IF NEW.current_room_id IS NOT NULL THEN
      SELECT name INTO v_room_name FROM rooms WHERE id = NEW.current_room_id;
    END IF;

    CASE NEW.status
      WHEN 'processing' THEN
        v_title := 'Your Turn! 🎯';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'N/A') || ' is now being served' || COALESCE(' in ' || v_room_name, '');
      WHEN 'completed' THEN
        v_title := 'Service Completed ✅';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'N/A') || ' has been completed successfully.';
      WHEN 'rejected' THEN
        v_title := 'Token Rejected ❌';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'N/A') || ' was rejected. Reason: ' || COALESCE(NEW.notes, 'Check details');
      WHEN 'no_show' THEN
        v_title := 'Missed Turn ⚠️';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'N/A') || ' was marked as no-show.';
      WHEN 'hold' THEN
        v_title := 'On Hold ⏸️';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'N/A') || ' is temporarily on hold.';
      ELSE
        v_title := 'Status Updated';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'N/A') || ' status is now ' || NEW.status;
    END CASE;

    INSERT INTO user_notifications (
      user_id, token_id, token_number, type, title, message, new_status, previous_status, new_room_name
    ) VALUES (
      NEW.user_id, NEW.id, NEW.token_number, 'status_change', v_title, v_message, NEW.status, OLD.status, v_room_name
    );
  END IF;
  RETURN NEW;
END;
$$;

-- STEP 4: ROOM TRANSFER TRIGGER
-- This fires when current_room_id changes
CREATE OR REPLACE FUNCTION notify_user_on_room_transfer()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_room_name TEXT;
  v_old_room_name TEXT;
BEGIN
  IF NEW.current_room_id IS DISTINCT FROM OLD.current_room_id AND NEW.current_room_id IS NOT NULL THEN
    
    SELECT name INTO v_new_room_name FROM rooms WHERE id = NEW.current_room_id;
    SELECT name INTO v_old_room_name FROM rooms WHERE id = OLD.current_room_id;

    INSERT INTO user_notifications (
      user_id, token_id, token_number, type, title, message, 
      previous_room_id, previous_room_name, new_room_id, new_room_name,
      previous_status, new_status
    ) VALUES (
      NEW.user_id, NEW.id, NEW.token_number, 'room_transfer', 
      'Moved to Next Room 🔄',
      'Token ' || COALESCE(NEW.token_number, 'N/A') || ' moved from ' || COALESCE(v_old_room_name, 'waiting') || ' to ' || COALESCE(v_new_room_name, 'next room'),
      OLD.current_room_id, v_old_room_name, NEW.current_room_id, v_new_room_name,
      OLD.status, NEW.status
    );
  END IF;
  RETURN NEW;
END;
$$;

-- STEP 5: PROXIMITY ALERT (Optional but helpful)
CREATE OR REPLACE FUNCTION notify_users_on_queue_shift()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_fwd_user_id UUID;
  v_fwd_token_id UUID;
  v_fwd_token_num TEXT;
BEGIN
  -- If a token just finished or started processing, notify the person who is now #2 in line
  IF (NEW.status IN ('processing', 'completed', 'cancelled', 'rejected', 'no_show')) THEN
    
    -- Find the person who is now 2nd in line for this service
    SELECT id, user_id, token_number INTO v_fwd_token_id, v_fwd_user_id, v_fwd_token_num
    FROM tokens
    WHERE service_id = NEW.service_id 
      AND status IN ('waiting', 'arrived')
      AND (booked_at::date = CURRENT_DATE)
    ORDER BY priority DESC, booked_at ASC
    LIMIT 1 OFFSET 1; -- The person who has 1 person ahead of them

    IF v_fwd_user_id IS NOT NULL THEN
      -- Avoid spam (only one proximity alert per token per day)
      IF NOT EXISTS (SELECT 1 FROM user_notifications WHERE token_id = v_fwd_token_id AND type = 'queue_alert' AND created_at::date = CURRENT_DATE) THEN
        INSERT INTO user_notifications (user_id, token_id, token_number, type, title, message)
        VALUES (v_fwd_user_id, v_fwd_token_id, v_fwd_token_num, 'queue_alert', 'Get Ready! 🎯', 'You are next in line! Only 1 person ahead of you.');
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- STEP 6: RLS POLICIES
ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;

-- Clean up old policies
DO $$ 
DECLARE r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'user_notifications') 
    LOOP EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.user_notifications';
    END LOOP;
END $$;

-- Policies
CREATE POLICY "Users view own" ON public.user_notifications FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "System insert all" ON public.user_notifications FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Users update own" ON public.user_notifications FOR UPDATE TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users delete own" ON public.user_notifications FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- STEP 7: APPLY TRIGGERS
CREATE TRIGGER trg_notify_user_on_status_change
  AFTER UPDATE ON public.tokens
  FOR EACH ROW EXECUTE FUNCTION notify_user_on_status_change();

CREATE TRIGGER trg_notify_user_on_room_transfer
  AFTER UPDATE ON public.tokens
  FOR EACH ROW EXECUTE FUNCTION notify_user_on_room_transfer();

CREATE TRIGGER trg_notify_users_on_queue_shift
  AFTER UPDATE ON public.tokens
  FOR EACH ROW EXECUTE FUNCTION notify_users_on_queue_shift();

-- STEP 8: PERMISSIONS
GRANT ALL ON public.user_notifications TO authenticated;
GRANT ALL ON public.user_notifications TO service_role;

COMMIT;

-- REFRESH CACHE
NOTIFY pgrst, 'reload schema';

SELECT 'SUCCESS: NOTIFICATION MASTER SYSTEM ACTIVE!' as message;
