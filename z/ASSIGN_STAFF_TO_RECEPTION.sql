-- Assign Staff to Reception Room
-- This will allow staff to see waiting tokens

-- Step 1: Check current staff assignments
SELECT 
    full_name,
    email,
    assigned_room_id,
    (SELECT name FROM rooms WHERE id = assigned_room_id) as current_room
FROM profiles
WHERE role = 'staff';

-- Step 2: Get Reception room ID
SELECT id, name, room_number 
FROM rooms 
WHERE room_number = 'R001';

-- Step 3: Assign ALL staff members to Reception room (R001)
-- This ensures they can see all waiting tokens
UPDATE profiles
SET assigned_room_id = (SELECT id FROM rooms WHERE room_number = 'R001')
WHERE role = 'staff';

-- Step 4: Verify the update
SELECT 
    full_name,
    email,
    assigned_room_id,
    (SELECT name FROM rooms WHERE id = assigned_room_id) as assigned_room,
    (SELECT room_number FROM rooms WHERE id = assigned_room_id) as room_number
FROM profiles
WHERE role = 'staff';

-- Expected result: All staff should now be assigned to "Reception" (R001)
