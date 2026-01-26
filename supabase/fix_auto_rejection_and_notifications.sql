-- ============================================
-- �️ MASTER FIX: Linking Tokens to Profiles
-- ============================================
-- This script fixes the "PGRST200" error by ensuring a clear relationship 
-- exists between the tokens and profiles table.

-- 1. Ensure user_id column exists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tokens' AND column_name = 'user_id') THEN
        ALTER TABLE tokens ADD COLUMN user_id UUID;
    END IF;
END $$;

-- 2. Drop existing constraint if it points to auth.users (which PostgREST can't see)
ALTER TABLE tokens DROP CONSTRAINT IF EXISTS tokens_user_id_fkey;

-- 3. Add explicit foreign key to profiles table (this enables the join!)
ALTER TABLE tokens DROP CONSTRAINT IF EXISTS tokens_user_id_profiles_fkey;
ALTER TABLE tokens 
ADD CONSTRAINT tokens_user_id_profiles_fkey 
FOREIGN KEY (user_id) 
REFERENCES profiles(id) 
ON DELETE SET NULL;

-- 4. Ensure service and room relationships are also explicit for PostgREST
ALTER TABLE tokens DROP CONSTRAINT IF EXISTS tokens_service_id_fkey;
ALTER TABLE tokens 
ADD CONSTRAINT tokens_service_id_fkey 
FOREIGN KEY (service_id) 
REFERENCES services(id) 
ON DELETE CASCADE;

ALTER TABLE tokens DROP CONSTRAINT IF EXISTS tokens_current_room_id_fkey;
ALTER TABLE tokens 
ADD CONSTRAINT tokens_current_room_id_fkey 
FOREIGN KEY (current_room_id) 
REFERENCES rooms(id) 
ON DELETE SET NULL;

-- 5. Notify PostgREST to refresh its schema cache
NOTIFY pgrst, 'reload schema';

-- ============================================
-- �🚀 ENHANCED AUTO-REJECTION & NOTIFICATIONS
-- ============================================

-- Function to reject tokens from previous days that were never completed
CREATE OR REPLACE FUNCTION auto_reject_no_show_tokens()
RETURNS INTEGER AS $$
DECLARE
    v_rejected_count INTEGER;
BEGIN
    -- Reject tokens where:
    -- 1. Status is 'waiting' or 'arrived' (not completed/cancelled)
    -- 2. Scheduled date or booking date is older than today
    
    WITH rejected_tokens AS (
        UPDATE tokens
        SET 
            status = 'no_show', -- Better to use no_show for statistics
            notes = COALESCE(notes || ' | ', '') || 'System: Marked as no-show (date passed)',
            updated_at = NOW()
        WHERE status IN ('waiting', 'arrived', 'hold')
          AND (
            (scheduled_date IS NOT NULL AND scheduled_date < CURRENT_DATE)
            OR
            (scheduled_date IS NULL AND booked_at < CURRENT_DATE)
          )
        RETURNING id
    )
    SELECT COUNT(*) INTO v_rejected_count FROM rejected_tokens;
    
    RETURN v_rejected_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure notifications are fired for 'no_show' and 'rejected'
CREATE OR REPLACE FUNCTION notify_user_on_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_room_name TEXT;
  v_title TEXT;
  v_message TEXT;
BEGIN
  -- Only trigger if status actually changed
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    v_user_id := NEW.user_id;
    
    IF v_user_id IS NULL THEN
      RETURN NEW;
    END IF;
    
    -- Create appropriate message based on status
    CASE NEW.status
      WHEN 'processing' THEN
        v_title := 'Your Turn! 🎯';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'UNKNOWN') || ' is now being served.';
      WHEN 'completed' THEN
        v_title := 'Service Completed ✅';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'UNKNOWN') || ' has been completed successfully.';
      WHEN 'hold' THEN
        v_title := 'Token On Hold ⏸️';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'UNKNOWN') || ' is on hold.';
      WHEN 'rejected' THEN
        v_title := 'Token Rejected ❌';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'UNKNOWN') || ' was rejected. Reason: ' || COALESCE(NEW.notes, 'Check details');
      WHEN 'no_show' THEN
        v_title := 'Missed Turn ⚠️';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'UNKNOWN') || ' was marked as no-show because its time has passed.';
      ELSE
        v_title := 'Status Updated';
        v_message := 'Token ' || COALESCE(NEW.token_number, 'UNKNOWN') || ' status changed to ' || NEW.status;
    END CASE;
    
    -- Insert notification
    INSERT INTO user_notifications (
      user_id, token_id, token_number, type, title, message, new_status, is_read, created_at
    ) VALUES (
      v_user_id, NEW.id, NEW.token_number, 'status_change', v_title, v_message, NEW.status, FALSE, NOW()
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle queue position shifts and notify users (Proximity Alerts)
CREATE OR REPLACE FUNCTION notify_users_on_queue_shift()
RETURNS TRIGGER AS $$
DECLARE
  v_service_id UUID;
  v_target_token_id UUID;
  v_user_id UUID;
  v_token_number TEXT;
  v_room_name TEXT;
  v_count INTEGER;
BEGIN
  -- Triggered when a token starts processing, completes, or is cancelled/rejected
  -- This shift potentially moves other people up in the queue
  IF (NEW.status IN ('processing', 'completed', 'cancelled', 'rejected', 'no_show') AND 
      OLD.status IN ('waiting', 'arrived')) OR
     (NEW.status IN ('completed', 'cancelled', 'rejected', 'no_show') AND 
      OLD.status = 'processing')
  THEN
    -- Get the service ID for the shift to find the relevant queue
    SELECT service_id INTO v_service_id FROM tokens WHERE id = NEW.id;
    
    -- FIND THE PERSON WHO IS NOW AT POSITION 2 IN WAITING QUEUE
    -- (This means 1 person processing + 1 person waiting = 2 people ahead of them)
    WITH active_queue AS (
      SELECT 
        id, 
        user_id, 
        token_number,
        ROW_NUMBER() OVER (
          ORDER BY 
            priority DESC,
            booked_at ASC,
            created_at ASC
        ) as position
      FROM tokens
      WHERE service_id = v_service_id
        AND status IN ('waiting', 'arrived')
        AND (booked_at::date = CURRENT_DATE OR created_at::date = CURRENT_DATE)
    )
    SELECT id, user_id, token_number
    INTO v_target_token_id, v_user_id, v_token_number
    FROM active_queue
    WHERE position = 2; -- The user who now has 2 people currently "ahead" (1 proc + 1 wait)

    -- If someone is now at position 2, notify them
    IF v_target_token_id IS NOT NULL AND v_user_id IS NOT NULL THEN
      -- Avoid duplicate alerts for the same token today
      IF NOT EXISTS (
        SELECT 1 FROM user_notifications 
        WHERE token_id = v_target_token_id 
          AND type = 'queue_alert' 
          AND created_at::date = CURRENT_DATE
      ) THEN
        -- Get room name if available (from the trigger token's room)
        IF NEW.current_room_id IS NOT NULL THEN
            SELECT name INTO v_room_name FROM rooms WHERE id = NEW.current_room_id;
        END IF;

        INSERT INTO user_notifications (
          user_id,
          token_id,
          token_number,
          type,
          title,
          message,
          new_status,
          is_read,
          created_at
        ) VALUES (
          v_user_id,
          v_target_token_id,
          v_token_number,
          'queue_alert',
          'Get Ready! 🎯',
          'Token ' || COALESCE(v_token_number, 'N/A') || ': There are only 2 people ahead of you.',
          'waiting',
          FALSE,
          NOW()
        );
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECURITY FUNCTION: Check if user is staff or admin without recursion
-- Using SECURITY DEFINER bypasses RLS for this specific check
CREATE OR REPLACE FUNCTION check_is_staff_or_admin(user_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = user_uuid AND role IN ('staff', 'admin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- POLICY: Allow staff to read all profiles (required for dashboard joins)
DO $$
BEGIN
    DROP POLICY IF EXISTS "Staff can read all profiles" ON profiles;
    CREATE POLICY "Staff can read all profiles" ON profiles
    FOR SELECT
    TO authenticated
    USING (
      check_is_staff_or_admin(auth.uid())
      OR id = auth.uid()
    );
END $$;

-- SECURITY FUNCTION: Check user's assigned room without recursion
CREATE OR REPLACE FUNCTION get_user_assigned_room(user_uuid UUID)
RETURNS UUID AS $$
BEGIN
  RETURN (SELECT assigned_room_id FROM profiles WHERE id = user_uuid);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- FIX: Robust Token RLS Policies
-- We recreate these to be simpler and avoid selection blockers
DO $$
BEGIN
    -- Drop existing to be sure
    DROP POLICY IF EXISTS "tokens_select_policy" ON tokens;
    
    -- CREATE REFINED SELECT POLICY
    CREATE POLICY "tokens_select_policy" ON tokens
    FOR SELECT
    TO authenticated
    USING (
      -- 1. Owners always see their own tokens
      auth.uid() = user_id
      OR
      -- 2. Admins see everything
      check_is_staff_or_admin(auth.uid()) -- This function handles 'admin' role correctly
      OR
      -- 3. Staff see tokens in their assigned room
      -- We use a function to avoid recursion when checking profiles
      current_room_id = get_user_assigned_room(auth.uid())
    );
END $$;
-- This ensures that 001, 002 starts fresh for every single day
ALTER TABLE token_counters DROP CONSTRAINT IF EXISTS unique_service_type;
ALTER TABLE token_counters DROP CONSTRAINT IF EXISTS unique_service_type_date;
ALTER TABLE token_counters ADD CONSTRAINT unique_service_type_date UNIQUE(service_id, service_type, last_reset_date);

-- STEP 2: Update ATOMIC token generation function to be date-aware
CREATE OR REPLACE FUNCTION generate_token_number_atomic(
    p_service_id UUID,
    p_service_type TEXT DEFAULT 'renewal',
    p_date DATE DEFAULT CURRENT_DATE -- Added target date parameter
)
RETURNS TEXT AS $$
DECLARE
    v_next_number INTEGER;
    v_token_number TEXT;
    v_padding INTEGER;
BEGIN
    -- Validate service type
    IF p_service_type NOT IN ('renewal', 'new_registration') THEN
        RAISE EXCEPTION 'Invalid service_type: %. Must be renewal or new_registration', p_service_type;
    END IF;
    
    -- Determine padding based on service type
    v_padding := CASE 
        WHEN p_service_type = 'renewal' THEN 3
        WHEN p_service_type = 'new_registration' THEN 4
        ELSE 3
    END;
    
    -- ATOMIC UPSERT for the specific date
    INSERT INTO token_counters (service_id, service_type, last_reset_date, current_number)
    VALUES (p_service_id, p_service_type, p_date, 1)
    ON CONFLICT (service_id, service_type, last_reset_date) 
    DO UPDATE SET 
        current_number = token_counters.current_number + 1,
        updated_at = NOW()
    RETURNING current_number INTO v_next_number;
    
    -- Generate padded token number
    v_token_number := LPAD(v_next_number::TEXT, v_padding, '0');
    
    RETURN v_token_number;
END;
$$ LANGUAGE plpgsql;

-- Re-create triggers to be sure
DROP TRIGGER IF EXISTS trg_notify_user_on_status_change ON tokens;
CREATE TRIGGER trg_notify_user_on_status_change
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_user_on_status_change();

-- Proximity alert trigger
DROP TRIGGER IF EXISTS trg_notify_users_on_queue_shift ON tokens;
CREATE TRIGGER trg_notify_users_on_queue_shift
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION notify_users_on_queue_shift();

-- Robust mark_token_arrived function
CREATE OR REPLACE FUNCTION mark_token_arrived(p_token_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_row_count INTEGER;
BEGIN
    UPDATE tokens
    SET 
        status = 'arrived',
        arrived_at = NOW(),
        updated_at = NOW()
    WHERE id = p_token_id
      AND status = 'waiting'
      AND (user_id = auth.uid() OR auth.uid() IS NULL); -- Allow null auth for local testing if needed
    
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    RETURN v_row_count > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION mark_token_arrived(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION mark_token_arrived(UUID) TO anon;

-- Manual test (you can run this to clean up immediately)
-- SELECT auto_reject_no_show_tokens();
