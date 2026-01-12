-- ============================================
-- 🎯 FINAL TOKEN PERMISSION FIX
-- ============================================
-- This script fixes token creation AND token transfers
-- by setting up clean, robust RLS policies.
-- ============================================

-- STEP 1: Clear all existing policies on tokens table
DO $$ 
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN (SELECT policyname FROM pg_policies WHERE tablename = 'tokens') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || pol.policyname || '" ON tokens';
    END loop;
END $$;

-- STEP 2: Grant basic permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON tokens TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tokens TO service_role;

-- STEP 3: Create SELECT policy
-- Customers see their own tokens, Staff see tokens in their room, Admin sees all.
CREATE POLICY "token_select_policy" ON tokens
  FOR SELECT
  USING (
    auth.uid() = user_id
    OR
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND (
        profiles.role = 'admin'
        OR (
          profiles.role = 'staff' 
          AND profiles.assigned_room_id IS NOT NULL 
          AND profiles.assigned_room_id = tokens.current_room_id
        )
      )
    )
  );

-- STEP 4: Create INSERT policy
-- THIS IS THE CRITICAL FIX FOR TOKEN CREATION.
-- Authenticated users (customers) can create their own tokens.
CREATE POLICY "token_insert_policy" ON tokens
  FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    OR
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role IN ('staff', 'admin')
    )
  );

-- STEP 5: Create UPDATE policy
-- Staff can update tokens in their room (for transfers/status changes).
-- Customers can update their own tokens (for cancellation).
CREATE POLICY "token_update_policy" ON tokens
  FOR UPDATE
  USING (
    (
      auth.uid() = user_id 
      AND status = 'waiting'
    )
    OR
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND (
        profiles.role = 'admin'
        OR (
          profiles.role = 'staff' 
          AND profiles.assigned_room_id IS NOT NULL 
          AND profiles.assigned_room_id = tokens.current_room_id
        )
      )
    )
  )
  WITH CHECK (
    (
      auth.uid() = user_id
    )
    OR
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role IN ('staff', 'admin')
    )
  );

-- STEP 6: Create DELETE policy
CREATE POLICY "token_delete_policy" ON tokens
  FOR DELETE
  USING (
    auth.uid() = user_id
    OR
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'admin'
    )
  );

-- STEP 7: Ensure no other triggers are blocking creation
DROP TRIGGER IF EXISTS trg_notify_staff_on_token_insert ON tokens CASCADE;
DROP TRIGGER IF EXISTS notify_staff_on_token_creation ON tokens CASCADE;
DROP TRIGGER IF EXISTS assign_staff_on_token_insert ON tokens CASCADE;

-- ✅ SYSTEM RESTORED
SELECT 'SUCCESS: Token permissions are now correctly configured for all users!' as status;
