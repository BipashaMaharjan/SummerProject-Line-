-- ============================================
-- GET CORRECT IDs FOR ASSIGNMENT
-- ============================================

-- Step 1: Get all your actual room IDs
SELECT 
  id as room_id,
  room_number,
  name as room_name,
  '-- Room ' || room_number || ': ' || name as comment
FROM rooms
ORDER BY room_number;

-- Step 2: Get all your staff IDs
SELECT 
  id as staff_id,
  full_name,
  email,
  '-- Staff: ' || full_name as comment
FROM profiles 
WHERE role = 'staff'
ORDER BY full_name;

-- Step 3: Copy the IDs from above and use this template:
-- Replace ROOM_ID and STAFF_ID with actual values from above

-- Example format (DO NOT RUN - just a template):
-- UPDATE profiles SET assigned_room_id = 'ACTUAL_ROOM_ID_FROM_STEP_1' WHERE id = 'ACTUAL_STAFF_ID_FROM_STEP_2';

SELECT '
========================================
INSTRUCTIONS:
========================================
1. Run Step 1 to see your room IDs
2. Run Step 2 to see your staff IDs
3. Copy the actual IDs
4. Use this format to assign:

   UPDATE profiles 
   SET assigned_room_id = ''paste-room-id-here'' 
   WHERE id = ''paste-staff-id-here'';

5. Run one UPDATE at a time
6. Verify with the query below

========================================
' as instructions;

-- Step 4: Verify assignments after you run the UPDATEs
SELECT 
  p.full_name as staff_name,
  p.email,
  r.room_number,
  r.name as room_name,
  p.assigned_room_id
FROM profiles p
LEFT JOIN rooms r ON r.id = p.assigned_room_id
WHERE p.role = 'staff'
ORDER BY r.room_number;
