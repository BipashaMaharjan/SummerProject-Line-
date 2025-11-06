-- ============================================
-- SIMPLE STAFF ASSIGNMENT
-- ============================================

-- Step 1: Get all staff
SELECT 
  id as staff_id,
  full_name,
  email
FROM profiles 
WHERE role = 'staff'
ORDER BY full_name;

-- Step 2: Get all rooms
SELECT 
  id as room_id,
  name,
  room_number
FROM rooms
ORDER BY room_number;

-- Step 3: Get all services
SELECT 
  id as service_id,
  name
FROM services;

-- ========================================
-- ASSIGN STAFF TO ROOMS
-- ========================================
-- Copy staff IDs from Step 1 and paste below

-- Example: Staff Ram -> Room 1 (Reception)
-- UPDATE profiles SET assigned_room_id = 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79360' WHERE id = 'STAFF_RAM_ID';

-- Example: Staff Geeta -> Room 2 (Document Verification)
-- UPDATE profiles SET assigned_room_id = 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79361' WHERE id = 'STAFF_GEETA_ID';

-- ========================================
-- VERIFY ASSIGNMENTS
-- ========================================

SELECT 
  r.room_number,
  r.name as room_name,
  p.full_name as assigned_staff,
  p.email
FROM rooms r
LEFT JOIN profiles p ON p.assigned_room_id = r.id AND p.role = 'staff'
ORDER BY r.room_number;
