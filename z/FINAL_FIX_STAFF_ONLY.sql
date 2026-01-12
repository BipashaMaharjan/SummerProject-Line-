-- ============================================
-- 🔥 ABSOLUTE FINAL FIX - VERIFY AND REMOVE ALL TRIGGERS
-- ============================================
-- This will show you what triggers exist and remove them ALL
-- Copy and run this ENTIRE script in Supabase SQL Editor
-- ============================================

-- STEP 1: Show all triggers on tokens table
SELECT 
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'tokens'
ORDER BY trigger_name;

-- STEP 2: Drop EVERY SINGLE trigger on tokens table
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT trigger_name
        FROM information_schema.triggers
        WHERE event_object_table = 'tokens'
    ) LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || r.trigger_name || ' ON tokens CASCADE';
        RAISE NOTICE 'Dropped trigger: %', r.trigger_name;
    END LOOP;
END $$;

-- STEP 3: Recreate ONLY the staff notification triggers (not user ones)
-- First, ensure current_user_email function exists
CREATE OR REPLACE FUNCTION current_user_email()
RETURNS TEXT AS $$
BEGIN
  RETURN (SELECT email FROM auth.users WHERE id = auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 4: Recreate staff notification trigger for token transfers
CREATE OR REPLACE FUNCTION notify_on_token_transfer()
RETURNS TRIGGER AS $$
DECLARE
  v_staff_id UUID;
  v_staff_email TEXT;
  v_new_room_name TEXT;
  v_previous_room_name TEXT;
BEGIN
  IF NEW.current_room_id IS DISTINCT FROM OLD.current_room_id THEN
    v_staff_id := NEW.assigned_staff_id;
    
    IF v_staff_id IS NULL THEN
      v_staff_email := current_user_email();
      IF v_staff_email IS NOT NULL THEN
        SELECT id INTO v_staff_id FROM profiles WHERE email = v_staff_email;
      END IF;
    END IF;
    
    IF v_staff_id IS NOT NULL THEN
      IF NEW.current_room_id IS NOT NULL THEN
        SELECT name INTO v_new_room_name FROM rooms WHERE id = NEW.current_room_id;
      END IF;
      
      IF OLD.current_room_id IS NOT NULL THEN
        SELECT name INTO v_previous_room_name FROM rooms WHERE id = OLD.current_room_id;
      END IF;
      
      INSERT INTO staff_notifications (
        staff_id, token_id, token_number, type, message,
        previous_room_id, previous_room_name,
        new_room_id, new_room_name,
        previous_status, new_status,
        is_read, created_at
      ) VALUES (
        v_staff_id,
        NEW.id,
        COALESCE(NEW.token_number, 'UNKNOWN'),
        'tokenTransfer',
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
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_notify_on_token_transfer
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_on_token_transfer();

-- STEP 5: Recreate staff notification trigger for status changes
CREATE OR REPLACE FUNCTION notify_on_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_staff_id UUID;
  v_staff_email TEXT;
  v_room_name TEXT;
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    v_staff_id := NEW.assigned_staff_id;
    
    IF v_staff_id IS NULL THEN
      v_staff_email := current_user_email();
      IF v_staff_email IS NOT NULL THEN
        SELECT id INTO v_staff_id FROM profiles WHERE email = v_staff_email;
      END IF;
    END IF;
    
    IF v_staff_id IS NOT NULL THEN
      IF NEW.current_room_id IS NOT NULL THEN
        SELECT name INTO v_room_name FROM rooms WHERE id = NEW.current_room_id;
      END IF;
      
      INSERT INTO staff_notifications (
        staff_id, token_id, token_number, type, message,
        new_room_id, new_room_name,
        previous_status, new_status,
        is_read, created_at
      ) VALUES (
        v_staff_id,
        NEW.id,
        COALESCE(NEW.token_number, 'UNKNOWN'),
        'statusChange',
        'Token ' || COALESCE(NEW.token_number, 'UNKNOWN') || ' status changed from ' ||
        COALESCE(OLD.status, 'waiting') || ' to ' || NEW.status ||
        CASE WHEN v_room_name IS NOT NULL THEN ' in ' || v_room_name ELSE '' END,
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

CREATE TRIGGER trg_notify_on_status_change
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_on_status_change();

-- ============================================
-- ✅ DONE! VERIFY TRIGGERS
-- ============================================
-- Show what triggers are now active
SELECT 
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'tokens'
ORDER BY trigger_name;

-- ============================================
-- NOW TRY "START PROCESSING"
-- ============================================
