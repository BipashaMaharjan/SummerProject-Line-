-- Simple fix: Just update the workflow and move token to Room 1
-- (Rooms already exist, so we skip creating them)

-- Step 1: Check what rooms exist
SELECT id, name, room_number FROM rooms ORDER BY room_number;

-- Step 2: Delete existing workflow for License Renewal service
DELETE FROM service_workflow 
WHERE service_id = '02a27834-69d3-4c4b-9635-81f91130945f';

-- Step 3: Create complete 5-room workflow using existing rooms
-- First, let's get the room IDs
-- Reception: d2d08402-cb3b-4cb0-ae6e-c34d9bb79360
-- Document Verification: d2d08402-cb3b-4cb0-ae6e-c34d9bb79361
-- Payment Counter: Get from rooms table
-- Photo/Biometric: Get from rooms table
-- Final Processing: c79b39e9-69f8-4fc6-b28d-f6a00ef65596

-- Insert workflow using room_number to find IDs dynamically
INSERT INTO service_workflow (service_id, room_id, sequence_order, is_required, estimated_duration, created_at)
SELECT 
  '02a27834-69d3-4c4b-9635-81f91130945f',
  r.id,
  CASE r.room_number
    WHEN 'R001' THEN 1
    WHEN 'R002' THEN 2
    WHEN 'R003' THEN 3
    WHEN 'R004' THEN 4
    WHEN 'R005' THEN 5
  END,
  true,
  15,
  NOW()
FROM rooms r
WHERE r.room_number IN ('R001', 'R002', 'R003', 'R004', 'R005')
  AND r.is_active = true;

-- Step 4: Move token T71156 to Room 1 (Reception)
UPDATE tokens 
SET 
  current_room_id = (SELECT id FROM rooms WHERE room_number = 'R001'),
  current_sequence = 1,
  status = 'processing'
WHERE token_number = 'T71156';

-- Step 5: Verify the workflow (should show 5 rooms)
SELECT 
    sw.sequence_order,
    r.name as room_name,
    r.room_number,
    r.id as room_id
FROM service_workflow sw
JOIN rooms r ON sw.room_id = r.id
WHERE sw.service_id = '02a27834-69d3-4c4b-9635-81f91130945f'
ORDER BY sw.sequence_order;

-- Step 6: Verify token is in Room 1
SELECT 
    t.token_number,
    t.status,
    t.current_sequence,
    r.name as current_room_name,
    r.room_number
FROM tokens t
LEFT JOIN rooms r ON t.current_room_id = r.id
WHERE t.token_number = 'T71156';
