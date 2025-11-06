-- ============================================
-- 🔍 DIAGNOSE AND FIX - RUN THIS NOW
-- ============================================

-- STEP 1: Check current policies
SELECT 
  '========================================' as section,
  'Current Policies on Tokens' as description;

SELECT 
  policyname,
  cmd,
  qual as using_clause
FROM pg_policies
WHERE tablename = 'tokens'
ORDER BY cmd, policyname;

-- STEP 2: Check staff assignments
SELECT 
  '========================================' as section,
  'Staff Assignments' as description;

SELECT 
  p.id as staff_id,
  p.full_name,
  p.email,
  p.assigned_room_id,
  r.name as room_name,
  r.room_number
FROM profiles p
LEFT JOIN rooms r ON r.id = p.assigned_room_id
WHERE p.role = 'staff';

-- STEP 3: Check sample tokens
SELECT 
  '========================================' as section,
  'Sample Tokens and Their Rooms' as description;

SELECT 
  t.id as token_id,
  t.token_number,
  t.current_room_id,
  r.name as room_name,
  t.status,
  t.assigned_staff_id
FROM tokens t
LEFT JOIN rooms r ON r.id = t.current_room_id
ORDER BY t.created_at DESC
LIMIT 10;

-- ========================================
-- NOW FIX IT
-- ========================================

-- Drop ALL policies
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'tokens') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON tokens';
    END LOOP;
END $$;

-- Create ONE simple SELECT policy
CREATE POLICY "room_based_select" ON tokens
  FOR SELECT
  USING (
    -- Admin sees all
    (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'))
    OR
    -- Customer sees own
    (user_id = auth.uid())
    OR
    -- Staff sees ONLY their room
    (EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid() 
      AND p.role = 'staff'
      AND p.assigned_room_id = tokens.current_room_id
    ))
  );

-- Create ONE simple UPDATE policy
CREATE POLICY "room_based_update" ON tokens
  FOR UPDATE
  USING (
    (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'))
    OR
    (EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid() 
      AND p.role = 'staff'
      AND p.assigned_room_id = tokens.current_room_id
    ))
  )
  WITH CHECK (true);

-- Verify
SELECT 
  '========================================' as section,
  'NEW Policies Created' as description;

SELECT 
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'tokens'
ORDER BY cmd;

-- Test query for specific staff
SELECT 
  '========================================' as section,
  'Test: What Staff Can See' as description;

-- Show what each staff member should see
SELECT 
  p.full_name as staff_name,
  p.email,
  r.name as assigned_room,
  COUNT(t.id) as tokens_visible
FROM profiles p
LEFT JOIN rooms r ON r.id = p.assigned_room_id
LEFT JOIN tokens t ON t.current_room_id = p.assigned_room_id
WHERE p.role = 'staff'
GROUP BY p.full_name, p.email, r.name;

SELECT '
========================================
✅ FIX APPLIED!
========================================

CHECK THE OUTPUT ABOVE:

1. "Current Policies" - Shows old policies (before fix)
2. "Staff Assignments" - Shows which staff assigned to which room
3. "Sample Tokens" - Shows which tokens are in which rooms
4. "NEW Policies" - Shows the 2 new policies created
5. "Test" - Shows how many tokens each staff can see

WHAT TO LOOK FOR:

If staff see ALL tokens:
→ Check "Staff Assignments" 
→ Is assigned_room_id NULL? 
→ If yes, staff not assigned to room!

If staff see NO tokens:
→ Check "Sample Tokens"
→ Do tokens have current_room_id?
→ Does it match staff assigned_room_id?

NEXT STEPS:

1. Check the output above
2. If staff not assigned, run:
   UPDATE profiles 
   SET assigned_room_id = (SELECT id FROM rooms WHERE room_number = ''R003'')
   WHERE email = ''staff@example.com'';

3. Hot reload Flutter
4. Test again

SEND ME THE OUTPUT IF STILL NOT WORKING!

========================================
' as status;
