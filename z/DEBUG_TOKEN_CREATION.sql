-- ============================================
-- 🔍 DEBUG: Check Token Creation Setup
-- ============================================
-- Run this to verify token creation is working
-- ============================================

-- 1. Check if token_counters table exists
SELECT table_name 
FROM information_schema.tables 
WHERE table_name = 'token_counters';

-- Expected: 1 row

-- 2. Check if generate_token_number_atomic function exists
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname = 'generate_token_number_atomic';

-- Expected: 1 row showing the function

-- 3. Check current token counters
SELECT * FROM token_counters ORDER BY updated_at DESC;

-- 4. Test token generation manually
SELECT generate_token_number_atomic(
  '02a27834-69d3-4c4b-9635-81f91130945f'::uuid,  -- License Renewal service
  'renewal'
);

-- Expected: Returns '001', '002', etc.

-- ============================================
-- ✅ TROUBLESHOOTING
-- ============================================
-- If token_counters table doesn't exist:
--   → Run this:
--
-- CREATE TABLE IF NOT EXISTS token_counters (
--     service_id UUID NOT NULL,
--     service_type TEXT NOT NULL,
--     current_number INTEGER DEFAULT 0,
--     updated_at TIMESTAMPTZ DEFAULT NOW(),
--     PRIMARY KEY (service_id, service_type)
-- );
--
-- If function doesn't exist:
--   → Run FIX_TOKEN_GENERATION_ATOMIC.sql
-- ============================================
