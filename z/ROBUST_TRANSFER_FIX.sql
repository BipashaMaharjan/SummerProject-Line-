-- ============================================
-- 🚀 ROBUST FIX: RESET TOKEN POLICIES
-- ============================================
-- This script safely removes ALL old/conflicting rules on the tokens table
-- and sets up clean ones that work for transfers.
-- ============================================

-- STEP 1: Remove every single existing policy on the tokens table
-- This is necessary to stop old hidden rules from blocking transfers.
DO $$ 
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN (SELECT policyname FROM pg_policies WHERE tablename = 'tokens') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || pol.policyname || '" ON tokens';
    END loop;
END $$;

-- STEP 2: Create a clean rule for CUSTOMERS
-- They can only see tokens they booked.
CREATE POLICY "customer_select" ON tokens
  FOR SELECT
  USING (auth.uid() = user_id);

-- STEP 3: Create a clean rule for STAFF & ADMINS
-- They can see ALL tokens and update ALL tokens.
-- This is the "Gold Standard" fix for transfer errors.
CREATE POLICY "staff_admin_full_access" ON tokens
  FOR ALL -- Includes SELECT, INSERT, UPDATE, DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() 
      AND role IN ('staff', 'admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() 
      AND role IN ('staff', 'admin')
    )
  );

-- STEP 4: Ensure permissions are granted
GRANT SELECT, INSERT, UPDATE, DELETE ON tokens TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tokens TO service_role;

-- ============================================
-- ✅ SYSTEM RESET COMPLETE
-- ============================================
-- Transfers will now work because staff have full permission
-- to update the "room_id" field during a transfer.
