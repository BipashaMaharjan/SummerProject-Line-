-- ============================================
-- SAFE FIX - Staff Creation (Checks First)
-- ============================================

-- 1. Drop and recreate INSERT policy (safe way)
DROP POLICY IF EXISTS "Allow profile insertion" ON profiles;

CREATE POLICY "Allow profile insertion" ON profiles
  FOR INSERT
  WITH CHECK (
    auth.uid() = id
    OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    OR
    auth.uid() IS NULL
  );

-- 2. Create/Replace trigger function (safe - uses OR REPLACE)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role, is_active)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    COALESCE(NEW.raw_user_meta_data->>'role', 'customer'),
    true
  )
  ON CONFLICT (id) DO UPDATE
  SET
    email = EXCLUDED.email,
    full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
    role = COALESCE(EXCLUDED.role, profiles.role),
    updated_at = NOW();
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Drop and recreate trigger (safe way)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- 4. Fix staff table policy (safe way)
DROP POLICY IF EXISTS "Admins can manage staff" ON staff;

CREATE POLICY "Admins can manage staff" ON staff
  FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 5. Verify setup
SELECT 
  'Policies' as type,
  policyname as name,
  cmd as operation
FROM pg_policies 
WHERE tablename = 'profiles' AND policyname = 'Allow profile insertion'
UNION ALL
SELECT 
  'Trigger' as type,
  trigger_name as name,
  'AFTER INSERT' as operation
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';

-- Done! You should see 2 rows above confirming the setup.
