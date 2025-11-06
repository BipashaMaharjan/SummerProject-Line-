-- Check Staff Room Assignment and Token Rooms
-- Run this in Supabase SQL Editor to diagnose the issue

-- 1. Check all rooms
SELECT 
    id,
    name,
    room_number,
    is_active
FROM rooms
ORDER BY room_number;

-- 2. Check staff assignments
SELECT 
    id,
    full_name,
    email,
    role,
    assigned_room_id,
    is_active
FROM profiles
WHERE role = 'staff';

-- 3. Check tokens and their room assignments
SELECT 
    t.id,
    t.token_number,
    t.status,
    t.current_room_id,
    r.name as room_name,
    r.room_number,
    t.user_id,
    t.created_at
FROM tokens t
LEFT JOIN rooms r ON t.current_room_id = r.id
ORDER BY t.created_at DESC
LIMIT 10;

-- 4. Check if staff's assigned room matches token's current room
SELECT 
    p.full_name as staff_name,
    p.assigned_room_id as staff_room_id,
    r1.name as staff_room_name,
    r1.room_number as staff_room_number,
    t.token_number,
    t.current_room_id as token_room_id,
    r2.name as token_room_name,
    r2.room_number as token_room_number,
    CASE 
        WHEN p.assigned_room_id = t.current_room_id THEN '✅ MATCH'
        ELSE '❌ NO MATCH'
    END as match_status
FROM profiles p
LEFT JOIN rooms r1 ON p.assigned_room_id = r1.id
CROSS JOIN tokens t
LEFT JOIN rooms r2 ON t.current_room_id = r2.id
WHERE p.role = 'staff' AND t.status = 'waiting'
ORDER BY t.created_at DESC;

-- 5. Solution: Assign staff to Reception room (R001)
-- Uncomment and run this to fix:
/*
UPDATE profiles
SET assigned_room_id = (SELECT id FROM rooms WHERE room_number = 'R001')
WHERE role = 'staff' AND email = 'YOUR_STAFF_EMAIL@work.com';
*/
