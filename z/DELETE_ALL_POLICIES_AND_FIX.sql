-- ========================================
-- DELETE ALL OLD POLICIES AND CREATE STRICT ONE
-- ========================================
-- Problem: Multiple old policies are conflicting
-- Solution: Delete everything and create ONE strict policy

-- ========================================
-- STEP 1: DELETE ALL OLD POLICIES
-- ========================================

DROP POLICY IF EXISTS "Room-based token filtering" ON tokens;
DROP POLICY IF EXISTS "Staff can update their room tokens" ON tokens;
DROP POLICY IF EXISTS "Strict staff token visibility" ON tokens;
DROP POLICY IF EXISTS "tok_ins_own_v3" ON tokens;
DROP POLICY IF EXISTS "tok_sel_own_v3" ON tokens;
DROP POLICY IF EXISTS "tok_sel_staff_v3" ON tokens;
DROP POLICY IF EXISTS "tok_upd_own_wait_v3" ON tokens;
DROP POLICY IF EXISTS "tok_upd_staff_v3" ON tokens;
DROP POLICY IF EXISTS "STRICT_room_filter_v2" ON tokens;
DROP POLICY IF EXISTS "STRICT_room_update_v2" ON tokens;
DROP POLICY IF EXISTS "tokens_select_policy" ON tokens;

-- Delete any other policies that might exist
DROP POLICY IF EXISTS "Enable read access for all users" ON tokens;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON tokens;
DROP POLICY IF EXISTS "Enable update for users based on user_id" ON tokens;

SELECT '✅ All old policies deleted' as status;

-- ========================================
-- STEP 2: CREATE ONE STRICT SELECT POLICY
-- ========================================

CREATE POLICY "strict_room_based_select" ON tokens
  FOR SELECT
  USING (
    -- Case 1: Admin sees ALL tokens
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'admin'
    )
    OR
    -- Case 2: Customer sees ONLY their own tokens
    (
      tokens.user_id = auth.uid()
      AND EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'customer'
      )
    )
    OR
    -- Case 3: Staff sees ONLY tokens in their assigned room
    (
      EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'staff'
        AND profiles.assigned_room_id IS NOT NULL
        AND profiles.assigned_room_id = tokens.current_room_id
      )
    )
  );

SELECT '✅ Strict SELECT policy created' as status;

-- ========================================
-- STEP 3: CREATE STRICT INSERT POLICY
-- ========================================

CREATE POLICY "strict_token_insert" ON tokens
  FOR INSERT
  WITH CHECK (
    -- Users can insert their own tokens
    auth.uid() = user_id
    OR
    -- Admin can insert any token
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'admin'
    )
  );

SELECT '✅ Strict INSERT policy created' as status;

-- ========================================
-- STEP 4: CREATE STRICT UPDATE POLICY
-- ========================================

CREATE POLICY "strict_room_based_update" ON tokens
  FOR UPDATE
  USING (
    -- Admin can update all tokens
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'admin'
    )
    OR
    -- Staff can ONLY update tokens in their assigned room
    (
      EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'staff'
        AND profiles.assigned_room_id IS NOT NULL
        AND profiles.assigned_room_id = tokens.current_room_id
      )
    )
    OR
    -- Users can update their own waiting tokens (for cancellation)
    (
      tokens.user_id = auth.uid()
      AND tokens.status = 'waiting'
    )
  );

SELECT '✅ Strict UPDATE policy created' as status;

-- ========================================
-- STEP 5: VERIFY NEW POLICIES
-- ========================================

SELECT 
  '========================================' as separator,
  'NEW POLICIES (Should be only 3)' as info;

SELECT 
  policyname,
  cmd,
  CASE 
    WHEN policyname LIKE 'strict%' THEN '✅ NEW STRICT POLICY'
    ELSE '⚠️ OLD POLICY - SHOULD NOT EXIST'
  END as status
FROM pg_policies
WHERE tablename = 'tokens'
ORDER BY policyname;

-- ========================================
-- STEP 6: VERIFY ABC SETUP
-- ========================================

SELECT 
  '========================================' as separator,
  'ABC STAFF VERIFICATION' as info;

SELECT 
  p.full_name,
  p.email,
  p.role,
  r.room_number as assigned_room,
  r.name as room_name,
  CASE 
    WHEN p.role = 'admin' THEN '❌ ABC has ADMIN role - change to staff!'
    WHEN p.role = 'staff' AND p.assigned_room_id IS NULL THEN '❌ ABC not assigned to any room!'
    WHEN p.role = 'staff' AND r.room_number = '4' THEN '✅ ABC correctly assigned to Room 4'
    ELSE '⚠️ Check assignment'
  END as status
FROM profiles p
LEFT JOIN rooms r ON r.id = p.assigned_room_id
WHERE p.email LIKE '%abc%' OR p.full_name ILIKE '%abc%';

-- ========================================
-- STEP 7: CHECK TOKEN DISTRIBUTION
-- ========================================

SELECT 
  '========================================' as separator,
  'TOKEN DISTRIBUTION BY ROOM' as info;

SELECT 
  COALESCE(r.room_number, 'No Room') as room,
  COALESCE(r.name, 'Unassigned') as room_name,
  COUNT(t.id) as total_tokens,
  COUNT(CASE WHEN t.status = 'waiting' THEN 1 END) as waiting
FROM tokens t
LEFT JOIN rooms r ON r.id = t.current_room_id
GROUP BY r.room_number, r.name
ORDER BY r.room_number;

-- ========================================
-- COMPLETION MESSAGE
-- ========================================

SELECT '
========================================
✅ POLICIES FIXED!
========================================

WHAT WAS DONE:
1. ❌ Deleted ALL old permissive policies (tok_sel_staff_v3, etc.)
2. ✅ Created 3 new STRICT policies:
   - strict_room_based_select (staff see ONLY their room)
   - strict_token_insert (users insert own tokens)
   - strict_room_based_update (staff update ONLY their room)

NEXT STEPS:
1. Check ABC status above
   - If ABC has admin role: UPDATE profiles SET role = ''staff'' WHERE email LIKE ''%abc%'';
   - If ABC not in Room 4: UPDATE profiles SET assigned_room_id = (SELECT id FROM rooms WHERE room_number = ''4'') WHERE email LIKE ''%abc%'';

2. In Flutter app:
   - LOGOUT ABC
   - CLOSE app completely
   - REOPEN and login as ABC
   - Staff dashboard should ONLY show Room 4 tokens

3. Test:
   - ABC should NOT see Room 1 tokens
   - ABC should ONLY see Room 4 tokens

========================================
' as completion_message;
