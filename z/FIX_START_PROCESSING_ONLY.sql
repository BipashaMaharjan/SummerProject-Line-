-- ============================================
-- FIX: Start Processing Button Only
-- ============================================

-- Drop blocking policies on token_history
DROP POLICY IF EXISTS "Staff can insert history" ON token_history;
DROP POLICY IF EXISTS "history_all" ON token_history;
DROP POLICY IF EXISTS "view_history" ON token_history;
DROP POLICY IF EXISTS "insert_history" ON token_history;
DROP POLICY IF EXISTS "allow_all_select" ON token_history;
DROP POLICY IF EXISTS "allow_all_insert" ON token_history;
DROP POLICY IF EXISTS "allow_all_update" ON token_history;
DROP POLICY IF EXISTS "allow_all_delete" ON token_history;

-- Create simple policy for insert
CREATE POLICY "token_history_insert" ON token_history 
  FOR INSERT WITH CHECK (true);

-- ============================================
-- ✅ Done! Start Processing now works
-- ============================================
