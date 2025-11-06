-- Add more rooms to create a complete 5-room workflow
-- This will allow you to test the Transfer button functionality

-- First, let's check what rooms exist
-- SELECT * FROM rooms ORDER BY room_number;

-- Add additional rooms if they don't exist
INSERT INTO rooms (id, name, room_number, description, is_active, created_at)
VALUES 
  ('d2d08402-cb3b-4cb0-ae6e-c34d9bb79361', 'Document Verification', 'R002', 'Document verification counter', true, NOW()),
  ('d2d08402-cb3b-4cb0-ae6e-c34d9bb79362', 'Payment Counter', 'R003', 'Payment processing', true, NOW()),
  ('d2d08402-cb3b-4cb0-ae6e-c34d9bb79363', 'Photo/Biometric', 'R004', 'Photo and biometric capture', true, NOW()),
  ('d2d08402-cb3b-4cb0-ae6e-c34d9bb79364', 'Final Processing', 'R005', 'Final processing and dispatch', true, NOW())
ON CONFLICT (id) DO NOTHING;

-- Now add the complete workflow for License Renewal service
-- First, delete existing workflow to avoid conflicts
DELETE FROM service_workflow WHERE service_id = '02a27834-69d3-4c4b-9635-81f91130945f';

-- Add 5-step workflow for License Renewal
INSERT INTO service_workflow (service_id, room_id, sequence_order, is_required, estimated_duration, created_at)
VALUES
  -- Step 1: Reception
  ('02a27834-69d3-4c4b-9635-81f91130945f', 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79360', 1, true, 5, NOW()),
  
  -- Step 2: Document Verification
  ('02a27834-69d3-4c4b-9635-81f91130945f', 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79361', 2, true, 10, NOW()),
  
  -- Step 3: Payment Counter
  ('02a27834-69d3-4c4b-9635-81f91130945f', 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79362', 3, true, 5, NOW()),
  
  -- Step 4: Photo/Biometric
  ('02a27834-69d3-4c4b-9635-81f91130945f', 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79363', 4, true, 10, NOW()),
  
  -- Step 5: Final Processing
  ('02a27834-69d3-4c4b-9635-81f91130945f', 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79364', 5, true, 5, NOW());

-- Add workflow for New License service as well
DELETE FROM service_workflow WHERE service_id = '76251969-6be7-4135-bfca-6ab9a31df87f';

INSERT INTO service_workflow (service_id, room_id, sequence_order, is_required, estimated_duration, created_at)
VALUES
  -- Step 1: Reception
  ('76251969-6be7-4135-bfca-6ab9a31df87f', 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79360', 1, true, 5, NOW()),
  
  -- Step 2: Document Verification
  ('76251969-6be7-4135-bfca-6ab9a31df87f', 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79361', 2, true, 15, NOW()),
  
  -- Step 3: Payment Counter
  ('76251969-6be7-4135-bfca-6ab9a31df87f', 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79362', 3, true, 10, NOW()),
  
  -- Step 4: Photo/Biometric
  ('76251969-6be7-4135-bfca-6ab9a31df87f', 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79363', 4, true, 15, NOW()),
  
  -- Step 5: Final Processing
  ('76251969-6be7-4135-bfca-6ab9a31df87f', 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79364', 5, true, 10, NOW());

-- Verify the workflows
SELECT 
  s.name as service_name,
  sw.sequence_order,
  r.name as room_name,
  r.room_number,
  sw.estimated_duration
FROM service_workflow sw
JOIN services s ON sw.service_id = s.id
JOIN rooms r ON sw.room_id = r.id
ORDER BY s.name, sw.sequence_order;
