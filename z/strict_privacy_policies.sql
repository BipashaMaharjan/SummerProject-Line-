-- ============================================
-- STRICT PRIVACY - ONE TICKET, ONE STAFF
-- ============================================
-- Ensures tickets are visible ONLY to assigned staff
-- No cross-room visibility, instant removal on transfer

-- ========================================
-- PART 1: STRICT TOKEN VISIBILITY
-- ========================================

-- Remove all existing SELECT policies
DROP POLICY IF EXISTS "Staff can view assigned tokens" ON tokens;
DROP POLICY IF EXISTS "Users can view own tokens" ON tokens;
DROP POLICY IF EXISTS "Allow token select" ON tokens;

-- Create STRICT policy - Staff see ONLY their assigned tokens
CREATE POLICY "Strict staff token visibility" ON tokens
  FOR SELECT
  USING (
    -- Admin sees all (for management)
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    OR
    -- User sees ONLY their own tokens
    (user_id = auth.uid() AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'customer'))
    OR
    -- Staff sees ONLY tokens explicitly assigned to them
    (assigned_staff_id = auth.uid() AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'))
  );

-- ========================================
-- PART 2: ENSURE INSTANT REMOVAL ON TRANSFER
-- ========================================

-- Update the auto-assignment trigger to be more explicit
CREATE OR REPLACE FUNCTION assign_token_to_room_staff()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  next_room_staff UUID;
  previous_staff UUID;
BEGIN
  -- When token moves to a new room
  IF NEW.current_room_id IS DISTINCT FROM OLD.current_room_id 
     AND NEW.status = 'waiting' THEN
    
    -- Store previous staff for notification
    previous_staff := OLD.assigned_staff_id;
    
    -- Get staff assigned to the new room
    SELECT staff_id INTO next_room_staff
    FROM get_room_staff(NEW.current_room_id);
    
    -- CRITICAL: Change assigned_staff_id to new staff
    -- This instantly removes token from old staff's view
    IF next_room_staff IS NOT NULL THEN
      NEW.assigned_staff_id := next_room_staff;
      
      -- Notification for NEW staff
      INSERT INTO staff_notifications (staff_id, token_id, message, type)
      VALUES (
        next_room_staff,
        NEW.id,
        'New ticket received — Token #' || NEW.token_number || ' has been assigned to you.',
        'assigned'
      );
      
      -- Notification for PREVIOUS staff (optional - for their records)
      IF previous_staff IS NOT NULL AND previous_staff != next_room_staff THEN
        INSERT INTO staff_notifications (staff_id, token_id, message, type)
        VALUES (
          previous_staff,
          NEW.id,
          'Token #' || NEW.token_number || ' has been transferred out of your queue.',
          'transferred_out'
        );
      END IF;
    ELSE
      -- If no staff in next room, unassign (token becomes unassigned)
      NEW.assigned_staff_id := NULL;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Recreate trigger
DROP TRIGGER IF EXISTS trigger_assign_token_to_room_staff ON tokens;
CREATE TRIGGER trigger_assign_token_to_room_staff
  BEFORE UPDATE ON tokens
  FOR EACH ROW
  EXECUTE FUNCTION assign_token_to_room_staff();

-- ========================================
-- PART 3: VERIFY PRIVACY SETUP
-- ========================================

-- Check token visibility policy
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd
FROM pg_policies 
WHERE tablename = 'tokens' AND cmd = 'SELECT';

-- ========================================
-- TESTING QUERIES
-- ========================================

-- Test 1: Check which staff can see which tokens
-- (Run as different staff to verify isolation)
SELECT 
  t.token_number,
  t.status,
  r.name as current_room,
  p.full_name as assigned_to,
  t.assigned_staff_id,
  CASE 
    WHEN t.assigned_staff_id = auth.uid() THEN '✅ VISIBLE TO YOU'
    ELSE '❌ NOT VISIBLE TO YOU'
  END as visibility
FROM tokens t
LEFT JOIN rooms r ON r.id = t.current_room_id
LEFT JOIN profiles p ON p.id = t.assigned_staff_id
WHERE t.status IN ('waiting', 'processing')
ORDER BY t.created_at DESC;

-- Test 2: Verify staff assignments
SELECT 
  p.full_name as staff_name,
  r.name as assigned_room,
  COUNT(t.id) as token_count
FROM profiles p
LEFT JOIN rooms r ON r.id = p.assigned_room_id
LEFT JOIN tokens t ON t.assigned_staff_id = p.id AND t.status IN ('waiting', 'processing')
WHERE p.role = 'staff'
GROUP BY p.full_name, r.name
ORDER BY r.room_number;

SELECT '
========================================
PRIVACY RULES ENFORCED:
========================================
✅ Staff see ONLY tokens where assigned_staff_id = their ID
✅ When token transfers, assigned_staff_id changes immediately
✅ Old staff loses access instantly (RLS blocks SELECT)
✅ New staff gains access instantly (assigned_staff_id = their ID)
✅ No token can be visible to two staff at once
✅ Users see only their own tokens
✅ Admins see all (for management)

========================================
HOW IT WORKS:
========================================
1. Token assigned to Ram (assigned_staff_id = Ram ID)
   → Ram sees it, Geeta does not

2. Ram transfers to Room 2
   → Trigger fires
   → assigned_staff_id changes to Geeta ID
   → Ram can no longer see it (RLS blocks)
   → Geeta now sees it

3. Real-time update via Supabase subscriptions
   → Both dashboards refresh automatically
   → Ram: Token disappears
   → Geeta: Token appears

========================================
' as privacy_explanation;
