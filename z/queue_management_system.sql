-- ============================================
-- 🎯 QUEUE MANAGEMENT SYSTEM - DATABASE SETUP
-- ============================================
-- Real-time queue visibility and proximity notifications
-- Automatically notifies users when they are 2 positions away
-- ============================================

-- ============================================
-- STEP 1: Create queue_status table
-- ============================================
-- Tracks the currently serving token for each service
CREATE TABLE IF NOT EXISTS queue_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id UUID REFERENCES services(id) ON DELETE CASCADE NOT NULL,
  room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  current_token_id UUID REFERENCES tokens(id) ON DELETE SET NULL,
  current_token_number TEXT,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure only one active serving token per service
  UNIQUE(service_id)
);

-- ============================================
-- STEP 2: Create indexes for performance
-- ============================================
CREATE INDEX IF NOT EXISTS idx_queue_status_service_id 
  ON queue_status(service_id);

CREATE INDEX IF NOT EXISTS idx_queue_status_room_id 
  ON queue_status(room_id);

CREATE INDEX IF NOT EXISTS idx_queue_status_updated_at 
  ON queue_status(updated_at DESC);

-- ============================================
-- STEP 3: Enable Row Level Security
-- ============================================
ALTER TABLE queue_status ENABLE ROW LEVEL SECURITY;

-- Allow everyone to view queue status (public information)
DROP POLICY IF EXISTS "Anyone can view queue status" ON queue_status;
CREATE POLICY "Anyone can view queue status" ON queue_status 
  FOR SELECT 
  USING (true);

-- Only system can update queue status
DROP POLICY IF EXISTS "System can manage queue status" ON queue_status;
CREATE POLICY "System can manage queue status" ON queue_status 
  FOR ALL 
  USING (true)
  WITH CHECK (true);

-- ============================================
-- STEP 4: Function to get current serving token
-- ============================================
CREATE OR REPLACE FUNCTION get_current_serving_token(p_service_id UUID)
RETURNS TABLE (
  token_id UUID,
  token_number TEXT,
  room_id UUID,
  room_name TEXT,
  started_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    qs.current_token_id,
    qs.current_token_number,
    qs.room_id,
    r.name as room_name,
    qs.started_at
  FROM queue_status qs
  LEFT JOIN rooms r ON r.id = qs.room_id
  WHERE qs.service_id = p_service_id
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 5: Function to calculate queue position
-- ============================================
CREATE OR REPLACE FUNCTION calculate_queue_position(p_token_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_position INTEGER;
  v_token_record RECORD;
BEGIN
  -- Get the token details
  SELECT * INTO v_token_record
  FROM tokens
  WHERE id = p_token_id;
  
  -- If token not found or not in waiting/hold status, return 0
  IF v_token_record IS NULL OR v_token_record.status NOT IN ('waiting', 'hold') THEN
    RETURN 0;
  END IF;
  
  -- Calculate position: count tokens ahead in queue
  -- Priority: higher priority first, then earlier created_at
  SELECT COUNT(*) + 1 INTO v_position
  FROM tokens t
  WHERE t.service_id = v_token_record.service_id
    AND t.status IN ('waiting', 'hold')
    AND t.id != p_token_id
    AND (
      -- Higher priority comes first
      t.priority > v_token_record.priority
      OR (
        -- Same priority, earlier created_at comes first
        t.priority = v_token_record.priority 
        AND t.created_at < v_token_record.created_at
      )
    );
  
  RETURN COALESCE(v_position, 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 6: Function to update queue status
-- ============================================
CREATE OR REPLACE FUNCTION update_queue_status()
RETURNS TRIGGER AS $$
BEGIN
  -- Only update when status changes to 'processing'
  IF NEW.status = 'processing' AND (OLD.status IS NULL OR OLD.status != 'processing') THEN
    
    -- Insert or update queue_status for this service
    INSERT INTO queue_status (
      service_id,
      room_id,
      current_token_id,
      current_token_number,
      started_at,
      updated_at
    ) VALUES (
      NEW.service_id,
      NEW.current_room_id,
      NEW.id,
      NEW.token_number,
      NOW(),
      NOW()
    )
    ON CONFLICT (service_id) 
    DO UPDATE SET
      room_id = EXCLUDED.room_id,
      current_token_id = EXCLUDED.current_token_id,
      current_token_number = EXCLUDED.current_token_number,
      started_at = EXCLUDED.started_at,
      updated_at = NOW();
    
    RAISE NOTICE 'Queue status updated: Now serving token %', NEW.token_number;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_update_queue_status ON tokens;

-- Create trigger to update queue status
CREATE TRIGGER trg_update_queue_status
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION update_queue_status();

-- ============================================
-- STEP 7: Proximity notification trigger
-- ============================================
CREATE OR REPLACE FUNCTION notify_proximity_alert()
RETURNS TRIGGER AS $$
DECLARE
  v_token_record RECORD;
  v_queue_position INTEGER;
  v_current_serving_token TEXT;
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
      END IF;
      
      -- Optional: Also notify at position 1 (uncomment if desired)
      /*
      IF v_queue_position = 1 THEN
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
          'Almost Your Turn! 🎯',
          'Token ' || v_token_record.token_number || ' is up next! Currently serving: ' || 
          v_current_serving_token || '. Please proceed to the service area.',
          FALSE,
          NOW()
        );
        
        RAISE NOTICE 'Final alert sent to user % for token % (position: 1)', 
          v_token_record.user_id, v_token_record.token_number;
      END IF;
      */
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_notify_proximity_alert ON tokens;

-- Create trigger for proximity notifications
CREATE TRIGGER trg_notify_proximity_alert
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_proximity_alert();

-- ============================================
-- STEP 8: Grant necessary permissions
-- ============================================
GRANT SELECT ON queue_status TO authenticated;
GRANT SELECT ON queue_status TO anon;

-- ============================================
-- STEP 9: Helper function to get queue info
-- ============================================
CREATE OR REPLACE FUNCTION get_queue_info_for_token(p_token_id UUID)
RETURNS TABLE (
  queue_position INTEGER,
  current_serving_token TEXT,
  tokens_ahead INTEGER,
  estimated_wait_minutes INTEGER
) AS $$
DECLARE
  v_position INTEGER;
  v_serving_token TEXT;
  v_service_id UUID;
BEGIN
  -- Get token's service
  SELECT service_id INTO v_service_id
  FROM tokens
  WHERE id = p_token_id;
  
  -- Get current serving token
  SELECT current_token_number INTO v_serving_token
  FROM queue_status
  WHERE service_id = v_service_id;
  
  -- Calculate position
  v_position := calculate_queue_position(p_token_id);
  
  RETURN QUERY
  SELECT 
    v_position as queue_position,
    v_serving_token as current_serving_token,
    GREATEST(v_position - 1, 0) as tokens_ahead,
    GREATEST(v_position - 1, 0) * 5 as estimated_wait_minutes; -- 5 min avg per token
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 10: Test queries
-- ============================================
-- Verify setup
SELECT 
  'queue_status' as table_name,
  COUNT(*) as total_rows,
  COUNT(DISTINCT service_id) as unique_services
FROM queue_status;

-- ============================================
-- ✅ SETUP COMPLETE!
-- ============================================
-- The queue management system is now ready:
-- - Real-time queue status tracking
-- - Automatic proximity notifications (2 positions away)
-- - Queue position calculation
-- - All necessary triggers and functions
-- ============================================
