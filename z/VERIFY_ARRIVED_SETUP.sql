-- ============================================
-- 🔍 QUICK CHECK: Is Database Setup Complete?
-- ============================================
-- Run this ONE query to check everything at once
-- ============================================

SELECT 
  'Database Setup Status' as check_type,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_proc WHERE proname = 'mark_token_arrived'
    ) THEN '✅ Function exists'
    ELSE '❌ Function MISSING - Run ADD_ARRIVED_STATUS.sql'
  END as function_status,
  
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_enum 
      WHERE enumlabel = 'arrived' 
      AND enumtypid = 'token_status'::regtype
    ) THEN '✅ Status exists'
    ELSE '❌ Status MISSING - Run ADD_ARRIVED_STATUS.sql'
  END as enum_status,
  
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'tokens' 
      AND column_name = 'arrived_at'
    ) THEN '✅ Column exists'
    ELSE '❌ Column MISSING - Run ADD_ARRIVED_STATUS.sql'
  END as column_status;

-- ============================================
-- If you see ANY ❌ marks:
-- 1. Open ADD_ARRIVED_STATUS.sql
-- 2. Copy the ENTIRE file
-- 3. Paste into Supabase SQL Editor
-- 4. Click RUN
-- 5. Wait for "Success"
-- 6. Run this check again
-- ============================================
