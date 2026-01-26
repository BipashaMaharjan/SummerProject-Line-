-- ========================================================
-- 🏆 MASTER STAFF MANAGEMENT SETUP (V2 - ULTRA ROBUST)
-- ========================================================
-- This script fixes:
-- 1. "Database error saving new user" (Unexpected Failure)
-- 2. "Not Assigned" Room errors
-- 3. "Permission Denied" toggle errors
-- 4. "Foreign Key Violation (23503)" errors
-- ========================================================

-- 1. Helper Function: Check for Admin Role (Prevents Infinite Loops)
CREATE OR REPLACE FUNCTION public.is_admin() 
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Robust Trigger: Create Profile Automatically on Signup
-- This handles the creation at the database level to avoid race conditions.
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger AS $$
DECLARE
  v_room_id UUID;
  v_room_str TEXT;
BEGIN
  -- Extract room ID safely from metadata
  v_room_str := new.raw_user_meta_data->>'assigned_room_id';
  
  -- Safely parse UUID - This prevents the "Database error saving new user"
  -- caused by trying to cast an empty string or null to UUID.
  IF v_room_str IS NOT NULL AND length(v_room_str) = 36 THEN
    BEGIN
      v_room_id := v_room_str::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_room_id := NULL;
    END;
  ELSE
    v_room_id := NULL;
  END IF;

  -- Insert or Update the profile
  -- We include created_at and updated_at to ensure all constraints are met.
  INSERT INTO public.profiles (
    id, 
    email, 
    full_name, 
    role, 
    assigned_room_id, 
    is_active,
    created_at,
    updated_at
  )
  VALUES (
    new.id, 
    new.email, 
    COALESCE(new.raw_user_meta_data->>'full_name', 'Unnamed Staff'), 
    COALESCE(new.raw_user_meta_data->>'role', 'staff'),
    v_room_id,
    true,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    assigned_room_id = COALESCE(v_room_id, profiles.assigned_room_id),
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    updated_at = NOW();
    
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply Trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. Security: Grant Admin Management Permissions
-- Ensure Admin can manage all profiles without recursion
DROP POLICY IF EXISTS "Admins can manage profiles" ON public.profiles;
CREATE POLICY "Admins can manage profiles" ON public.profiles 
FOR ALL TO authenticated USING (is_admin());

-- Allow regular users to see their own profile
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile" ON public.profiles
FOR SELECT TO authenticated USING (auth.uid() = id);

-- 4. Queue Logic: Restore Missing Status Functions
CREATE OR REPLACE FUNCTION calculate_queue_position(p_token_id UUID)
RETURNS INTEGER AS $$
DECLARE
    v_pos INTEGER;
    v_service_id UUID;
    v_priority INTEGER;
    v_booked_at TIMESTAMPTZ;
BEGIN
    SELECT service_id, priority, booked_at INTO v_service_id, v_priority, v_booked_at FROM tokens WHERE id = p_token_id;
    SELECT COUNT(*) + 1 INTO v_pos FROM tokens WHERE service_id = v_service_id AND status IN ('waiting', 'arrived', 'processing')
      AND (priority > v_priority OR (priority = v_priority AND booked_at < v_booked_at)) AND (booked_at::date = CURRENT_DATE);
    RETURN v_pos;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_token_queue_info(p_token_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_pos INTEGER;
    v_serving_number TEXT;
    v_service_id UUID;
BEGIN
    v_pos := calculate_queue_position(p_token_id);
    SELECT service_id INTO v_service_id FROM tokens WHERE id = p_token_id;
    SELECT current_token_number INTO v_serving_number FROM queue_status WHERE service_id = v_service_id;
    RETURN jsonb_build_object('queue_position', v_pos, 'tokens_ahead', GREATEST(0, v_pos - 1), 'current_serving_token', v_serving_number, 'estimated_wait_minutes', (GREATEST(0, v_pos - 1) * 15));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Refresh Supabase
NOTIFY pgrst, 'reload schema';
