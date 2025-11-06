-- ============================================
-- Room-Based Staff Assignment System Setup
-- ============================================
-- This script sets up the database for room-specific staff assignments
-- Each room can have assigned staff, and tokens are auto-assigned when transferred

-- Step 1: Add assigned_staff_id to tokens table
ALTER TABLE tokens 
ADD COLUMN IF NOT EXISTS assigned_staff_id UUID REFERENCES auth.users(id);

-- Step 2: Add room_id to staff profiles (if not exists)
-- This links staff to their assigned room
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS assigned_room_id UUID REFERENCES rooms(id);

-- Step 3: Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_tokens_assigned_staff ON tokens(assigned_staff_id);
CREATE INDEX IF NOT EXISTS idx_profiles_assigned_room ON profiles(assigned_room_id);

-- Step 4: Create a function to get staff assigned to a room
CREATE OR REPLACE FUNCTION get_room_staff(room_uuid UUID)
RETURNS TABLE (
  staff_id UUID,
  staff_name TEXT,
  staff_email TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.full_name,
    u.email
  FROM profiles p
  JOIN auth.users u ON u.id = p.id
  WHERE p.assigned_room_id = room_uuid
    AND p.role = 'staff'
  LIMIT 1; -- Get first available staff for the room
END;
$$ LANGUAGE plpgsql;

-- Step 5: Create notifications table for staff notifications
CREATE TABLE IF NOT EXISTS staff_notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  staff_id UUID REFERENCES auth.users(id) NOT NULL,
  token_id UUID REFERENCES tokens(id) NOT NULL,
  message TEXT NOT NULL,
  type TEXT NOT NULL, -- 'transfer_in', 'transfer_out', 'assigned'
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for notifications
CREATE INDEX IF NOT EXISTS idx_notifications_staff ON staff_notifications(staff_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON staff_notifications(created_at DESC);

-- Step 6: Enable RLS on notifications
ALTER TABLE staff_notifications ENABLE ROW LEVEL SECURITY;

-- Policy: Staff can only see their own notifications
CREATE POLICY "Staff can view own notifications" ON staff_notifications
  FOR SELECT
  USING (auth.uid() = staff_id);

-- Policy: System can insert notifications
CREATE POLICY "System can insert notifications" ON staff_notifications
  FOR INSERT
  WITH CHECK (true);

-- Policy: Staff can update their own notifications (mark as read)
CREATE POLICY "Staff can update own notifications" ON staff_notifications
  FOR UPDATE
  USING (auth.uid() = staff_id);

-- Step 7: Create function to auto-assign token to next room's staff
CREATE OR REPLACE FUNCTION assign_token_to_room_staff()
RETURNS TRIGGER AS $$
DECLARE
  next_room_staff UUID;
  staff_name TEXT;
BEGIN
  -- Only process if current_room_id changed and status is 'waiting'
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
$$ LANGUAGE plpgsql;

-- Step 8: Create trigger for auto-assignment
DROP TRIGGER IF EXISTS trigger_assign_token_to_room_staff ON tokens;
CREATE TRIGGER trigger_assign_token_to_room_staff
  BEFORE UPDATE ON tokens
  FOR EACH ROW
  EXECUTE FUNCTION assign_token_to_room_staff();

-- Step 9: Sample data - Assign staff to rooms (EXAMPLE - adjust as needed)
-- Uncomment and modify these lines with your actual staff user IDs

-- Example: Assign staff to Room 1 (Reception)
-- UPDATE profiles 
-- SET assigned_room_id = 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79360'
-- WHERE id = 'YOUR_STAFF_USER_ID_HERE' AND role = 'staff';

-- Example: Assign staff to Room 2 (Document Verification)
-- UPDATE profiles 
-- SET assigned_room_id = 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79361'
-- WHERE id = 'YOUR_STAFF_USER_ID_HERE' AND role = 'staff';

-- Step 10: Query to check current setup
SELECT 
  r.name as room_name,
  r.room_number,
  p.full_name as assigned_staff,
  p.id as staff_id
FROM rooms r
LEFT JOIN profiles p ON p.assigned_room_id = r.id AND p.role = 'staff'
ORDER BY r.room_number;

-- ============================================
-- NOTES:
-- ============================================
-- 1. Run this script in Supabase SQL Editor
-- 2. Assign staff to rooms using UPDATE statements above
-- 3. When token is transferred, it auto-assigns to next room's staff
-- 4. Notifications are created automatically
-- 5. Staff only see tokens assigned to their room
