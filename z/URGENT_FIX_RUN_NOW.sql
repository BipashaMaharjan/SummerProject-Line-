-- ============================================
-- URGENT FIX - RUN THIS NOW IN SUPABASE
-- ============================================

-- Disable ALL triggers on tokens table that are causing the issue
DROP TRIGGER IF EXISTS auto_assign_token_to_staff ON tokens CASCADE;
DROP TRIGGER IF EXISTS assign_token_to_room_staff ON tokens CASCADE;
DROP TRIGGER IF EXISTS notify_staff_on_token_creation ON tokens CASCADE;
DROP TRIGGER IF EXISTS assign_staff_on_token_insert ON tokens CASCADE;
DROP TRIGGER IF EXISTS token_assignment_trigger ON tokens CASCADE;

-- Drop the functions too
DROP FUNCTION IF EXISTS auto_assign_token_to_staff() CASCADE;
DROP FUNCTION IF EXISTS assign_token_to_room_staff() CASCADE;
DROP FUNCTION IF EXISTS notify_staff_on_token_creation() CASCADE;

-- Verify all triggers are gone
SELECT 
  trigger_name,
  event_object_table,
  action_timing,
  event_manipulation
FROM information_schema.triggers
WHERE event_object_table = 'tokens';

-- This should return 0 rows if successful
SELECT 'SUCCESS: All problematic triggers removed!' as status;
