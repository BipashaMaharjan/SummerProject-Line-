-- 1. Drop old triggers (Clean Slate)
DROP TRIGGER IF EXISTS trg_notify_users_on_queue_shift ON tokens;
DROP TRIGGER IF EXISTS trg_notify_proximity_alert ON tokens;
DROP TRIGGER IF EXISTS trg_user_notify_all ON tokens;
DROP TRIGGER IF EXISTS trg_notify_user_orchestrator ON tokens;

-- 2. Consolidated Notification Function
CREATE OR REPLACE FUNCTION notify_user_orchestrator()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_title TEXT;
  v_message TEXT;
  v_room_name TEXT;
  v_target_user_id UUID;
  v_target_token_id UUID;
  v_target_token_num TEXT;
BEGIN
  -- CASE A: NOTIFY THE PERSON BEING SERVED (EXCLUSIVE)
  IF NEW.status = 'processing' AND (OLD.status IS DISTINCT FROM 'processing') THEN
    v_user_id := NEW.user_id;
    
    IF v_user_id IS NOT NULL THEN
      -- Get room name
      SELECT name INTO v_room_name FROM rooms WHERE id = NEW.current_room_id;

      INSERT INTO user_notifications (user_id, token_id, token_number, type, title, message, new_status, is_read)
      VALUES (v_user_id, NEW.id, NEW.token_number, 'status_change', 'Your Turn! 🎯', 
              'Token ' || COALESCE(NEW.token_number, 'N/A') || ' is now being served' || 
              CASE WHEN v_room_name IS NOT NULL THEN ' in ' || v_room_name ELSE '' END || '.', 
              'processing', FALSE);
    END IF;

    -- CASE B: NOTIFY THE PERSON AT POSITION 2 IN WAITING LIST (3rd overall including processing)
    -- We use service_id because it's the global queue identifier
    WITH active_queue AS (
      SELECT id, user_id, token_number,
             ROW_NUMBER() OVER (ORDER BY (scheduled_date IS NOT NULL) DESC, booked_at ASC) as pos
      FROM tokens
      WHERE service_id = NEW.service_id
        AND status = 'waiting' -- Only waiting tokens
        AND id != NEW.id       -- Don't count the one currently started
        AND (
          (scheduled_date IS NOT NULL AND scheduled_date::date = CURRENT_DATE) OR 
          (scheduled_date IS NULL AND booked_at::date = CURRENT_DATE)
        )
    )
    SELECT id, user_id, token_number INTO v_target_token_id, v_target_user_id, v_target_token_num
    FROM active_queue WHERE pos = 2; -- Token 003 is at pos 2 of waiting queue

    IF v_target_user_id IS NOT NULL THEN
      -- Deduplicate: Don't send if they got one recently
      IF NOT EXISTS (SELECT 1 FROM user_notifications WHERE user_id = v_target_user_id AND type = 'queue_alert' AND created_at > NOW() - INTERVAL '10 minutes') THEN
        INSERT INTO user_notifications (user_id, token_id, token_number, type, title, message, is_read)
        VALUES (v_target_user_id, v_target_token_id, v_target_token_num, 'queue_alert', 'Get Ready! 🎯', 
                'Token ' || COALESCE(v_target_token_num, 'N/A') || ': There are only 2 people ahead of you.', FALSE);
      END IF;
    END IF;
  END IF;

  -- CASE C: OTHER STATUS CHANGES
  IF NEW.status IN ('completed', 'hold', 'rejected', 'no_show') AND NEW.status IS DISTINCT FROM OLD.status THEN
    v_user_id := NEW.user_id;
    IF v_user_id IS NOT NULL THEN
      INSERT INTO user_notifications (user_id, token_id, token_number, type, title, message, new_status, is_read)
      VALUES (v_user_id, NEW.id, NEW.token_number, 'status_change', 
              CASE NEW.status 
                WHEN 'completed' THEN 'Service Completed ✅' 
                WHEN 'hold' THEN 'Token On Hold ⏸️' 
                WHEN 'rejected' THEN 'Token Rejected ❌'
                WHEN 'no_show' THEN 'Missed Turn ⚠️'
                ELSE 'Status Updated' 
              END,
              'Token ' || COALESCE(NEW.token_number, 'N/A') || ' status updated to ' || NEW.status, NEW.status, FALSE);
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Re-apply trigger
DROP TRIGGER IF EXISTS trg_notify_user_orchestrator ON tokens;
CREATE TRIGGER trg_notify_user_orchestrator
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_user_orchestrator();

SELECT '✅ Single-user notification logic applied. Proximity alerts removed.' as status;
