-- Check RLS Policies for Staff Token Visibility
-- Run this in Supabase SQL Editor

-- 1. Check if RLS is enabled on tokens table
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'tokens';

-- 2. Check all RLS policies on tokens table
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
WHERE tablename = 'tokens';

-- 3. Test: Check what tokens the current staff user can see
-- (Run this while logged in as staff in Supabase)
SELECT 
    id,
    token_number,
    status,
    current_room_id,
    user_id,
    created_at
FROM tokens
WHERE status = 'waiting'
ORDER BY created_at DESC;

-- 4. Check if there's a policy blocking staff from seeing waiting tokens
-- Look for policies that might filter by user_id or role

-- 5. SOLUTION: If RLS is blocking, you may need to update the policy
-- Example fix (uncomment if needed):
/*
-- Drop existing restrictive policy
DROP POLICY IF EXISTS "Users can only see their own tokens" ON tokens;

-- Create new policy that allows staff to see all tokens
CREATE POLICY "Staff can see all tokens" ON tokens
FOR SELECT
TO authenticated
USING (
  auth.uid() IN (
    SELECT id FROM profiles WHERE role IN ('staff', 'admin')
  )
  OR user_id = auth.uid()
);
*/
