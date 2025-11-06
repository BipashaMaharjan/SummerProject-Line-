-- ============================================
-- Check Staff Table Setup
-- ============================================

-- 1. Check if staff table exists
SELECT 
  table_name,
  table_type
FROM information_schema.tables
WHERE table_name = 'staff';

-- 2. Check staff table structure
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'staff'
ORDER BY ordinal_position;

-- 3. Check staff table RLS policies
SELECT 
  policyname,
  cmd,
  roles
FROM pg_policies 
WHERE tablename = 'staff';

-- 4. Check if RLS is enabled
SELECT 
  tablename,
  rowsecurity
FROM pg_tables 
WHERE tablename = 'staff';

-- 5. If staff table doesn't exist or has issues, create it properly
CREATE TABLE IF NOT EXISTS staff (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Enable RLS
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;

-- 7. Create admin policy for staff table
DROP POLICY IF EXISTS "Admins can manage staff" ON staff;

CREATE POLICY "Admins can manage staff" ON staff
  FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 8. Verify final setup
SELECT 'Setup complete!' as status;
