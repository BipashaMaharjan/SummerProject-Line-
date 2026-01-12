-- ============================================
-- 🚨 EMERGENCY FIX - RUN THIS NOW
-- ============================================
-- This fixes the "token_number NOT NULL" error
-- Run this in Supabase SQL Editor RIGHT NOW
-- ============================================

-- STEP 1: Drop the problematic triggers temporarily
DROP TRIGGER IF EXISTS trg_notify_user_on_room_transfer ON tokens;
DROP TRIGGER IF EXISTS trg_notify_user_on_status_change ON tokens;

-- STEP 2: Make token_number nullable in user_notifications
ALTER TABLE user_notifications 
ALTER COLUMN token_number DROP NOT NULL;

ALTER TABLE user_notifications 
ALTER COLUMN title DROP NOT NULL;

-- STEP 3: Update any existing NULL values
UPDATE user_notifications 
SET token_number = 'UNKNOWN'
WHERE token_number IS NULL;

UPDATE user_notifications 
SET title = 'Notification'
WHERE title IS NULL;

-- STEP 4: Recreate triggers with COALESCE to handle NULLs
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

CREATE TRIGGER trg_notify_user_on_room_transfer
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_user_on_room_transfer();

-- STEP 5: Recreate status change trigger
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

CREATE TRIGGER trg_notify_user_on_status_change
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_user_on_status_change();

-- ============================================
-- ✅ DONE! TRY "START PROCESSING" NOW
-- ============================================
-- The error should be fixed
-- You can now start processing tokens
-- ============================================
