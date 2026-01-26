-- ============================================
-- 🔧 FIX: Token Cancellation Security
-- ============================================
-- Only allow users to cancel tokens in 'waiting' status
-- Prevents cancellation of tokens being processed by staff
-- ============================================

-- Update the tokens UPDATE policy to restrict cancellation
DROP POLICY IF EXISTS "tokens_update_policy" ON tokens;
DROP POLICY IF EXISTS "strict_room_based_update" ON tokens;
DROP POLICY IF EXISTS "Staff can update tokens" ON tokens;

CREATE POLICY "tokens_update_policy" ON tokens
  FOR UPDATE
  USING (
    -- Admin can update all tokens
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
    -- Users can ONLY update their own tokens that are in 'waiting' status
    -- This prevents cancellation of tokens being processed
    (
      tokens.user_id = auth.uid()
      AND tokens.status = 'waiting'
      AND EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'customer'
      )
    )
  );

-- Verify the policy was created
SELECT 
  '✅ Policy created: ' || policyname as status,
  cmd as command
FROM pg_policies
WHERE tablename = 'tokens' AND cmd = 'UPDATE';

-- ============================================
-- ✅ DONE! Token cancellation is now secure
-- ============================================
-- Users can ONLY cancel tokens in 'waiting' status
-- Tokens in 'processing', 'hold', or other statuses
-- cannot be cancelled by users
-- ============================================
