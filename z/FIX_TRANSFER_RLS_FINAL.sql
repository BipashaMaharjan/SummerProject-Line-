-- ============================================
-- 🔐 FIX TOKEN TRANSFER RLS (STRICT & SECURE)
-- ============================================
-- This script fixes the "new row violates row-level security policy"
-- error when staff members transfer tokens to other rooms.
-- ============================================

-- STEP 1: Drop existing UPDATE policies to start clean
DROP POLICY IF EXISTS "Staff can update tokens" ON tokens;
DROP POLICY IF EXISTS "Staff can manage tokens" ON tokens;
DROP POLICY IF EXISTS "Allow token updates" ON tokens;
DROP POLICY IF EXISTS "tokens_update" ON tokens;

-- STEP 2: Create a secure UPDATE policy for staff and admins
-- This policy allows staff to update a token IF they can currently see it
-- AND allows them to save the update even if the token moves to another room.
CREATE POLICY "staff_update_transfer_policy" ON tokens
  FOR UPDATE
  USING (
    -- Can update IF:
    -- 1. User is an Admin
    (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'))
    OR
    -- 2. User is Staff AND assigned to the room the token is CURRENTLY in
    (EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() 
      AND role = 'staff' 
      AND assigned_room_id = tokens.current_room_id
    ))
  )
  WITH CHECK (
    -- Allows the update to proceed regardless of the new current_room_id
    -- as long as the user is still a staff member or admin.
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('staff', 'admin'))
  );

-- STEP 3: Ensure SELECT policy is compatible
-- (Keep the strict room visibility but ensure it doesn't block the update process)
-- Note: The SELECT policy "strict_room_visibility" already exists from previous scripts.
-- We don't need to change it because the UPDATE policy above has its own USING clause.

-- STEP 4: Ensure staff can insert into token_history (essential for transfers)
DROP POLICY IF EXISTS "Staff can insert history" ON token_history;
CREATE POLICY "Staff can insert history" ON token_history
  FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('staff', 'admin'))
  );

-- STEP 5: Grant permissions just in case
GRANT UPDATE ON tokens TO authenticated;
GRANT INSERT ON token_history TO authenticated;

-- ============================================
-- ✅ RLS FIX APPLIED!
-- ============================================
-- Staff can now:
-- 1. Update tokens that are in their room.
-- 2. Transfer tokens to other rooms (even if they lose visibility after).
-- 3. Update token status (waiting -> processing -> completed).
-- ============================================
