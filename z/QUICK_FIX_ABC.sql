-- ========================================
-- QUICK FIX: ABC Seeing All Tokens
-- ========================================
-- RLS is enabled, so the problem is in the policies or ABC's role

-- STEP 1: Check ABC's role (MOST LIKELY PROBLEM)
-- ========================================
SELECT 
  '1. ABC ROLE CHECK' as step,
  full_name,
  email,
  role,
  assigned_room_id,
  CASE 
    WHEN role = 'admin' THEN '❌ THIS IS THE PROBLEM! ABC has admin role - change to staff'
    WHEN role = 'staff' THEN '✅ Role is correct'
    ELSE '⚠️ Unknown role'
  END as issue
FROM profiles
WHERE email LIKE '%abc%' OR full_name ILIKE '%abc%';

-- STEP 2: Fix ABC's role if it's admin
-- ========================================
-- Uncomment and run if ABC has admin role:
-- UPDATE profiles SET role = 'staff' WHERE email LIKE '%abc%';

-- STEP 3: Check current policies
-- ========================================
SELECT 
  '2. CURRENT POLICIES' as step,
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'tokens'
ORDER BY policyname;

-- STEP 4: Drop ALL old policies and create strict one
-- ========================================

-- Drop everything
DROP POLICY IF EXISTS "Room-based token filtering" ON tokens;
DROP POLICY IF EXISTS "Staff can view assigned tokens" ON tokens;
DROP POLICY IF EXISTS "Staff can view all tokens" ON tokens;
DROP POLICY IF EXISTS "STRICT_room_filter_v2" ON tokens;
DROP POLICY IF EXISTS "STRICT_room_update_v2" ON tokens;
DROP POLICY IF EXISTS "Enable read access for all users" ON tokens;

-- Create ONE strict policy
CREATE POLICY "tokens_select_policy" ON tokens
  FOR SELECT
  USING (
    -- Admin sees all
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    OR
    -- Customer sees own
    (user_id = auth.uid() AND (SELECT role FROM profiles WHERE id = auth.uid()) = 'customer')
    OR
    -- Staff sees ONLY their room's tokens
    (
      (SELECT role FROM profiles WHERE id = auth.uid()) = 'staff'
      AND
      current_room_id = (SELECT assigned_room_id FROM profiles WHERE id = auth.uid())
    )
  );

-- STEP 5: Verify ABC's room assignment
-- ========================================
SELECT 
  '3. ABC ROOM ASSIGNMENT' as step,
  p.full_name,
  p.email,
  p.role,
  p.assigned_room_id,
  r.room_number,
  r.name as room_name
FROM profiles p
LEFT JOIN rooms r ON r.id = p.assigned_room_id
WHERE p.email LIKE '%abc%' OR p.full_name ILIKE '%abc%';

-- If ABC not assigned to Room 4, run this:
-- UPDATE profiles 
-- SET assigned_room_id = (SELECT id FROM rooms WHERE room_number = '4')
-- WHERE email LIKE '%abc%';

-- STEP 6: Verify tokens have room assignments
-- ========================================
SELECT 
  '4. TOKENS WITHOUT ROOMS' as step,
  COUNT(*) as tokens_with_null_room
FROM tokens
WHERE current_room_id IS NULL;

-- If tokens have NULL rooms, assign them to Room 1:
-- UPDATE tokens 
-- SET current_room_id = (SELECT id FROM rooms WHERE room_number = '1')
-- WHERE current_room_id IS NULL;

-- STEP 7: Final verification
-- ========================================
SELECT 
  '5. FINAL CHECK' as step,
  'Policy created: tokens_select_policy' as status;

SELECT 
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'tokens';

-- ========================================
-- INSTRUCTIONS
-- ========================================
SELECT '
========================================
NEXT STEPS:
========================================

1. Check the output above for ABC role
   - If ABC has "admin" role, run:
     UPDATE profiles SET role = ''staff'' WHERE email LIKE ''%abc%'';

2. Verify ABC is assigned to Room 4
   - If not, run:
     UPDATE profiles 
     SET assigned_room_id = (SELECT id FROM rooms WHERE room_number = ''4'')
     WHERE email LIKE ''%abc%'';

3. In Flutter app:
   - LOGOUT ABC completely
   - CLOSE the app
   - REOPEN and login as ABC
   - Check staff dashboard

ABC should now ONLY see Room 4 tokens!

========================================
' as instructions;
