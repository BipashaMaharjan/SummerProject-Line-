-- ============================================
-- Quick Staff-to-Room Assignment Script
-- ============================================
-- Use this script to assign your staff to their respective rooms

-- Step 1: First, get list of all staff users
SELECT 
  id as user_id,
  full_name,
  email,
  assigned_room_id
FROM profiles 
WHERE role = 'staff'
ORDER BY full_name;

-- Step 2: Get list of all rooms
SELECT 
  id as room_id,
  name as room_name,
  room_number
FROM rooms
ORDER BY room_number;

-- Step 3: Assign staff to rooms (MODIFY WITH YOUR ACTUAL IDs)
-- Replace 'STAFF_USER_ID' with actual user_id from Step 1
-- Replace 'ROOM_ID' with actual room id from Step 2

-- Example: Assign staff to Room 1 (Reception)
-- UPDATE profiles 
-- SET assigned_room_id = 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79360'
-- WHERE id = 'YOUR_STAFF_USER_ID_HERE';

-- Room 1: Reception (d2d08402-cb3b-4cb0-ae6e-c34d9bb79360)
UPDATE profiles 
SET assigned_room_id = 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79360'
WHERE id = 'STAFF_1_USER_ID_HERE';

-- Room 2: Document Verification (d2d08402-cb3b-4cb0-ae6e-c34d9bb79361)
UPDATE profiles 
SET assigned_room_id = 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79361'
WHERE id = 'STAFF_2_USER_ID_HERE';

-- Room 3: Payment Counter (d2d08402-cb3b-4cb0-ae6e-c34d9bb79362)
UPDATE profiles 
SET assigned_room_id = 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79362'
WHERE id = 'STAFF_3_USER_ID_HERE';

-- Room 4: Photo/Biometric (d2d08402-cb3b-4cb0-ae6e-c34d9bb79363)
UPDATE profiles 
SET assigned_room_id = 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79363'
WHERE id = 'STAFF_4_USER_ID_HERE';

-- Room 5: Final Processing (d2d08402-cb3b-4cb0-ae6e-c34d9bb79364)
UPDATE profiles 
SET assigned_room_id = 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79364'
WHERE id = 'STAFF_5_USER_ID_HERE';

-- Step 4: Verify assignments
SELECT 
  r.room_number,
  r.name as room_name,
  p.full_name as assigned_staff,
  p.email as staff_email,
  p.id as staff_id
FROM rooms r
LEFT JOIN profiles p ON p.assigned_room_id = r.id AND p.role = 'staff'
ORDER BY r.room_number;

-- Step 5: Test the get_room_staff function
-- Replace with actual room ID
SELECT * FROM get_room_staff('d2d08402-cb3b-4cb0-ae6e-c34d9bb79360');

-- ============================================
-- NOTES:
-- ============================================
-- 1. Run Step 1 and Step 2 first to get the IDs
-- 2. Copy the user_id values and replace in Step 3
-- 3. Run the UPDATE statements in Step 3
-- 4. Verify with Step 4 query
-- 5. Test with Step 5 query
