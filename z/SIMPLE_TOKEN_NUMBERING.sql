-- ============================================
-- 🔢 SIMPLE SEQUENTIAL TOKEN NUMBERING - FIXED
-- ============================================
-- Step 1: Drop the old function first
-- Step 2: Create new simple numbering function
-- ============================================

-- STEP 1: Remove old function
DROP FUNCTION IF EXISTS generate_token_number(uuid);

-- STEP 2: Create new simple sequential numbering
-- Default: Daily Reset (001, 002, 003... resets each day)
CREATE OR REPLACE FUNCTION generate_token_number(service_id_param UUID)
RETURNS TEXT AS $$
DECLARE
  v_count INTEGER;
  v_token_number TEXT;
  v_today DATE;
BEGIN
  -- Get today's date
  v_today := CURRENT_DATE;
  
  -- Count tokens created today for this service
  SELECT COUNT(*) + 1 INTO v_count
  FROM tokens
  WHERE service_id = service_id_param
    AND DATE(booked_at) = v_today;
  
  -- Generate simple sequential number with leading zeros
  v_token_number := LPAD(v_count::TEXT, 3, '0');
  
  RETURN v_token_number;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- ✅ DONE! Your tokens will now be: 001, 002, 003
-- ============================================

-- Test it (replace with your actual service ID):
-- SELECT generate_token_number('your-service-id-here');
