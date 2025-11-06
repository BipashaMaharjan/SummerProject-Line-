-- Check the current token status and workflow
-- This will show you exactly where the token is

-- 1. Check your token details
SELECT 
    t.token_number,
    t.status,
    t.current_sequence,
    r.name as current_room_name,
    r.room_number,
    t.current_room_id
FROM tokens t
LEFT JOIN rooms r ON t.current_room_id = r.id
WHERE t.token_number = 'T71156'  -- Replace with your token number
ORDER BY t.booked_at DESC
LIMIT 1;

-- 2. Check the complete workflow for this service
SELECT 
    sw.sequence_order,
    r.name as room_name,
    r.room_number,
    r.id as room_id,
    sw.estimated_duration
FROM tokens t
JOIN service_workflow sw ON sw.service_id = t.service_id
JOIN rooms r ON sw.room_id = r.id
WHERE t.token_number = 'T71156'  -- Replace with your token number
ORDER BY sw.sequence_order;

-- 3. If you need to move the token back to Room 1:
-- UPDATE tokens 
-- SET 
--   current_room_id = (
--     SELECT room_id 
--     FROM service_workflow 
--     WHERE service_id = (SELECT service_id FROM tokens WHERE token_number = 'T71156')
--     AND sequence_order = 1
--   ),
--   current_sequence = 1,
--   status = 'processing'
-- WHERE token_number = 'T71156';
