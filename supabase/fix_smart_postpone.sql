-- ============================================
-- 🎯 SMART POSTPONE (MOVE BACK 5 SPOTS) - ULTIMATE FIX
-- ============================================
-- This script ensures that tokens ACTUALLY move, even if they 
-- have different priorities (like 0 and -1).
-- ============================================

-- 1. Reset standard users to Priority 0 (Cleanup)
-- This fixes the issue where some tokens are "stuck" due to old scripts
UPDATE tokens 
SET priority = 0 
WHERE priority < 0 AND status IN ('waiting', 'arrived');

-- 2. Robust Position Calculation
-- Uses a stable sort: Priority -> Time -> ID
CREATE OR REPLACE FUNCTION calculate_queue_position(p_token_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_token RECORD;
  v_pos INTEGER;
  v_target_date DATE;
BEGIN
  -- Get the target token
  SELECT *, COALESCE(scheduled_date::date, booked_at::date, created_at::date) as target_date 
  INTO v_token 
  FROM tokens WHERE id = p_token_id;
  
  -- If token not found or not waiting, position is 0
  IF v_token IS NULL OR v_token.status NOT IN ('waiting', 'arrived') THEN 
    RETURN 0; 
  END IF;

  v_target_date := v_token.target_date;

  -- Count tokens AHEAD in the actual visual list
  SELECT COUNT(*) + 1 INTO v_pos
  FROM tokens t
  WHERE t.service_id = v_token.service_id
    AND t.status IN ('waiting', 'arrived')
    AND COALESCE(t.scheduled_date::date, t.booked_at::date, t.created_at::date) = v_target_date
    AND (
      t.priority > v_token.priority  -- Higher priority is always ahead
      OR (
        t.priority = v_token.priority -- Same priority, check time
        AND (
          COALESCE(t.booked_at, t.created_at) < COALESCE(v_token.booked_at, v_token.created_at)
          OR (COALESCE(t.booked_at, t.created_at) = COALESCE(v_token.booked_at, v_token.created_at) AND t.id < v_token.id)
        )
      )
    );
    
  RETURN v_pos;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Smart Postpone Function
-- Moves a token back by p_offset positions by INHERITING priority/time
CREATE OR REPLACE FUNCTION postpone_token_smart(p_token_id UUID, p_offset INTEGER DEFAULT 5)
RETURNS BOOLEAN AS $$
DECLARE
  v_target_time TIMESTAMPTZ;
  v_target_priority INTEGER;
  v_service_id UUID;
  v_target_date DATE;
BEGIN
  -- 1. Get current token info
  SELECT service_id, COALESCE(scheduled_date::date, booked_at::date, created_at::date) as target_date 
  INTO v_service_id, v_target_date 
  FROM tokens WHERE id = p_token_id;

  IF v_service_id IS NULL THEN RETURN FALSE; END IF;

  -- 2. Find the person at EXACTLY (offset) positions behind us
  -- We order by Priority DESC, Time ASC to find who is VISUALLY behind
  SELECT COALESCE(booked_at, created_at), priority 
  INTO v_target_time, v_target_priority
  FROM tokens
  WHERE service_id = v_service_id 
    AND status IN ('waiting', 'arrived')
    AND COALESCE(scheduled_date::date, booked_at::date, created_at::date) = v_target_date
    AND id != p_token_id
    -- This looks for people who are AFTER us in the queue
    AND (
      priority < (SELECT priority FROM tokens WHERE id = p_token_id)
      OR (
        priority = (SELECT priority FROM tokens WHERE id = p_token_id)
        AND COALESCE(booked_at, created_at) > (SELECT COALESCE(booked_at, created_at) FROM tokens WHERE id = p_token_id)
      )
    )
  ORDER BY priority DESC, COALESCE(booked_at, created_at) ASC, id ASC
  OFFSET (p_offset - 1) LIMIT 1;

  -- 3. Update the token
  IF v_target_time IS NULL THEN
    -- If there aren't enough people behind, move to the absolute end
    v_target_time := NOW();
    v_target_priority := -10; -- Low enough to be behind everyone
  ELSE
    -- Move to 1 second AFTER that 5th person
    v_target_time := v_target_time + INTERVAL '1 second';
    -- IMPORTANT: Inherit their priority so we don't jump ahead due to priority levels
  END IF;

  UPDATE tokens 
  SET booked_at = v_target_time, 
      priority = COALESCE(v_target_priority, -10),
      updated_at = NOW() 
  WHERE id = p_token_id;
  
  -- 4. Log history
  INSERT INTO token_history (token_id, action, notes)
  VALUES (p_token_id, 'postponed', 'User moved back 5 spots (Inherited priority)');

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

SELECT '✅ ULTIMATE Smart Postpone logic applied. Priority-aware movement is active.' as status;
