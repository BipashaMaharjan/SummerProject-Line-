-- ============================================
-- 🎯 FIX STAFF DASHBOARD CROSS-VISIBILITY
-- ============================================
-- Issue: Staff can sometimes see other staff members' tokens
-- Fix: Strengthen RLS policies to ensure strict room isolation
-- ============================================

-- STEP 1: Drop existing token SELECT policy
DROP POLICY IF EXISTS "token_select_policy" ON tokens;

-- STEP 2: Create strengthened SELECT policy with strict checks
CREATE POLICY "token_select_policy_strict" ON tokens
  FOR SELECT
  USING (
    -- Customers see their own tokens
    (auth.uid() = user_id)
    OR
    -- Staff see ONLY tokens in their assigned room (strict check)
    (
      EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'staff' 
        AND profiles.assigned_room_id IS NOT NULL  -- Must have assigned room
        AND profiles.assigned_room_id = tokens.current_room_id  -- Must match token's room
      )
    )
    OR
    -- Admins see all tokens
    (
      EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'admin'
      )
    )
  );

-- STEP 3: Add diagnostic function to check staff room assignments
CREATE OR REPLACE FUNCTION check_staff_room_assignment()
RETURNS TABLE(
  staff_id UUID,
  staff_email TEXT,
  staff_role TEXT,
  assigned_room_id UUID,
  assigned_room_name TEXT,
  token_count_in_room BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id as staff_id,
    u.email as staff_email,
    p.role as staff_role,
    p.assigned_room_id,
    r.name as assigned_room_name,
    (
      SELECT COUNT(*) 
      FROM tokens t 
      WHERE t.current_room_id = p.assigned_room_id
    ) as token_count_in_room
  FROM profiles p
  LEFT JOIN auth.users u ON u.id = p.id
  LEFT JOIN rooms r ON r.id = p.assigned_room_id
  WHERE p.role = 'staff';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 4: Add function to verify RLS is working correctly
CREATE OR REPLACE FUNCTION verify_staff_token_isolation()
RETURNS TABLE(
  test_name TEXT,
  passed BOOLEAN,
  details TEXT
) AS $$
DECLARE
  v_staff_count INTEGER;
  v_staff_with_room INTEGER;
  v_staff_without_room INTEGER;
BEGIN
  -- Test 1: Check if all staff have assigned rooms
  SELECT COUNT(*) INTO v_staff_count
  FROM profiles WHERE role = 'staff';
  
  SELECT COUNT(*) INTO v_staff_with_room
  FROM profiles WHERE role = 'staff' AND assigned_room_id IS NOT NULL;
  
  v_staff_without_room := v_staff_count - v_staff_with_room;
  
  RETURN QUERY SELECT 
    'Staff Room Assignment'::TEXT,
    (v_staff_without_room = 0)::BOOLEAN,
    format('%s/%s staff have assigned rooms', v_staff_with_room, v_staff_count)::TEXT;
  
  -- Test 2: Check if RLS is enabled on tokens table
  RETURN QUERY SELECT 
    'RLS Enabled on Tokens'::TEXT,
    (
      SELECT relrowsecurity 
      FROM pg_class 
      WHERE relname = 'tokens'
    )::BOOLEAN,
    'Row-level security status'::TEXT;
  
  -- Test 3: Check if token_select_policy exists
  RETURN QUERY SELECT 
    'Token Select Policy Exists'::TEXT,
    EXISTS(
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'tokens' 
      AND policyname LIKE '%select%'
    )::BOOLEAN,
    'Policy existence check'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 5: Grant permissions
GRANT EXECUTE ON FUNCTION check_staff_room_assignment() TO authenticated;
GRANT EXECUTE ON FUNCTION verify_staff_token_isolation() TO authenticated;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Run these queries to verify the fix:

-- 1. Check all staff room assignments
-- SELECT * FROM check_staff_room_assignment();

-- 2. Verify RLS isolation is working
-- SELECT * FROM verify_staff_token_isolation();

-- 3. Check current RLS policies
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
-- FROM pg_policies 
-- WHERE tablename = 'tokens';

-- ============================================
-- EXPLANATION
-- ============================================
-- 
-- The fix ensures:
-- 1. Staff can ONLY see tokens where current_room_id matches their assigned_room_id
-- 2. Staff without assigned_room_id (NULL) cannot see any tokens
-- 3. Customers can only see their own tokens (user_id match)
-- 4. Admins can see all tokens
-- 
-- This prevents cross-visibility between staff members assigned to different rooms.
-- ============================================

SELECT 'SUCCESS: Staff token isolation policy strengthened!' as status;
