-- ========================================
-- EMERGENCY FIX: RLS NOT FILTERING PROPERLY
-- ========================================
-- Staff ABC (Room 4) is seeing Room 1 tokens - THIS IS WRONG!

-- ========================================
-- STEP 1: CHECK CURRENT SITUATION
-- ========================================

-- Show ABC's profile
SELECT 
  '========================================' as info,
  'ABC Staff Profile' as section;

SELECT 
  id,
  full_name,
  email,
  role,
  assigned_room_id
FROM profiles
WHERE email LIKE '%abc%' OR full_name LIKE '%ABC%';

-- Show what room ABC is assigned to
SELECT 
  '========================================' as info,
  'ABC Room Assignment' as section;

SELECT 
  p.full_name,
  p.email,
  r.room_number,
  r.name as room_name,
  p.assigned_room_id
FROM profiles p
LEFT JOIN rooms r ON r.id = p.assigned_room_id
WHERE p.email LIKE '%abc%' OR p.full_name LIKE '%ABC%';

-- Show all tokens and their rooms
SELECT 
  '========================================' as info,
  'All Tokens Distribution' as section;

SELECT 
  t.token_number,
  t.status,
  r.room_number,
  r.name as room_name,
  t.current_room_id
FROM tokens t
LEFT JOIN rooms r ON r.id = t.current_room_id
ORDER BY r.room_number, t.token_number;

-- ========================================
-- STEP 2: CHECK CURRENT RLS POLICIES
-- ========================================

SELECT 
  '========================================' as info,
  'Current RLS Policies on Tokens' as section;

SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies
WHERE tablename = 'tokens';

-- Check if RLS is enabled
SELECT 
  '========================================' as info,
  'RLS Status' as section;

SELECT 
  schemaname,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'tokens';

-- ========================================
-- STEP 3: DROP ALL EXISTING POLICIES
-- ========================================

SELECT 
  '========================================' as info,
  'Dropping All Old Policies' as section;

DROP POLICY IF EXISTS "Room-based token filtering" ON tokens;
DROP POLICY IF EXISTS "Staff can view assigned tokens" ON tokens;
DROP POLICY IF EXISTS "Staff can view all tokens" ON tokens;
DROP POLICY IF EXISTS "Anyone can view tokens" ON tokens;
DROP POLICY IF EXISTS "Public tokens read" ON tokens;
DROP POLICY IF EXISTS "Strict room-based token access" ON tokens;
DROP POLICY IF EXISTS "Enable read access for all users" ON tokens;
DROP POLICY IF EXISTS "Enable read for authenticated users" ON tokens;
DROP POLICY IF EXISTS "Staff can update their room tokens" ON tokens;
DROP POLICY IF EXISTS "Staff can update assigned room tokens" ON tokens;
DROP POLICY IF EXISTS "Staff can update tokens" ON tokens;

-- ========================================
-- STEP 4: CREATE SUPER STRICT POLICY
-- ========================================

SELECT 
  '========================================' as info,
  'Creating STRICT Room-Based Policy' as section;

-- CRITICAL: This policy MUST filter by room for staff
CREATE POLICY "STRICT_room_filter_v2" ON tokens
  FOR SELECT
  TO authenticated
  USING (
    -- Case 1: Admin sees everything
    (
      EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'admin'
      )
    )
    OR
    -- Case 2: Customer sees only their own tokens
    (
      tokens.user_id = auth.uid()
      AND
      EXISTS (
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

-- Update policy for staff
CREATE POLICY "STRICT_room_update_v2" ON tokens
  FOR UPDATE
  TO authenticated
  USING (
    -- Admin can update all
    (
      EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'admin'
      )
    )
    OR
    -- Staff can only update tokens in their room
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

-- ========================================
-- STEP 5: ENSURE RLS IS ENABLED
-- ========================================

SELECT 
  '========================================' as info,
  'Enabling RLS' as section;

ALTER TABLE tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE tokens FORCE ROW LEVEL SECURITY;

-- ========================================
-- STEP 6: VERIFY THE FIX
-- ========================================

SELECT 
  '========================================' as info,
  'Verification - New Policies' as section;

SELECT 
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'tokens'
ORDER BY policyname;

-- ========================================
-- STEP 7: TEST QUERY (Run as ABC)
-- ========================================

SELECT 
  '========================================' as info,
  'Test: What ABC Should See' as section;

-- This simulates what ABC will see
-- Replace USER_ID_OF_ABC with actual ABC user ID
SELECT 
  '
To test as ABC staff member:
1. Get ABC user ID from profiles table
2. Run this query in a new SQL editor tab while authenticated as ABC:

SELECT * FROM tokens;

ABC should ONLY see tokens where current_room_id matches their assigned_room_id
' as instructions;

-- Show Room 4 ID for reference
SELECT 
  '========================================' as info,
  'Room 4 Information' as section;

SELECT 
  id as room_4_id,
  room_number,
  name
FROM rooms
WHERE room_number = '4';

-- ========================================
-- COMPLETION MESSAGE
-- ========================================

SELECT 
  '
========================================
✅ STRICT RLS POLICIES APPLIED
========================================

WHAT CHANGED:
1. Dropped ALL old permissive policies
2. Created STRICT room-based filtering
3. Enabled FORCE ROW LEVEL SECURITY
4. Staff can ONLY see their room tokens

NEXT STEPS:
1. Verify ABC is assigned to Room 4:
   SELECT assigned_room_id FROM profiles WHERE email = ''abc@example.com'';

2. Verify tokens have current_room_id set:
   SELECT token_number, current_room_id FROM tokens;

3. Test by logging into Flutter app as ABC
   - Should ONLY see Room 4 tokens
   - Should NOT see Room 1, 2, 3, or 5 tokens

IF STILL NOT WORKING:
- Check if ABC has admin role (would see everything)
- Check if tokens have NULL current_room_id (would not appear)
- Check if ABC assigned_room_id is NULL (would see nothing)

========================================
' as completion;
