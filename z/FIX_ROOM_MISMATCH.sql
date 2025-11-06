-- Find and Fix Room Mismatch Between Staff and Tokens

-- 1. Show all tokens with their room assignments
SELECT 
    token_number,
    status,
    current_room_id,
    (SELECT name FROM rooms WHERE id = current_room_id) as room_name,
    (SELECT room_number FROM rooms WHERE id = current_room_id) as room_number,
    created_at
FROM tokens
WHERE status = 'waiting'
ORDER BY created_at DESC;

-- 2. Show staff room assignments
SELECT 
    full_name,
    email,
    role,
    assigned_room_id,
    (SELECT name FROM rooms WHERE id = assigned_room_id) as assigned_room_name,
    (SELECT room_number FROM rooms WHERE id = assigned_room_id) as room_number
FROM profiles
WHERE role = 'staff';

-- 3. SOLUTION: Assign staff to the SAME room where tokens are created
-- Find the room ID where tokens are being created
SELECT DISTINCT current_room_id, 
    (SELECT name FROM rooms WHERE id = current_room_id) as room_name
FROM tokens 
WHERE status = 'waiting';

-- 4. Update staff to match token room (uncomment and run):
/*
UPDATE profiles
SET assigned_room_id = (
    SELECT DISTINCT current_room_id 
    FROM tokens 
    WHERE status = 'waiting' 
    LIMIT 1
)
WHERE role = 'staff';
*/

-- 5. Verify the fix
SELECT 
    'Staff' as type,
    full_name as name,
    assigned_room_id as room_id,
    (SELECT name FROM rooms WHERE id = assigned_room_id) as room_name
FROM profiles
WHERE role = 'staff'
UNION ALL
SELECT 
    'Token' as type,
    token_number as name,
    current_room_id as room_id,
    (SELECT name FROM rooms WHERE id = current_room_id) as room_name
FROM tokens
WHERE status = 'waiting';
