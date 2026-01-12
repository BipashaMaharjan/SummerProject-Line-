-- ============================================
-- BACKEND FIX: Start Processing - Complete
-- ============================================
-- This fixes the "Start Processing" button by ensuring:
-- 1. Staff can UPDATE tokens (to change status to 'processing')
-- 2. Staff can INSERT into token_history (to track the action)
-- 
-- Root cause: RLS policies were blocking UPDATE on tokens table
--             and/or INSERT on token_history table
-- 
-- The startOperation() method in Dart does:
-- → UPDATE tokens SET status='processing' WHERE id=tokenId
-- → INSERT INTO token_history (tracking the action)
-- 
-- Both operations need explicit RLS permissions
-- ============================================

-- ============================================
-- STEP 1: Verify RLS is ENABLED on both tables
-- ============================================
-- This is required for policies to work
ALTER TABLE tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE token_history ENABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 2: Fix tokens table RLS for UPDATE
-- ============================================
-- Remove old/conflicting UPDATE policies
DROP POLICY IF EXISTS "tokens_update_simple" ON tokens;
DROP POLICY IF EXISTS "update_tokens" ON tokens;
DROP POLICY IF EXISTS "Staff can update tokens" ON tokens;
DROP POLICY IF EXISTS "Staff can update any token" ON tokens;
DROP POLICY IF EXISTS "Staff and users can update tokens" ON tokens;

-- Create PERMISSIVE UPDATE policy for tokens
-- Staff need to be able to update any token to change its status
CREATE POLICY "tokens_update_allow" ON tokens 
  FOR UPDATE 
  USING (
    -- Allow if user is admin
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
    OR
    -- Allow if user is staff
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role = 'staff'
    )
  ) 
  WITH CHECK (
    -- Same condition for update
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
    OR
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role = 'staff'
    )
  );

-- ============================================
-- STEP 3: Fix token_history table RLS for INSERT
-- ============================================
-- Remove old/conflicting INSERT policies
DROP POLICY IF EXISTS "token_history_insert_simple" ON token_history;
DROP POLICY IF EXISTS "token_history_insert" ON token_history;
DROP POLICY IF EXISTS "Staff can insert history" ON token_history;
DROP POLICY IF EXISTS "history_all" ON token_history;
DROP POLICY IF EXISTS "allow_all_select" ON token_history;
DROP POLICY IF EXISTS "allow_all_insert" ON token_history;
DROP POLICY IF EXISTS "allow_all_update" ON token_history;
DROP POLICY IF EXISTS "allow_all_delete" ON token_history;

-- Create PERMISSIVE INSERT policy for token_history
-- Staff need to be able to insert history entries when processing tokens
CREATE POLICY "token_history_insert_allow" ON token_history 
  FOR INSERT 
  WITH CHECK (
    -- Allow if user is admin
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
    OR
    -- Allow if user is staff
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role = 'staff'
    )
  );

-- Optional: Allow staff to view history (for audit/debugging)
CREATE POLICY "token_history_select_allow" ON token_history 
  FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND (role = 'admin' OR role = 'staff')
    )
  );

-- ============================================
-- STEP 4: Verify all policies are in place
-- ============================================
SELECT 
  tablename,
  policyname,
  cmd
FROM pg_policies 
WHERE tablename IN ('tokens', 'token_history') 
ORDER BY tablename, policyname;

-- ============================================
-- STEP 5: Diagnose current state
-- ============================================
-- This section helps you understand what might still be blocking

-- Check if RLS is enabled:
SELECT 
  schemaname, 
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables 
WHERE tablename IN ('tokens', 'token_history')
ORDER BY tablename;

-- Count records in token_history to verify it's writable:
SELECT COUNT(*) as total_history_records FROM token_history;

-- Check how many tokens exist:
SELECT 
  COUNT(*) as total_tokens,
  COUNT(CASE WHEN status = 'waiting' THEN 1 END) as waiting,
  COUNT(CASE WHEN status = 'processing' THEN 1 END) as processing,
  COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
  COUNT(CASE WHEN status = 'rejected' THEN 1 END) as rejected,
  COUNT(CASE WHEN status = 'hold' THEN 1 END) as hold
FROM tokens;

-- ============================================
-- STEP 6: Manual Test (Optional)
-- ============================================
-- Uncomment below to test if INSERT works:
/*
-- Get a test token
SELECT id, token_number, status FROM tokens LIMIT 1;

-- Try to insert a test history entry:
INSERT INTO token_history (token_id, room_id, status, action, notes, performed_by)
SELECT 
  t.id,
  r.id,
  'processing',
  'test_action',
  'Manual test of token_history INSERT',
  auth.uid()
FROM tokens t
LEFT JOIN rooms r ON r.id = (SELECT id FROM rooms LIMIT 1)
LIMIT 1;

-- Verify insert worked:
SELECT * FROM token_history ORDER BY created_at DESC LIMIT 5;
*/

-- ============================================
-- ✅ DONE! 
-- ============================================
-- Now "Start Processing" should work!
--
-- What this fix does:
-- ✓ Enables RLS on both tables (required for policies to work)
-- ✓ Creates UPDATE policy for tokens (allows status change)
-- ✓ Creates INSERT policy for token_history (allows tracking)
-- ✓ Restricts access to admin/staff only
-- 
-- If "Start Processing" STILL doesn't work:
-- 1. Check that the staff user has role = 'staff' in profiles table
-- 2. Check browser console for specific error messages
-- 3. Run the test queries above to verify permissions
-- 4. Check Supabase logs for RLS rejection messages
-- ============================================
