-- ============================================
-- 🔒 FIX WAITING TOKENS VISIBILITY
-- ============================================
-- Staff should ONLY see tokens in their assigned room
-- Unassigned/waiting tokens should NOT be visible
-- ============================================

-- ========================================
-- STEP 1: DROP EXISTING SELECT POLICY
-- ========================================

DROP POLICY IF EXISTS "strict_room_visibility" ON tokens;
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
-- STEP 2: CREATE STRICT ROOM-ONLY POLICY
-- ========================================

CREATE POLICY "only_assigned_room_tokens" ON tokens
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
    -- Staff see ONLY tokens that meet ALL conditions:
    -- 1. Token has a current_room_id (not unassigned)
    -- 2. Staff is assigned to that specific room
    -- 3. Token's current_room_id matches staff's assigned_room_id
    (
      tokens.current_room_id IS NOT NULL  -- Token must be in a room
      AND EXISTS (
        SELECT 1 FROM profiles p
        WHERE p.id = auth.uid() 
        AND p.role = 'staff'
        AND p.assigned_room_id IS NOT NULL  -- Staff must be assigned
        AND p.assigned_room_id = tokens.current_room_id  -- Rooms must match
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
  'Token Distribution by Room' as description;

SELECT 
  COALESCE(r.name, 'UNASSIGNED/WAITING') as room_name,
  COALESCE(r.room_number, 'N/A') as room_number,
  COUNT(t.id) as token_count,
  STRING_AGG(t.status::text, ', ') as statuses
FROM tokens t
LEFT JOIN rooms r ON r.id = t.current_room_id
WHERE t.created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY r.name, r.room_number
ORDER BY r.room_number;

SELECT 
  '========================================' as section,
  'Staff Assignments' as description;

SELECT 
  p.full_name as "Staff Name",
  p.email as "Email",
  r.name as "Assigned Room",
  r.room_number as "Room #",
  (
    SELECT COUNT(*) 
    FROM tokens t 
    WHERE t.current_room_id = p.assigned_room_id
  ) as "Tokens in Room"
FROM profiles p
LEFT JOIN rooms r ON r.id = p.assigned_room_id
WHERE p.role = 'staff'
ORDER BY r.room_number;

SELECT 
  '========================================' as section,
  'Unassigned Tokens (No Staff Should See These)' as description;

SELECT 
  t.token_number,
  t.status,
  t.created_at,
  'Should NOT be visible to staff' as note
FROM tokens t
WHERE t.current_room_id IS NULL
ORDER BY t.created_at DESC
LIMIT 10;

SELECT '
========================================
✅ WAITING TOKENS VISIBILITY FIXED!
========================================

WHAT THIS DOES:

1. STRICT ROOM-BASED VISIBILITY ✅
   - Staff see ONLY tokens in their assigned room
   - Tokens WITHOUT current_room_id are HIDDEN
   - Unassigned/waiting tokens are NOT visible

2. THE POLICY CHECKS:
   ✅ Token has current_room_id (not NULL)
   ✅ Staff is assigned to a room
   ✅ Staff''s room = Token''s room
   ❌ If ANY condition fails → Token NOT visible

3. EXAMPLES:

   Token States:
   ├─ Token in Reception (R001)
   │  └─ Visible to: Reception staff ONLY ✅
   ├─ Token in Payment (R003)
   │  └─ Visible to: Payment staff ONLY ✅
   ├─ Token with current_room_id = NULL
   │  └─ Visible to: NO STAFF ❌ (Admin only)
   └─ Waiting token (no room assigned)
      └─ Visible to: NO STAFF ❌ (Admin only)

4. STAFF VISIBILITY:

   ABC (Payment Counter Staff):
   ├─ Sees: Tokens where current_room_id = Payment ✅
   ├─ Does NOT see: Reception tokens ❌
   ├─ Does NOT see: Photo/Biometrics tokens ❌
   ├─ Does NOT see: Unassigned tokens ❌
   └─ Does NOT see: Waiting tokens ❌

   Ganesh (Photo/Biometrics Staff):
   ├─ Sees: Tokens where current_room_id = Photo/Bio ✅
   ├─ Does NOT see: Payment tokens ❌
   ├─ Does NOT see: Reception tokens ❌
   ├─ Does NOT see: Unassigned tokens ❌
   └─ Does NOT see: Waiting tokens ❌

   Admin:
   ├─ Sees: ALL tokens ✅
   └─ Including unassigned/waiting ✅

5. WORKFLOW:

   When token is booked:
   ├─ current_room_id = NULL (or first room)
   ├─ If NULL → No staff sees it
   └─ If assigned to Room 1 → Room 1 staff sees it

   When token is transferred:
   ├─ current_room_id changes from Room 1 to Room 2
   ├─ Room 1 staff can no longer see it ✅
   └─ Room 2 staff can now see it ✅

IMPORTANT:
- Tokens MUST have current_room_id to be visible
- Staff MUST be assigned to rooms
- Only matching room tokens are visible

CHECK THE VERIFICATION ABOVE:
- "Token Distribution by Room" shows where tokens are
- "Unassigned Tokens" shows tokens NO staff should see
- "Staff Assignments" shows what each staff can see

TEST NOW:
1. Hot reload Flutter (press ''r'')
2. Login as ABC (Payment Counter)
3. Should see ONLY Payment Counter tokens ✅
4. Should NOT see unassigned/waiting tokens ✅
5. Should NOT see other rooms'' tokens ✅

IF STAFF SEE NO TOKENS:
- Check if tokens have current_room_id set
- Check if staff are assigned to rooms
- Run the verification queries above

========================================
' as status;
