-- ============================================
-- 🎯 ADD QUEUE PROXIMITY ALERTS
-- ============================================
-- Automatically notifies users when they reach 3rd position 
-- (meaning only 2 people are ahead of them)
-- ============================================

-- Function to handle queue position shifts and notify users
CREATE OR REPLACE FUNCTION notify_users_on_queue_shift()
RETURNS TRIGGER AS $$
DECLARE
  v_room_id UUID;
  v_target_token_id UUID;
  v_user_id UUID;
  v_token_number TEXT;
  v_room_name TEXT;
  v_count INTEGER;
BEGIN
  -- We trigger this when a token starts processing or is finished/cancelled
  -- This shift potentially moves other people up in the queue
  IF (NEW.status IN ('processing', 'completed', 'cancelled', 'rejected', 'no_show') AND 
      OLD.status = 'arrived') OR
     (NEW.status IN ('completed', 'cancelled', 'rejected', 'no_show') AND 
      OLD.status = 'processing')
  THEN
    -- Get the room ID for the shift
    v_room_id := NEW.current_room_id;
    
    IF v_room_id IS NULL THEN
      RETURN NEW;
    END IF;

    -- Get the room name for the notification
    SELECT name INTO v_room_name FROM rooms WHERE id = v_room_id;

    -- FIND THE PERSON WHO IS NOW AT POSITION 3 (2 people ahead)
    -- This uses the hybrid priority logic:
    -- 1. Scheduled first
    -- 2. Then Walk-in
    -- 3. Within each, FIFO by booked_at
    WITH active_queue AS (
      SELECT 
        id, 
        user_id, 
        token_number,
        ROW_NUMBER() OVER (
          ORDER BY 
            (scheduled_date IS NOT NULL) DESC, -- Scheduled first
            booked_at ASC                      -- FIFO
        ) as position
      FROM tokens
      WHERE current_room_id = v_room_id
        AND status = 'arrived' -- Only those who have checked in
        AND (
          (scheduled_date IS NOT NULL AND scheduled_date::date = CURRENT_DATE) OR -- Today's scheduled
          (scheduled_date IS NULL AND booked_at::date = CURRENT_DATE)            -- Today's walk-ins
        )
    )
    SELECT id, user_id, token_number, position
    INTO v_target_token_id, v_user_id, v_token_number, v_count
    FROM active_queue
    WHERE position = 3; -- The user who now has 2 people ahead

    -- If someone is now at position 3, notify them
    IF v_target_token_id IS NOT NULL AND v_user_id IS NOT NULL THEN
      -- Avoid duplicate alerts (check if we already sent a queue_alert for this token today)
      IF NOT EXISTS (
        SELECT 1 FROM user_notifications 
        WHERE token_id = v_target_token_id 
          AND type = 'queue_alert' 
          AND created_at::date = CURRENT_DATE
      ) THEN
        INSERT INTO user_notifications (
          user_id,
          token_id,
          token_number,
          type,
          title,
          message,
          new_room_id,
          new_room_name,
          new_status,
          is_read,
          created_at
        ) VALUES (
          v_user_id,
          v_target_token_id,
          v_token_number,
          'queue_alert',
          'Get Ready! 🎯',
          'Token ' || COALESCE(v_token_number, 'N/A') || ': There are only 2 people ahead of you at ' || COALESCE(v_room_name, 'the counter') || '.',
          v_room_id,
          v_room_name,
          'arrived',
          FALSE,
          NOW()
        );
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
DROP TRIGGER IF EXISTS trg_notify_users_on_queue_shift ON tokens;
CREATE TRIGGER trg_notify_users_on_queue_shift
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_users_on_queue_shift();

-- ============================================
-- ✅ DONE! PROXIMITY ALERTS ENABLED
-- ============================================
