-- ============================================
-- 🚨 EMERGENCY FIX: STAFF NOTIFICATIONS NOT NULL CONSTRAINT
-- ============================================
-- This script fixes the "null value in column token_number" error
-- by making the column nullable and adding COALESCE to triggers.
-- ============================================

-- STEP 1: Make token_number column nullable in staff_notifications
ALTER TABLE staff_notifications ALTER COLUMN token_number DROP NOT NULL;

-- STEP 2: Update notify_on_token_transfer function
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
        v_token_num,
        'tokenTransfer',
        'New token received — Token #' || v_token_num || ' has been transferred to you' ||
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
        v_token_num,
        'transferredOut',
        'Token transferred — Token #' || v_token_num || ' has been transferred to ' || 
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
      v_token_num,
      'admin',
      'Token transferred — Token #' || v_token_num || ' moved from ' ||
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

-- STEP 3: Update notify_on_token_status_change function
CREATE OR REPLACE FUNCTION notify_on_token_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_staff_id UUID;
  v_room_name TEXT;
  v_token_num TEXT;
BEGIN
  v_token_num := COALESCE(NEW.token_number, 'UNKNOWN');

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
        v_token_num,
        'statusChange',
        'Status update — Token #' || v_token_num || ' status changed from ' ||
        COALESCE(OLD.status::TEXT, 'waiting') || ' to ' || NEW.status,
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
      v_token_num,
      'admin',
      'Status update — Token #' || v_token_num || ' status changed from ' ||
      COALESCE(OLD.status::TEXT, 'waiting') || ' to ' || NEW.status,
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

-- STEP 4: Update notify_on_token_assignment function
CREATE OR REPLACE FUNCTION notify_on_token_assignment()
RETURNS TRIGGER AS $$
DECLARE
  v_room_name TEXT;
  v_token_num TEXT;
BEGIN
  v_token_num := COALESCE(NEW.token_number, 'UNKNOWN');

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
      v_token_num,
      'tokenAssigned',
      'Token assigned — Token #' || v_token_num || ' has been assigned to you',
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
        v_token_num,
        'transferredOut',
        'Token reassigned — Token #' || v_token_num || ' has been reassigned',
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

-- STEP 5: Re-verify all triggers exist
DROP TRIGGER IF EXISTS trg_notify_on_token_transfer ON tokens;
CREATE TRIGGER trg_notify_on_token_transfer
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_on_token_transfer();

DROP TRIGGER IF EXISTS trg_notify_on_token_status_change ON tokens;
CREATE TRIGGER trg_notify_on_token_status_change
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_on_token_status_change();

DROP TRIGGER IF EXISTS trg_notify_on_token_assignment ON tokens;
CREATE TRIGGER trg_notify_on_token_assignment
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_on_token_assignment();

-- ✅ FIX COMPLETE!
