-- ========================================
-- QUICK DIAGNOSTIC: Why ABC sees all tokens
-- ========================================

-- 1. Check ABC's profile
SELECT 
  'ABC Profile Check' as check_type,
  id,
  full_name,
  email,
  role,
  assigned_room_id,
  CASE 
    WHEN role = 'admin' THEN '❌ PROBLEM: ABC has ADMIN role - will see everything!'
    WHEN role = 'staff' AND assigned_room_id IS NULL THEN '❌ PROBLEM: ABC not assigned to any room'
    WHEN role = 'staff' AND assigned_room_id IS NOT NULL THEN '✅ ABC is staff with room assignment'
    ELSE '⚠️ Unknown situation'
  END as diagnosis
FROM profiles
WHERE email LIKE '%abc%' OR full_name ILIKE '%abc%';

-- 2. Check what room ABC is assigned to
SELECT 
  'ABC Room Assignment' as check_type,
  p.full_name,
  p.role,
  r.room_number as assigned_room,
  r.name as room_name,
  r.id as room_id
FROM profiles p
LEFT JOIN rooms r ON r.id = p.assigned_room_id
WHERE p.email LIKE '%abc%' OR p.full_name ILIKE '%abc%';

-- 3. Check tokens in Room 1 vs Room 4
SELECT 
  'Token Distribution' as check_type,
  r.room_number,
  r.name as room_name,
  COUNT(t.id) as token_count,
  COUNT(CASE WHEN t.status = 'waiting' THEN 1 END) as waiting_count
FROM rooms r
LEFT JOIN tokens t ON t.current_room_id = r.id
WHERE r.room_number IN ('1', '4')
GROUP BY r.room_number, r.name
ORDER BY r.room_number;

-- 4. Show specific tokens ABC should NOT see (Room 1)
SELECT 
  'Room 1 Tokens (ABC should NOT see these)' as check_type,
  t.token_number,
  t.status,
  r.room_number,
  r.name as room_name
FROM tokens t
JOIN rooms r ON r.id = t.current_room_id
WHERE r.room_number = '1'
LIMIT 5;

-- 5. Show specific tokens ABC SHOULD see (Room 4)
SELECT 
  'Room 4 Tokens (ABC SHOULD see these)' as check_type,
  t.token_number,
  t.status,
  r.room_number,
  r.name as room_name
FROM tokens t
JOIN rooms r ON r.id = t.current_room_id
WHERE r.room_number = '4'
LIMIT 5;

-- 6. Check current RLS policies
SELECT 
  'Current RLS Policies' as check_type,
  policyname,
  cmd,
  CASE 
    WHEN policyname LIKE '%STRICT%' THEN '✅ Strict policy exists'
    ELSE '⚠️ Old policy - may be permissive'
  END as policy_status
FROM pg_policies
WHERE tablename = 'tokens';

-- 7. Check if RLS is enabled
SELECT 
  'RLS Status' as check_type,
  tablename,
  rowsecurity as rls_enabled,
  CASE 
    WHEN rowsecurity = true THEN '✅ RLS is enabled'
    ELSE '❌ RLS is DISABLED - this is the problem!'
  END as status
FROM pg_tables
WHERE tablename = 'tokens';

-- ========================================
-- QUICK FIX COMMANDS
-- ========================================

SELECT '
========================================
QUICK FIX BASED ON DIAGNOSIS:
========================================

IF ABC HAS ADMIN ROLE:
  UPDATE profiles SET role = ''staff'' WHERE email = ''abc@example.com'';

IF ABC NOT ASSIGNED TO ROOM 4:
  UPDATE profiles 
  SET assigned_room_id = (SELECT id FROM rooms WHERE room_number = ''4'')
  WHERE email = ''abc@example.com'';

IF RLS NOT ENABLED:
  Run FIX_RLS_NOW.sql script

THEN TEST:
  1. Logout ABC from Flutter app
  2. Login again
  3. Check staff dashboard
  4. Should ONLY see Room 4 tokens

========================================
' as instructions;
