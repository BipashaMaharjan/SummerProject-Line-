-- ============================================
-- 🎯 ADD ARRIVED STATUS + AUTO-REJECTION
-- ============================================
-- Part 1: Add 'arrived' status
-- Part 2: Auto-reject tokens if user doesn't arrive by scheduled date
-- ============================================

-- PART 1: Add 'arrived' to token status
-- ============================================

-- Step 1: Add 'arrived' to the enum (if using enum type)
DO $$ 
BEGIN
    -- Check if the type exists and add value if it doesn't
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum 
        WHERE enumlabel = 'arrived' 
        AND enumtypid = 'token_status'::regtype
    ) THEN
        ALTER TYPE token_status ADD VALUE 'arrived';
    END IF;
END $$;

-- Step 2: Add arrived_at timestamp column
ALTER TABLE tokens ADD COLUMN IF NOT EXISTS arrived_at TIMESTAMPTZ;

-- Step 3: Create index for performance
CREATE INDEX IF NOT EXISTS idx_tokens_arrived_at ON tokens(arrived_at) WHERE arrived_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tokens_status_scheduled ON tokens(status, scheduled_date);

-- ============================================
-- PART 2: Function to mark token as arrived
-- ============================================

CREATE OR REPLACE FUNCTION mark_token_arrived(p_token_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_updated_count INTEGER;
BEGIN
    -- Update token status to 'arrived' and record timestamp
    UPDATE tokens
    SET 
        status = 'arrived',
        arrived_at = NOW(),
        updated_at = NOW()
    WHERE id = p_token_id
      AND status = 'waiting'  -- Only allow from waiting status
      AND user_id = auth.uid()  -- Security: only token owner can mark arrived
    RETURNING 1 INTO v_updated_count;
    
    -- Return true if updated, false otherwise
    RETURN v_updated_count = 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permission to authenticated users
GRANT EXECUTE ON FUNCTION mark_token_arrived(UUID) TO authenticated;

-- ============================================
-- PART 3: Auto-reject tokens that didn't arrive
-- ============================================

CREATE OR REPLACE FUNCTION auto_reject_no_show_tokens()
RETURNS INTEGER AS $$
DECLARE
    v_rejected_count INTEGER;
BEGIN
    -- Reject tokens where:
    -- 1. Status is still 'waiting' (not arrived)
    -- 2. Scheduled date has passed (e.g., booked for 5 Magh, now it's 6 Magh)
    -- 3. Grace period of 1 day has passed
    
    WITH rejected_tokens AS (
        UPDATE tokens
        SET 
            status = 'rejected',
            notes = COALESCE(notes || ' | ', '') || 'Auto-rejected: Did not arrive by scheduled date',
            updated_at = NOW()
        WHERE status = 'waiting'
          AND scheduled_date IS NOT NULL
          AND scheduled_date < CURRENT_DATE - INTERVAL '1 day'  -- 1 day grace period
        RETURNING id
    )
    SELECT COUNT(*) INTO v_rejected_count FROM rejected_tokens;
    
    IF v_rejected_count > 0 THEN
        RAISE NOTICE 'Auto-rejected % tokens for no-show', v_rejected_count;
    END IF;
    
    RETURN v_rejected_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- PART 4: Schedule auto-rejection (runs daily)
-- ============================================

-- Create a cron job to run daily at midnight (requires pg_cron extension)
-- If you don't have pg_cron, you can call this function manually or from your app

-- Option 1: Using pg_cron (if available)
/*
SELECT cron.schedule(
    'auto-reject-no-shows',
    '0 0 * * *',  -- Every day at midnight
    $$SELECT auto_reject_no_show_tokens();$$
);
*/

-- Option 2: Manual execution (run this daily)
-- SELECT auto_reject_no_show_tokens();

-- ============================================
-- PART 5: Update proximity notifications
-- ============================================

-- Update proximity alert to only notify arrived tokens
CREATE OR REPLACE FUNCTION notify_proximity_alert()
RETURNS TRIGGER AS $$
DECLARE
  v_token_record RECORD;
  v_queue_position INTEGER;
  v_current_serving_token TEXT;
  v_existing_notification_count INTEGER;
BEGIN
  IF NEW.status = 'processing' AND (OLD.status IS NULL OR OLD.status != 'processing') THEN
    v_current_serving_token := NEW.token_number;
    
    FOR v_token_record IN
      SELECT 
        t.id,
        t.user_id,
        t.token_number,
        t.service_id,
        calculate_queue_position(t.id) as position
      FROM tokens t
      WHERE t.service_id = NEW.service_id
        AND t.status = 'arrived'  -- ✅ Changed from 'waiting' to 'arrived'
        AND t.user_id IS NOT NULL
    LOOP
      v_queue_position := v_token_record.position;
      
      IF v_queue_position = 2 THEN
        SELECT COUNT(*) INTO v_existing_notification_count
        FROM user_notifications
        WHERE user_id = v_token_record.user_id
          AND token_id = v_token_record.id
          AND type = 'queue_alert'
          AND created_at > NOW() - INTERVAL '5 minutes';
        
        IF v_existing_notification_count = 0 THEN
          INSERT INTO user_notifications (
            user_id, token_id, token_number, type, title, message, is_read, created_at
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
          
          RAISE NOTICE 'Proximity alert sent to user % for token %', 
            v_token_record.user_id, v_token_record.token_number;
        END IF;
      END IF;
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- PART 6: Update queue position calculation
-- ============================================

-- Prioritize arrived tokens over waiting tokens
CREATE OR REPLACE FUNCTION calculate_queue_position(p_token_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_position INTEGER;
  v_token_record RECORD;
BEGIN
  SELECT * INTO v_token_record FROM tokens WHERE id = p_token_id;
  
  IF v_token_record IS NULL OR v_token_record.status NOT IN ('waiting', 'arrived', 'hold') THEN
    RETURN 0;
  END IF;
  
  -- Count tokens ahead in queue
  -- Priority order: arrived tokens first, then waiting tokens
  SELECT COUNT(*) + 1 INTO v_position
  FROM tokens t
  WHERE t.service_id = v_token_record.service_id
    AND t.status IN ('waiting', 'arrived', 'hold')
    AND t.id != p_token_id
    AND (
      -- Arrived tokens always come before waiting tokens
      (t.status = 'arrived' AND v_token_record.status = 'waiting')
      OR
      -- Within same status, higher priority comes first
      (t.status = v_token_record.status AND t.priority > v_token_record.priority)
      OR
      -- Same status and priority, earlier created_at comes first
      (t.status = v_token_record.status AND t.priority = v_token_record.priority AND t.created_at < v_token_record.created_at)
    );
  
  RETURN COALESCE(v_position, 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- ✅ SETUP COMPLETE!
-- ============================================
-- What was added:
-- 1. 'arrived' status for tokens
-- 2. arrived_at timestamp tracking
-- 3. mark_token_arrived() function for users
-- 4. auto_reject_no_show_tokens() for scheduled dates
-- 5. Updated proximity alerts (only arrived tokens)
-- 6. Updated queue position (arrived tokens prioritized)
--
-- Next steps:
-- 1. Update Flutter model to include 'arrived' status
-- 2. Add "I'm Here" button in user app
-- 3. Update staff dashboard to filter by arrived tokens
-- 4. Schedule daily auto-rejection job
-- ============================================
