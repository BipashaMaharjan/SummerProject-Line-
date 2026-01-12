-- ============================================
-- 🔍 DIAGNOSE RLS POLICIES
-- ============================================
-- Run this to see what policies are currently active on the tokens table.
-- This will help us find why the transfer is still being blocked.
-- ============================================

SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd, 
    qual as using_expression, 
    with_check as check_expression
FROM pg_policies 
WHERE tablename = 'tokens';

-- Also check current staff assignment
-- Replace with the email of the staff member trying to do the transfer
SELECT id, full_name, role, assigned_room_id 
FROM profiles 
WHERE role = 'staff';
