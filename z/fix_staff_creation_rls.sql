-- ============================================
-- Fix RLS Policy for Staff Account Creation
-- ============================================
-- This fixes the "row-level security policy" error when creating staff accounts

-- Step 1: Check existing policies on profiles table
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
WHERE tablename = 'profiles';

-- Step 2: Drop restrictive INSERT policy if it exists
DROP POLICY IF EXISTS "Users can only insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

-- Step 3: Create permissive INSERT policy
-- Allow users to insert their own profile
CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Step 4: Create policy for admins to insert any profile (for staff creation)
CREATE POLICY "Admins can insert any profile" ON profiles
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    )
  );

-- Step 5: Verify policies
SELECT 
  policyname,
  cmd,
  roles
FROM pg_policies 
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;

-- ============================================
-- Alternative: If above doesn't work, use service role
-- ============================================
-- If you're creating staff from admin panel, you might need to:
-- 1. Use Supabase service_role key (bypasses RLS)
-- 2. Or temporarily disable RLS for INSERT operations

-- To check if RLS is enabled:
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'profiles';

-- ============================================
-- NOTES:
-- ============================================
-- 1. Run this script in Supabase SQL Editor
-- 2. The admin policy allows admins to create staff accounts
-- 3. Regular users can only create their own profile
-- 4. This is secure and follows best practices
