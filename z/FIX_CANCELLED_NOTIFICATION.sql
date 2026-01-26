-- ============================================
-- 🔧 FIX: Add Cancelled Status Notification
-- ============================================
-- This adds proper notification for when users
-- cancel their tokens
-- ============================================

CREATE OR REPLACE FUNCTION notify_user_on_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_room_name TEXT;
  v_title TEXT;
  v_message TEXT;
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    -- Skip initial token creation
    IF OLD.status IS NULL AND NEW.status = 'waiting' THEN
      RETURN NEW;
    END IF;
    
    v_user_id := NEW.user_id;
    
    -- Only send notifications if user exists
    IF v_user_id IS NULL THEN
      RETURN NEW;
    END IF;
    
    -- Get room name if available
    IF NEW.current_room_id IS NOT NULL THEN
      SELECT name INTO v_room_name FROM rooms WHERE id = NEW.current_room_id;
    END IF;
    
    -- Set notification title and message based on status
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
      
      WHEN 'cancelled' THEN
        v_title := 'Token Cancelled 🚫';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'UNKNOWN') || ' has been cancelled successfully.';
      
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

-- Recreate the trigger
DROP TRIGGER IF EXISTS trg_notify_user_on_status_change ON tokens;
CREATE TRIGGER trg_notify_user_on_status_change
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_user_on_status_change();

-- ============================================
-- ✅ DONE! Cancelled tokens now show correct notification
-- ============================================
-- Users will see: "Token Cancelled 🚫"
-- Instead of: "Token Rejected ❌"
-- ============================================
