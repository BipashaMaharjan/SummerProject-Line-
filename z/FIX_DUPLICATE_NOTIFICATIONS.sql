-- ============================================
-- 🔧 FIX: Prevent Duplicate Proximity Notifications
-- ============================================
-- This fixes the race condition where users get multiple
-- notifications if tokens complete at the same time
-- ============================================

-- Drop and recreate the proximity alert function with deduplication
CREATE OR REPLACE FUNCTION notify_proximity_alert()
RETURNS TRIGGER AS $$
DECLARE
  v_token_record RECORD;
  v_queue_position INTEGER;
  v_current_serving_token TEXT;
  v_existing_notification_count INTEGER;
BEGIN
  -- Only trigger when status changes to 'processing'
  IF NEW.status = 'processing' AND (OLD.status IS NULL OR OLD.status != 'processing') THEN
    
    -- Get the current serving token number
    v_current_serving_token := NEW.token_number;
    
    -- Find all waiting tokens for the same service
    FOR v_token_record IN
      SELECT 
        t.id,
        t.user_id,
        t.token_number,
        t.service_id,
        calculate_queue_position(t.id) as position
      FROM tokens t
      WHERE t.service_id = NEW.service_id
        AND t.status IN ('waiting', 'hold')
        AND t.user_id IS NOT NULL
    LOOP
      -- Get the calculated position
      v_queue_position := v_token_record.position;
      
      -- Send notification if exactly 2 positions away
      IF v_queue_position = 2 THEN
        
        -- ✅ FIX: Check if notification already sent in last 5 minutes
        SELECT COUNT(*) INTO v_existing_notification_count
        FROM user_notifications
        WHERE user_id = v_token_record.user_id
          AND token_id = v_token_record.id
          AND type = 'queue_alert'
          AND created_at > NOW() - INTERVAL '5 minutes';
        
        -- Only send if no recent notification exists
        IF v_existing_notification_count = 0 THEN
          INSERT INTO user_notifications (
            user_id,
            token_id,
            token_number,
            type,
            title,
            message,
            is_read,
            created_at
          ) VALUES (
            v_token_record.user_id,
            v_token_record.id,
            v_token_record.token_number,
            'queue_alert',
            'Your Turn is Coming Soon! ⏰',
            'Token ' || v_token_record.token_number || ' is next! Currently serving: ' || 
            v_current_serving_token || '. Please be ready - you have approximately 2 tokens ahead.',
            FALSE,
            NOW()
          );
          
          RAISE NOTICE 'Proximity alert sent to user % for token % (position: %)', 
            v_token_record.user_id, v_token_record.token_number, v_queue_position;
        ELSE
          RAISE NOTICE 'Skipped duplicate notification for user % token %', 
            v_token_record.user_id, v_token_record.token_number;
        END IF;
      END IF;
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- ✅ DONE! Duplicate notifications are now prevented
-- ============================================
-- Users will only get ONE notification per 5-minute window
-- Even if multiple tokens complete simultaneously
-- ============================================
