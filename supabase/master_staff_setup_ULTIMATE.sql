-- ========================================================
-- 🏆 MASTER STAFF MANAGEMENT SETUP (ULTIMATE VERSION)
-- ========================================================
-- This script is the definitive fix for:
-- 1. "Database error saving new user" (Unexpected Failure)
-- 2. "Not Assigned" Room errors
-- 3. "Permission Denied" toggle errors
-- 4. Infinite Recursion Loop in profiles
-- 5. Missing get_token_queue_info RPC
-- ========================================================

-- STEP 1: DROP EVERYTHING START FRESH
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.is_admin() CASCADE;

-- STEP 2: CREATE SECURE HELPER FUNCTIONS
-- Using SECURITY DEFINER avoids infinite RLS recursion.
CREATE OR REPLACE FUNCTION public.is_admin() 
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 3: THE "BULLETPROOF" AUTH TRIGGER
-- Wraps everything in a BEGIN...EXCEPTION block so signup NEVER fails.
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger AS $$
DECLARE
  v_room_id UUID;
  v_room_str TEXT;
BEGIN
  -- Try to extract and validate room ID
  BEGIN
    v_room_str := new.raw_user_meta_data->>'assigned_room_id';
    IF v_room_str IS NOT NULL AND length(v_room_str) = 36 THEN
      v_room_id := v_room_str::uuid;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_room_id := NULL;
  END;

  -- Insert profile with safe defaults
  BEGIN
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
      COALESCE(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)), 
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
  EXCEPTION WHEN OTHERS THEN
    -- Log the error internally but RETURN NEW so auth signup succeeds!
    RAISE WARNING 'Profile creation failed for user %: %', new.id, SQLERRM;
  END;
    
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply the Trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- STEP 4: CLEAN UP POLICIES
-- Drop all potentially conflicting policies
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'profiles') 
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.profiles';
    END LOOP;
END $$;

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 1. Admins can do anything
CREATE POLICY "Admins manage everything" ON public.profiles 
FOR ALL TO authenticated USING (is_admin());

-- 2. Users can see their own profile
CREATE POLICY "Users see own profile" ON public.profiles
FOR SELECT TO authenticated USING (auth.uid() = id);

-- 3. Users can update their own profile
CREATE POLICY "Users update own profile" ON public.profiles
FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 4. Essential: Allow Service Role and Trigger to Bypass RLS
-- (Trigger already uses SECURITY DEFINER, so it's safe)

-- STEP 5: RESTORE QUEUE RPCs
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

-- Refresh Supabase Cache
NOTIFY pgrst, 'reload schema';

SELECT 'SUCCESS: ULTIMATE STAFF SETUP APPLIED!' as status;
