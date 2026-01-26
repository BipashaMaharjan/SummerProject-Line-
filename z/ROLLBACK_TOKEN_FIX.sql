-- ============================================
-- 🔙 ROLLBACK: Token Generation Fix
-- ============================================
-- Use this if you need to revert the changes
-- ============================================

-- STEP 1: Drop new functions
DROP FUNCTION IF EXISTS generate_token_number_atomic(UUID, TEXT);
DROP FUNCTION IF EXISTS get_service_type(UUID);
DROP FUNCTION IF EXISTS generate_token_number(UUID);

-- STEP 2: Remove service_type column from services
ALTER TABLE services DROP COLUMN IF EXISTS service_type;

-- STEP 3: Drop token_counters table
DROP TABLE IF EXISTS token_counters CASCADE;

-- STEP 4: Restore old function (if you want to go back)
CREATE OR REPLACE FUNCTION generate_token_number(service_id_param UUID)
RETURNS TEXT AS $$
DECLARE
  v_count INTEGER;
  v_token_number TEXT;
  v_today DATE;
BEGIN
  v_today := CURRENT_DATE;
  
  SELECT COUNT(*) + 1 INTO v_count
  FROM tokens
  WHERE service_id = service_id_param
    AND DATE(booked_at) = v_today;
  
  v_token_number := LPAD(v_count::TEXT, 3, '0');
  
  RETURN v_token_number;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- ⚠️ WARNING: Rolling back will restore the
-- race condition vulnerability!
-- ============================================
