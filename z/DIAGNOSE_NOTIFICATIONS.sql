-- ============================================
-- 🔍 COMPREHENSIVE NOTIFICATION DIAGNOSTICS
-- ============================================
-- This script checks the entire notification system
-- for both staff and users
-- ============================================

-- SECTION 1: Check if staff_notifications table exists
SELECT 
  'staff_notifications table' as check_name,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_name = 'staff_notifications'
    ) THEN '✅ EXISTS'
    ELSE '❌ MISSING'
  END as status;

-- SECTION 2: Check staff_notifications table structure
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'staff_notifications'
ORDER BY ordinal_position;

-- SECTION 3: Check if user_notifications table exists
SELECT 
  'user_notifications table' as check_name,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_name = 'user_notifications'
    ) THEN '✅ EXISTS'
    ELSE '❌ MISSING - This is likely the problem!'
  END as status;

-- SECTION 4: Check RLS policies on staff_notifications
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'staff_notifications'
ORDER BY policyname;

-- SECTION 5: Check triggers on tokens table
SELECT 
  trigger_name,
  event_manipulation,
  action_timing,
  action_statement
FROM information_schema.triggers
WHERE event_object_table = 'tokens'
ORDER BY trigger_name;

-- SECTION 6: Check if notification functions exist
SELECT 
  routine_name,
  routine_type,
  data_type as return_type
FROM information_schema.routines
WHERE routine_name LIKE '%notif%'
ORDER BY routine_name;

-- SECTION 7: Count notifications in staff_notifications
SELECT 
  'Total staff notifications' as metric,
  COUNT(*) as count
FROM staff_notifications
UNION ALL
SELECT 
  'Unread staff notifications' as metric,
  COUNT(*) as count
FROM staff_notifications
WHERE is_read = FALSE
UNION ALL
SELECT 
  'Staff notifications (last 24h)' as metric,
  COUNT(*) as count
FROM staff_notifications
WHERE created_at > NOW() - INTERVAL '24 hours';

-- SECTION 8: Check recent staff notifications
SELECT 
  id,
  staff_id,
  token_number,
  type,
  message,
  is_read,
  created_at,
  new_room_name,
  new_status
FROM staff_notifications
ORDER BY created_at DESC
LIMIT 10;

-- SECTION 9: Check if there are any tokens
SELECT 
  'Total tokens' as metric,
  COUNT(*) as count
FROM tokens
UNION ALL
SELECT 
  'Tokens with current_room_id' as metric,
  COUNT(*) as count
FROM tokens
WHERE current_room_id IS NOT NULL
UNION ALL
SELECT 
  'Tokens with assigned_staff_id' as metric,
  COUNT(*) as count
FROM tokens
WHERE assigned_staff_id IS NOT NULL;

-- SECTION 10: Check recent token updates
SELECT 
  id,
  token_number,
  status,
  current_room_id,
  assigned_staff_id,
  updated_at
FROM tokens
ORDER BY updated_at DESC
LIMIT 5;

-- SECTION 11: Check staff and their assigned rooms
SELECT 
  p.id,
  p.email,
  p.role,
  p.assigned_room_id,
  r.name as room_name
FROM profiles p
LEFT JOIN rooms r ON p.assigned_room_id = r.id
WHERE p.role IN ('staff', 'admin')
ORDER BY p.role, p.email;

-- SECTION 12: Test if triggers are firing
-- This will show if there are any errors in the trigger functions
DO $$
DECLARE
  v_test_token_id UUID;
  v_test_room_id UUID;
BEGIN
  -- Get a test token
  SELECT id INTO v_test_token_id FROM tokens LIMIT 1;
  
  -- Get a test room
  SELECT id INTO v_test_room_id FROM rooms LIMIT 1;
  
  IF v_test_token_id IS NOT NULL AND v_test_room_id IS NOT NULL THEN
    RAISE NOTICE '✅ Test data available - token: %, room: %', v_test_token_id, v_test_room_id;
  ELSE
    RAISE WARNING '❌ No test data available';
  END IF;
END $$;

-- ============================================
-- SUMMARY
-- ============================================
-- Review the results above to identify issues:
-- 1. Check if staff_notifications table exists
-- 2. Check if user_notifications table exists (likely missing!)
-- 3. Verify RLS policies are in place
-- 4. Verify triggers are created
-- 5. Check if there are any notifications
-- 6. Check if tokens and staff exist
-- ============================================
