-- ============================================
-- COMPLETE ROOM-BASED STAFF ASSIGNMENT SYSTEM
-- ============================================
-- This implements the full department-based queue system

-- ========================================
-- PART 1: FIX TRANSFER PERMISSIONS
-- ========================================

-- Fix tokens table RLS policies
DROP POLICY IF EXISTS "Staff can update tokens" ON tokens;
DROP POLICY IF EXISTS "Staff can manage tokens" ON tokens;
DROP POLICY IF EXISTS "Allow token updates" ON tokens;

-- Allow staff to update tokens (for transfers)
CREATE POLICY "Staff can update tokens" ON tokens
  FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('staff', 'admin'))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('staff', 'admin'))
  );

-- Allow staff to insert token history
DROP POLICY IF EXISTS "Staff can insert history" ON token_history;

CREATE POLICY "Staff can insert history" ON token_history
  FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('staff', 'admin'))
  );

-- ========================================
-- PART 2: SETUP ROOM-BASED ASSIGNMENTS
-- ========================================

-- Add assigned_staff_id to tokens (if not exists)
ALTER TABLE tokens 
ADD COLUMN IF NOT EXISTS assigned_staff_id UUID REFERENCES profiles(id);

-- Add assigned_room_id to profiles (if not exists)
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS assigned_room_id UUID REFERENCES rooms(id);

-- Add assigned_service_id to profiles (for service-based filtering)
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS assigned_service_id UUID REFERENCES services(id);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_tokens_assigned_staff ON tokens(assigned_staff_id);
CREATE INDEX IF NOT EXISTS idx_profiles_assigned_room ON profiles(assigned_room_id);
CREATE INDEX IF NOT EXISTS idx_profiles_assigned_service ON profiles(assigned_service_id);

-- ========================================
-- PART 3: STAFF NOTIFICATIONS TABLE
-- ========================================

CREATE TABLE IF NOT EXISTS staff_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID REFERENCES profiles(id) NOT NULL,
  token_id UUID REFERENCES tokens(id) NOT NULL,
  message TEXT NOT NULL,
  type TEXT NOT NULL, -- 'assigned', 'transferred_in', 'transferred_out'
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE staff_notifications ENABLE ROW LEVEL SECURITY;

-- Staff can see their own notifications
DROP POLICY IF EXISTS "Staff can view own notifications" ON staff_notifications;
CREATE POLICY "Staff can view own notifications" ON staff_notifications
  FOR SELECT
  USING (auth.uid() = staff_id);

-- System can insert notifications
DROP POLICY IF EXISTS "System can insert notifications" ON staff_notifications;
CREATE POLICY "System can insert notifications" ON staff_notifications
  FOR INSERT
  WITH CHECK (true);

-- Staff can update their notifications (mark as read)
DROP POLICY IF EXISTS "Staff can update own notifications" ON staff_notifications;
CREATE POLICY "Staff can update own notifications" ON staff_notifications
  FOR UPDATE
  USING (auth.uid() = staff_id);

-- ========================================
-- PART 4: FUNCTION TO GET ROOM STAFF
-- ========================================

CREATE OR REPLACE FUNCTION get_room_staff(room_uuid UUID)
RETURNS TABLE (
  staff_id UUID,
  staff_name TEXT,
  staff_email TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.full_name,
    p.email
  FROM profiles p
  WHERE p.assigned_room_id = room_uuid
    AND p.role = 'staff'
  LIMIT 1;
END;
$$;

-- ========================================
-- PART 5: AUTO-ASSIGN TOKEN TO ROOM STAFF
-- ========================================

CREATE OR REPLACE FUNCTION assign_token_to_room_staff()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  next_room_staff UUID;
BEGIN
  -- When token moves to a new room and status is 'waiting'
  IF NEW.current_room_id IS DISTINCT FROM OLD.current_room_id 
     AND NEW.status = 'waiting' THEN
    
    -- Get staff assigned to the new room
    SELECT staff_id INTO next_room_staff
    FROM get_room_staff(NEW.current_room_id);
    
    -- If staff found, assign token
    IF next_room_staff IS NOT NULL THEN
      NEW.assigned_staff_id := next_room_staff;
      
      -- Create notification for the new room's staff
      INSERT INTO staff_notifications (staff_id, token_id, message, type)
      VALUES (
        next_room_staff,
        NEW.id,
        'New ticket received — Token #' || NEW.token_number || ' has been assigned to you.',
        'assigned'
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_assign_token_to_room_staff ON tokens;
CREATE TRIGGER trigger_assign_token_to_room_staff
  BEFORE UPDATE ON tokens
  FOR EACH ROW
  EXECUTE FUNCTION assign_token_to_room_staff();

-- ========================================
-- PART 6: AUTO-ASSIGN NEW TOKENS TO SERVICE STAFF
-- ========================================

CREATE OR REPLACE FUNCTION assign_new_token_to_service_staff()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  first_room_id UUID;
  first_room_staff UUID;
BEGIN
  -- Get the first room for this service
  SELECT room_id INTO first_room_id
  FROM service_workflow
  WHERE service_id = NEW.service_id
  ORDER BY sequence_order ASC
  LIMIT 1;
  
  IF first_room_id IS NOT NULL THEN
    -- Get staff assigned to first room
    SELECT staff_id INTO first_room_staff
    FROM get_room_staff(first_room_id);
    
    -- Assign to staff if found
    IF first_room_staff IS NOT NULL THEN
      NEW.assigned_staff_id := first_room_staff;
      
      -- Create notification
      INSERT INTO staff_notifications (staff_id, token_id, message, type)
      VALUES (
        first_room_staff,
        NEW.id,
        'New ticket booked — Token #' || NEW.token_number || ' has been assigned to you.',
        'assigned'
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for new tokens
DROP TRIGGER IF EXISTS trigger_assign_new_token ON tokens;
CREATE TRIGGER trigger_assign_new_token
  BEFORE INSERT ON tokens
  FOR EACH ROW
  EXECUTE FUNCTION assign_new_token_to_service_staff();

-- ========================================
-- PART 7: UPDATE STAFF DASHBOARD RLS
-- ========================================

-- Staff can only see tokens assigned to them OR in their room
DROP POLICY IF EXISTS "Staff can view assigned tokens" ON tokens;

CREATE POLICY "Staff can view assigned tokens" ON tokens
  FOR SELECT
  USING (
    -- Admin sees all
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    OR
    -- User sees their own
    user_id = auth.uid()
    OR
    -- Staff sees tokens assigned to them
    assigned_staff_id = auth.uid()
    OR
    -- Staff sees tokens in their room
    current_room_id IN (
      SELECT assigned_room_id FROM profiles WHERE id = auth.uid() AND role = 'staff'
    )
  );

-- ========================================
-- PART 8: CONFIRM STAFF EMAILS
-- ========================================

-- Confirm all existing staff emails
UPDATE auth.users
SET email_confirmed_at = NOW()
WHERE id IN (
  SELECT id FROM profiles WHERE role = 'staff' AND email_confirmed_at IS NULL
);

-- ========================================
-- VERIFICATION QUERIES
-- ========================================

-- Check setup
SELECT 'Setup complete!' as status;

-- Show rooms
SELECT 
  id,
  name,
  room_number
FROM rooms
ORDER BY room_number;

-- Show services
SELECT 
  id,
  name
FROM services;

SELECT '
========================================
NEXT STEPS:
========================================
1. Assign staff to rooms using:
   UPDATE profiles SET assigned_room_id = ''ROOM_ID'' WHERE id = ''STAFF_ID'';

2. Optionally assign staff to services:
   UPDATE profiles SET assigned_service_id = ''SERVICE_ID'' WHERE id = ''STAFF_ID'';

3. Test by:
   - Booking a token (should auto-assign to first room staff)
   - Transferring token (should auto-assign to next room staff)
   - Check notifications in staff_notifications table

========================================
' as instructions;
