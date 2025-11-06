-- FIX: Add missing rooms and complete the workflow
-- Your current workflow: Reception → Document Verification → Final Processing (only 3 rooms)
-- We need: Reception → Document Verification → Payment → Photo/Biometric → Final Processing (5 rooms)

-- Step 1: Add missing rooms (Payment and Photo/Biometric)
INSERT INTO rooms (id, name, room_number, description, is_active, created_at)
VALUES 
  ('d2d08402-cb3b-4cb0-ae6e-c34d9bb79362', 'Payment Counter', 'R003', 'Payment processing', true, NOW()),
  ('d2d08402-cb3b-4cb0-ae6e-c34d9bb79363', 'Photo/Biometric', 'R004', 'Photo and biometric capture', true, NOW())
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  room_number = EXCLUDED.room_number,
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active;

-- Step 2: Get the service ID from your token
-- (We'll use the License Renewal service ID: 02a27834-69d3-4c4b-9635-81f91130945f)

-- Step 3: Delete existing workflow and recreate with 5 rooms
DELETE FROM service_workflow 
WHERE service_id = '02a27834-69d3-4c4b-9635-81f91130945f';

-- Step 4: Create complete 5-room workflow
INSERT INTO service_workflow (service_id, room_id, sequence_order, is_required, estimated_duration, created_at)
VALUES
  -- Room 1: Reception
  ('02a27834-69d3-4c4b-9635-81f91130945f', 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79360', 1, true, 15, NOW()),
  
  -- Room 2: Document Verification
  ('02a27834-69d3-4c4b-9635-81f91130945f', 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79361', 2, true, 15, NOW()),
  
  -- Room 3: Payment Counter (NEW)
  ('02a27834-69d3-4c4b-9635-81f91130945f', 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79362', 3, true, 15, NOW()),
  
  -- Room 4: Photo/Biometric (NEW)
  ('02a27834-69d3-4c4b-9635-81f91130945f', 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79363', 4, true, 15, NOW()),
  
  -- Room 5: Final Processing
  ('02a27834-69d3-4c4b-9635-81f91130945f', 'c79b39e9-69f8-4fc6-b28d-f6a00ef65596', 5, true, 15, NOW());

-- Step 5: Move your current token back to Room 1 so you can test Transfer
UPDATE tokens 
SET 
  current_room_id = 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79360',  -- Reception
  current_sequence = 1,
  status = 'processing'
WHERE token_number = 'T71156';

-- Step 6: Verify the workflow
SELECT 
    sw.sequence_order,
    r.name as room_name,
    r.room_number,
    r.id as room_id,
    sw.estimated_duration
FROM service_workflow sw
JOIN rooms r ON sw.room_id = r.id
WHERE sw.service_id = '02a27834-69d3-4c4b-9635-81f91130945f'
ORDER BY sw.sequence_order;

-- Step 7: Verify your token is now in Room 1
SELECT 
    t.token_number,
    t.status,
    t.current_sequence,
    r.name as current_room_name,
    r.room_number
FROM tokens t
LEFT JOIN rooms r ON t.current_room_id = r.id
WHERE t.token_number = 'T71156';
