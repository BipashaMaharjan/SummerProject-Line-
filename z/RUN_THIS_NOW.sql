-- ============================================
-- 🚀 RUN THIS NOW - Complete Setup
-- ============================================
-- This single script sets up everything you need

-- STEP 1: Fix transfer permissions and setup system
-- (From fix_transfer_permissions_and_complete_system.sql)

-- Fix tokens UPDATE policy
DROP POLICY IF EXISTS "Staff can update tokens" ON tokens;
CREATE POLICY "Staff can update tokens" ON tokens
  FOR UPDATE
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('staff', 'admin')))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('staff', 'admin')));

-- Fix token_history INSERT policy
DROP POLICY IF EXISTS "Staff can insert history" ON token_history;
CREATE POLICY "Staff can insert history" ON token_history
  FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('staff', 'admin')));

-- Add columns
ALTER TABLE tokens ADD COLUMN IF NOT EXISTS assigned_staff_id UUID REFERENCES profiles(id);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS assigned_room_id UUID REFERENCES rooms(id);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_tokens_assigned_staff ON tokens(assigned_staff_id);
CREATE INDEX IF NOT EXISTS idx_profiles_assigned_room ON profiles(assigned_room_id);

-- Create notifications table
CREATE TABLE IF NOT EXISTS staff_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID REFERENCES profiles(id) NOT NULL,
  token_id UUID REFERENCES tokens(id) NOT NULL,
  message TEXT NOT NULL,
  type TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE staff_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff can view own notifications" ON staff_notifications;
CREATE POLICY "Staff can view own notifications" ON staff_notifications FOR SELECT USING (auth.uid() = staff_id);

DROP POLICY IF EXISTS "System can insert notifications" ON staff_notifications;
CREATE POLICY "System can insert notifications" ON staff_notifications FOR INSERT WITH CHECK (true);

-- STEP 2: Apply STRICT privacy policies
-- (From strict_privacy_policies.sql)

DROP POLICY IF EXISTS "Staff can view assigned tokens" ON tokens;
DROP POLICY IF EXISTS "Users can view own tokens" ON tokens;
DROP POLICY IF EXISTS "Allow token select" ON tokens;
DROP POLICY IF EXISTS "Strict staff token visibility" ON tokens;

CREATE POLICY "Strict staff token visibility" ON tokens
  FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    OR
    (user_id = auth.uid() AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'customer'))
    OR
    (assigned_staff_id = auth.uid() AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'))
  );

-- STEP 3: Create helper function
CREATE OR REPLACE FUNCTION get_room_staff(room_uuid UUID)
RETURNS TABLE (staff_id UUID, staff_name TEXT, staff_email TEXT) 
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.full_name, p.email
  FROM profiles p
  WHERE p.assigned_room_id = room_uuid AND p.role = 'staff'
  LIMIT 1;
END;
$$;

-- STEP 4: Create auto-assignment trigger
CREATE OR REPLACE FUNCTION assign_token_to_room_staff()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  next_room_staff UUID;
  previous_staff UUID;
BEGIN
  IF NEW.current_room_id IS DISTINCT FROM OLD.current_room_id AND NEW.status = 'waiting' THEN
    previous_staff := OLD.assigned_staff_id;
    SELECT staff_id INTO next_room_staff FROM get_room_staff(NEW.current_room_id);
    
    IF next_room_staff IS NOT NULL THEN
      NEW.assigned_staff_id := next_room_staff;
      INSERT INTO staff_notifications (staff_id, token_id, message, type)
      VALUES (next_room_staff, NEW.id, 'New ticket received — Token #' || NEW.token_number || ' has been assigned to you.', 'assigned');
      
      IF previous_staff IS NOT NULL AND previous_staff != next_room_staff THEN
        INSERT INTO staff_notifications (staff_id, token_id, message, type)
        VALUES (previous_staff, NEW.id, 'Token #' || NEW.token_number || ' has been transferred out of your queue.', 'transferred_out');
      END IF;
    ELSE
      NEW.assigned_staff_id := NULL;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_assign_token_to_room_staff ON tokens;
CREATE TRIGGER trigger_assign_token_to_room_staff
  BEFORE UPDATE ON tokens
  FOR EACH ROW
  EXECUTE FUNCTION assign_token_to_room_staff();

-- STEP 5: Auto-assign new tokens
CREATE OR REPLACE FUNCTION assign_new_token_to_service_staff()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  first_room_id UUID;
  first_room_staff UUID;
BEGIN
  SELECT room_id INTO first_room_id
  FROM service_workflow
  WHERE service_id = NEW.service_id
  ORDER BY sequence_order ASC LIMIT 1;
  
  IF first_room_id IS NOT NULL THEN
    SELECT staff_id INTO first_room_staff FROM get_room_staff(first_room_id);
    IF first_room_staff IS NOT NULL THEN
      NEW.assigned_staff_id := first_room_staff;
      INSERT INTO staff_notifications (staff_id, token_id, message, type)
      VALUES (first_room_staff, NEW.id, 'New ticket booked — Token #' || NEW.token_number || ' has been assigned to you.', 'assigned');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_assign_new_token ON tokens;
CREATE TRIGGER trigger_assign_new_token
  BEFORE INSERT ON tokens
  FOR EACH ROW
  EXECUTE FUNCTION assign_new_token_to_service_staff();

-- STEP 6: Confirm all staff emails
UPDATE auth.users
SET email_confirmed_at = NOW()
WHERE id IN (SELECT id FROM profiles WHERE role = 'staff');

-- ========================================
-- ✅ SETUP COMPLETE!
-- ========================================

SELECT '
========================================
✅ SETUP COMPLETE!
========================================

NEXT STEPS:
1. Assign staff to rooms:
   UPDATE profiles SET assigned_room_id = ''ROOM_ID'' WHERE id = ''STAFF_ID'';

2. Verify assignments:
   SELECT p.full_name, r.name 
   FROM profiles p 
   LEFT JOIN rooms r ON r.id = p.assigned_room_id 
   WHERE p.role = ''staff'';

3. Test the system!

========================================
' as status;
