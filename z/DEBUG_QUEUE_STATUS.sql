-- ============================================
-- 🔍 QUICK CHECK: Is Queue System Set Up?
-- ============================================
-- Run these queries to diagnose the loading issue

-- 1. Does the queue_status table exist?
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' 
  AND table_name = 'queue_status'
) as table_exists;

-- 2. Is there any data in queue_status?
SELECT 
  id,
  service_id,
  current_token_number,
  updated_at
FROM queue_status;

-- 3. Are there any tokens currently processing?
SELECT 
  token_number,
  status,
  service_id
FROM tokens 
WHERE status = 'processing';

-- ============================================
-- 🔧 QUICK FIX: If table doesn't exist
-- ============================================
-- If query #1 returns FALSE, run this:
-- (Copy from queue_management_system.sql and run it)

-- ============================================
-- 🔧 QUICK FIX: If table is empty but should have data
-- ============================================
-- If you have a processing token but queue_status is empty,
-- the trigger might not have fired. Manually update a token:

-- UPDATE tokens 
-- SET status = 'processing' 
-- WHERE id = 'your-token-id-here';
