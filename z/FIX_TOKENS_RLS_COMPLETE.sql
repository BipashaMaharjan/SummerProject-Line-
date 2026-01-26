-- ============================================
-- 🔧 COMPREHENSIVE FIX: Tokens Table RLS Policies
-- ============================================
-- This script fixes the RLS policy error:
-- "new row violates row-level security policy for table 'tokens'"
-- 
-- The fix ensures authenticated users can create tokens
-- while maintaining proper security for all user roles.
-- ============================================

-- STEP 1: Drop all existing policies on tokens table
-- This ensures we start with a clean slate
DO $$ 
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN (SELECT policyname FROM pg_policies WHERE tablename = 'tokens') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || pol.policyname || '" ON tokens';
        RAISE NOTICE 'Dropped policy: %', pol.policyname;
    END LOOP;
END $$;

SELECT '✅ Step 1: All existing policies dropped' as status;

-- ============================================
-- STEP 2: Grant necessary permissions
-- ============================================

GRANT SELECT, INSERT, UPDATE, DELETE ON tokens TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tokens TO service_role;

SELECT '✅ Step 2: Permissions granted' as status;

-- ============================================
-- STEP 3: Create SELECT policy
-- ============================================
-- Allows:
-- - Customers to see their own tokens
-- - Staff to see tokens in their assigned room
-- - Admins to see all tokens

CREATE POLICY "tokens_select_policy" ON tokens
  FOR SELECT
  USING (
    -- Admins see all tokens
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'admin'
    )
    OR
    -- Customers see their own tokens
    (
      auth.uid() = user_id
      AND EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'customer'
      )
    )
    OR
    -- Staff see tokens in their assigned room
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

SELECT '✅ Step 3: SELECT policy created' as status;

-- ============================================
-- STEP 4: Create INSERT policy (CRITICAL FIX)
-- ============================================
-- This is the key fix for the RLS error.
-- Allows:
-- - Authenticated users to insert tokens with their own user_id
-- - Staff and admins to insert any token

CREATE POLICY "tokens_insert_policy" ON tokens
  FOR INSERT
  WITH CHECK (
    -- Users can insert their own tokens
    auth.uid() = user_id
    OR
    -- Staff and admins can insert any token
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role IN ('staff', 'admin')
    )
  );

SELECT '✅ Step 4: INSERT policy created (RLS error fixed!)' as status;

-- ============================================
-- STEP 5: Create UPDATE policy
-- ============================================
-- Allows:
-- - Customers to update their own waiting tokens (for cancellation)
-- - Staff to update tokens in their assigned room
-- - Admins to update all tokens

CREATE POLICY "tokens_update_policy" ON tokens
  FOR UPDATE
  USING (
    -- Admins can update all tokens
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'admin'
    )
    OR
    -- Staff can update tokens in their assigned room
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
    -- Customers can update their own waiting tokens
    (
      auth.uid() = user_id
      AND status = 'waiting'
    )
  )
  WITH CHECK (
    -- Users can update to their own user_id
    auth.uid() = user_id
    OR
    -- Staff and admins can update to any user_id
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role IN ('staff', 'admin')
    )
  );

SELECT '✅ Step 5: UPDATE policy created' as status;

-- ============================================
-- STEP 6: Create DELETE policy
-- ============================================
-- Allows:
-- - Customers to delete their own tokens
-- - Admins to delete any token

CREATE POLICY "tokens_delete_policy" ON tokens
  FOR DELETE
  USING (
    -- Users can delete their own tokens
    auth.uid() = user_id
    OR
    -- Admins can delete any token
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'admin'
    )
  );

SELECT '✅ Step 6: DELETE policy created' as status;

-- ============================================
-- STEP 7: Verify policies are correctly created
-- ============================================

SELECT 
  '========================================' as separator,
  'TOKENS TABLE POLICIES' as info;

SELECT 
  policyname as "Policy Name",
  cmd as "Command",
  CASE 
    WHEN policyname = 'tokens_select_policy' THEN '✅ SELECT policy'
    WHEN policyname = 'tokens_insert_policy' THEN '✅ INSERT policy (RLS fix)'
    WHEN policyname = 'tokens_update_policy' THEN '✅ UPDATE policy'
    WHEN policyname = 'tokens_delete_policy' THEN '✅ DELETE policy'
    ELSE '⚠️ Unknown policy'
  END as "Description"
FROM pg_policies
WHERE tablename = 'tokens'
ORDER BY policyname;

-- ============================================
-- COMPLETION MESSAGE
-- ============================================

SELECT '
========================================
✅ TOKENS TABLE RLS POLICIES FIXED!
========================================

WHAT WAS DONE:
1. ❌ Dropped all existing conflicting policies
2. ✅ Granted permissions to authenticated users
3. ✅ Created SELECT policy (customers see own, staff see room, admin sees all)
4. ✅ Created INSERT policy (CRITICAL FIX - allows authenticated users to create tokens)
5. ✅ Created UPDATE policy (proper permissions for all roles)
6. ✅ Created DELETE policy (customers can delete own tokens)

NEXT STEPS:
1. In your Flutter app, try creating a token
2. The RLS error should be gone
3. Token creation should work successfully

TEST:
- Open Flutter app (already running)
- Log in as a customer
- Create a new token
- Expected: ✅ Token created successfully (no RLS error)

========================================
' as completion_message;
