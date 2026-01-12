-- ============================================
-- 🎯 MINIMAL FIX: TOKEN TRANSFER RLS
-- ============================================
-- This ONLY fixes the transfer error and changes NOTHING else.
-- ============================================

-- 1. Give staff permission to update tokens in their room
DROP POLICY IF EXISTS "staff_transfer_fix" ON tokens;
CREATE POLICY "staff_transfer_fix" ON tokens
  FOR UPDATE
  USING (
    -- Staff can update if the token IS CURRENTLY in their room
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() 
      AND role = 'staff' 
      AND assigned_room_id = tokens.current_room_id
    )
    OR 
    -- Admins can update anything
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (true); -- This is the fix! It allows the "new" room value to be saved.

-- 2. Ensure permission is granted
GRANT UPDATE ON tokens TO authenticated;
