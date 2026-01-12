-- ============================================
-- Add Room Assignment to Staff Creation
-- ============================================

-- Step 1: Ensure assigned_room_id column exists in profiles
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS assigned_room_id UUID REFERENCES rooms(id) ON DELETE SET NULL;

-- Step 2: Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_profiles_assigned_room ON profiles(assigned_room_id);

-- Step 3: Update RLS policies to allow staff to see tokens only from their assigned room
-- Drop old policy if exists
DROP POLICY IF EXISTS "Staff can read all tokens" ON tokens;

-- Create new policy that respects room assignment
CREATE POLICY "Staff can read tokens from assigned room" ON tokens
  FOR SELECT
  USING (
    -- Admin can see all tokens
    auth.jwt()->>'role' = 'admin'
    OR
    -- Staff can see tokens from their assigned room
    (
      auth.jwt()->>'role' = 'staff'
      AND
      current_room_id = (
        SELECT assigned_room_id FROM profiles WHERE id = auth.uid()
      )
    )
    OR
    -- Users can see their own tokens
    auth.uid() = user_id
  );

-- Step 4: Verify the setup
SELECT 
  tablename,
  policyname,
  cmd
FROM pg_policies 
WHERE tablename = 'tokens'
ORDER BY policyname;

-- ============================================
-- NOTES:
-- ============================================
-- 1. Run this script in Supabase SQL Editor
-- 2. assigned_room_id is now required for staff
-- 3. Staff without room cannot see any tokens
-- 4. Staff can only see tokens in their assigned room
