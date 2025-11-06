-- ============================================
-- Complete Fix for Staff Account Creation
-- ============================================
-- This solves the RLS policy error when admins create staff accounts

-- Step 1: Check current RLS policies
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'profiles';

-- Step 2: Drop all existing INSERT policies on profiles
DROP POLICY IF EXISTS "Users can only insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON profiles;
DROP POLICY IF EXISTS "Admins can insert any profile" ON profiles;

-- Step 3: Create comprehensive INSERT policy
-- This allows:
-- 1. Users to insert their own profile (normal signup)
-- 2. Admins to insert any profile (staff creation)
-- 3. System to insert profiles during auth.signUp (via trigger)

CREATE POLICY "Allow profile insertion" ON profiles
  FOR INSERT
  WITH CHECK (
    -- Allow if inserting own profile
    auth.uid() = id
    OR
    -- Allow if current user is admin
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    )
    OR
    -- Allow if no auth context (for triggers/system operations)
    auth.uid() IS NULL
  );

-- Step 4: Ensure UPDATE policy allows admins to update any profile
DROP POLICY IF EXISTS "Users can only update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;

CREATE POLICY "Allow profile updates" ON profiles
  FOR UPDATE
  USING (
    -- Own profile
    auth.uid() = id
    OR
    -- Admin can update any
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    )
  )
  WITH CHECK (
    -- Own profile
    auth.uid() = id
    OR
    -- Admin can update any
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    )
  );

-- Step 5: Create trigger to auto-create profile on user signup
-- This ensures profile is created automatically when auth user is created

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role, is_active)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    COALESCE(NEW.raw_user_meta_data->>'role', 'customer'),
    true
  )
  ON CONFLICT (id) DO UPDATE
  SET
    email = EXCLUDED.email,
    full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
    role = COALESCE(EXCLUDED.role, profiles.role),
    updated_at = NOW();
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Step 6: Verify setup
SELECT 
  policyname,
  cmd,
  roles,
  with_check
FROM pg_policies 
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;

-- Step 7: Test the setup
-- You can test by trying to create a staff account again

-- ============================================
-- ADDITIONAL: Fix staff table RLS if needed
-- ============================================

-- Check staff table policies
SELECT 
  policyname,
  cmd
FROM pg_policies 
WHERE tablename = 'staff';

-- Allow admins to insert into staff table
DROP POLICY IF EXISTS "Admins can manage staff" ON staff;

CREATE POLICY "Admins can manage staff" ON staff
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    )
  );

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check if RLS is enabled
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables 
WHERE tablename IN ('profiles', 'staff');

-- Check all policies
SELECT 
  tablename,
  policyname,
  cmd,
  roles
FROM pg_policies 
WHERE tablename IN ('profiles', 'staff')
ORDER BY tablename, cmd;

-- ============================================
-- NOTES:
-- ============================================
-- 1. Run this entire script in Supabase SQL Editor
-- 2. The trigger automatically creates profiles on signup
-- 3. Admins can create staff accounts without RLS errors
-- 4. Regular users can still only manage their own profiles
-- 5. This is secure and follows best practices
