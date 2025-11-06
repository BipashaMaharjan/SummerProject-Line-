-- ============================================
-- 🔒 FIX VISIBILITY - STRICT ROOM-BASED
-- ============================================
-- Only assigned staff see their room's tickets
-- ============================================

-- ========================================
-- STEP 1: DROP EXISTING SELECT POLICY
-- ========================================

DROP POLICY IF EXISTS "view_tokens" ON tokens;
DROP POLICY IF EXISTS "select_policy" ON tokens;
DROP POLICY IF EXISTS "tokens_select" ON tokens;
DROP POLICY IF EXISTS "staff_select_own_room" ON tokens;
DROP POLICY IF EXISTS "Staff see only their room tokens" ON tokens;
DROP POLICY IF EXISTS "Staff see only assigned room tokens" ON tokens;

-- Drop any other SELECT policies
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'tokens' AND cmd = 'SELECT') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON tokens';
    END LOOP;
END $$;

-- ========================================
-- STEP 2: CREATE STRICT SELECT POLICY
-- ========================================

CREATE POLICY "strict_room_visibility" ON tokens
  FOR SELECT
  USING (
    -- Admins see everything
    (EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() 
      AND role = 'admin'
    ))
    OR
    -- Customers see their own tokens
    (
      user_id = auth.uid() 
      AND EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = auth.uid() 
        AND role = 'customer'
      )
    )
    OR
    -- Staff see ONLY tokens in their assigned room
    -- Both conditions must be true:
    -- 1. User is staff
    -- 2. Staff's assigned_room_id matches token's current_room_id
    (
      EXISTS (
        SELECT 1 FROM profiles p
        WHERE p.id = auth.uid() 
        AND p.role = 'staff'
        AND p.assigned_room_id IS NOT NULL  -- Must be assigned to a room
        AND p.assigned_room_id = tokens.current_room_id  -- Room must match
      )
    )
  );

-- ========================================
-- VERIFICATION
-- ========================================

SELECT 
  '========================================' as section,
  'Current SELECT Policy' as description;

SELECT 
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'tokens' AND cmd = 'SELECT';

SELECT 
  '========================================' as section,
  'Staff Assignments' as description;

SELECT 
  p.full_name as "Staff Name",
  p.email as "Email",
  r.name as "Assigned Room",
  r.room_number as "Room #",
  CASE 
    WHEN p.assigned_room_id IS NULL THEN '❌ NOT ASSIGNED - Will see NO tokens'
    ELSE '✅ ASSIGNED - Will see only this room'
  END as "Visibility Status"
FROM profiles p
LEFT JOIN rooms r ON r.id = p.assigned_room_id
WHERE p.role = 'staff'
ORDER BY r.room_number;

SELECT 
  '========================================' as section,
  'Test Query - What ABC Sees' as description;

-- This simulates what ABC (Payment Counter staff) would see
-- Replace 'abc@example.com' with actual staff email
SELECT 
  t.token_number,
  r.name as room_name,
  t.status,
  'ABC should see this' as note
FROM tokens t
JOIN rooms r ON r.id = t.current_room_id
WHERE t.current_room_id = (
  SELECT assigned_room_id 
  FROM profiles 
  WHERE email = 'abc@example.com' 
  AND role = 'staff'
)
LIMIT 5;

SELECT '
========================================
✅ STRICT VISIBILITY APPLIED!
========================================

WHAT THIS DOES:

1. STRICT ROOM-BASED VISIBILITY ✅
   - Staff MUST be assigned to a room
   - Staff see ONLY tokens in their assigned room
   - If not assigned → See NO tokens

2. THE POLICY CHECKS:
   - Is user a staff member? ✅
   - Is staff assigned to a room? ✅
   - Does assigned_room_id = current_room_id? ✅
   - ALL must be true to see token

3. EXAMPLES:

   ABC (assigned to Payment Counter):
   ├─ Sees: Payment Counter tokens ONLY ✅
   ├─ Does NOT see: Reception tokens ❌
   ├─ Does NOT see: Photo/Biometrics tokens ❌
   └─ Does NOT see: Unassigned room tokens ❌

   Ganesh (assigned to Photo/Biometrics):
   ├─ Sees: Photo/Biometrics tokens ONLY ✅
   ├─ Does NOT see: Payment Counter tokens ❌
   ├─ Does NOT see: Reception tokens ❌
   └─ Does NOT see: Other rooms ❌

   Unassigned Staff:
   ├─ Sees: NOTHING ❌
   └─ Must be assigned to a room first

IMPORTANT:
- All staff MUST be assigned to rooms
- If staff not assigned → They see NO tokens
- Check "Staff Assignments" above

TO ASSIGN STAFF:
-- First, get staff and room IDs
SELECT id, full_name, email FROM profiles WHERE role = ''staff'';
SELECT id, name, room_number FROM rooms;

-- Then assign
UPDATE profiles 
SET assigned_room_id = ''ROOM_ID_HERE''
WHERE id = ''STAFF_ID_HERE'';

EXAMPLE:
UPDATE profiles 
SET assigned_room_id = (SELECT id FROM rooms WHERE room_number = ''R003'')
WHERE email = ''abc@example.com'';

TEST NOW:
1. Hot reload Flutter (press ''r'')
2. Login as ABC
3. Should see ONLY Payment Counter tokens ✅
4. Should NOT see other rooms ✅
5. Login as Ganesh
6. Should see ONLY Photo/Biometrics tokens ✅

========================================
' as status;
