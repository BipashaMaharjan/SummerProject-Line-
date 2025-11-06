-- ============================================
-- SETUP NEW LICENSE REGISTRATION WORKFLOW
-- ============================================
-- License Renewal: Keep existing (R001→R002→R003→R004→R005)
-- New License: Create new (R001→R002→R003→R004→R005→R006)
-- ============================================

-- STEP 1: Update R005 name to "Written Test"
-- ============================================
UPDATE rooms 
SET name = 'Written Test'
WHERE room_number = 'R005';


-- STEP 2: Create R006 - Final Processing
-- ============================================
INSERT INTO rooms (room_number, name, is_active)
VALUES ('R006', 'Final Processing', true)
ON CONFLICT (room_number) DO UPDATE 
SET name = 'Final Processing', is_active = true;


-- STEP 3: Delete only NEW LICENSE workflow (keep License Renewal)
-- ============================================
DELETE FROM service_workflow
WHERE service_id IN (
  SELECT id FROM services WHERE name ILIKE '%new%license%'
);


-- STEP 4: Create NEW LICENSE workflow (6 steps)
-- ============================================

-- Step 1: Reception
INSERT INTO service_workflow (service_id, room_id, sequence_number)
SELECT 
  s.id,
  r.id,
  1
FROM services s
CROSS JOIN rooms r
WHERE s.name ILIKE '%new%license%'
  AND r.room_number = 'R001';

-- Step 2: Document Verification
INSERT INTO service_workflow (service_id, room_id, sequence_number)
SELECT 
  s.id,
  r.id,
  2
FROM services s
CROSS JOIN rooms r
WHERE s.name ILIKE '%new%license%'
  AND r.room_number = 'R002';

-- Step 3: Payment Counter
INSERT INTO service_workflow (service_id, room_id, sequence_number)
SELECT 
  s.id,
  r.id,
  3
FROM services s
CROSS JOIN rooms r
WHERE s.name ILIKE '%new%license%'
  AND r.room_number = 'R003';

-- Step 4: Photo and Biometrics
INSERT INTO service_workflow (service_id, room_id, sequence_number)
SELECT 
  s.id,
  r.id,
  4
FROM services s
CROSS JOIN rooms r
WHERE s.name ILIKE '%new%license%'
  AND r.room_number = 'R004';

-- Step 5: Written Test
INSERT INTO service_workflow (service_id, room_id, sequence_number)
SELECT 
  s.id,
  r.id,
  5
FROM services s
CROSS JOIN rooms r
WHERE s.name ILIKE '%new%license%'
  AND r.room_number = 'R005';

-- Step 6: Final Processing
INSERT INTO service_workflow (service_id, room_id, sequence_number)
SELECT 
  s.id,
  r.id,
  6
FROM services s
CROSS JOIN rooms r
WHERE s.name ILIKE '%new%license%'
  AND r.room_number = 'R006';


-- ============================================
-- STEP 5: Verify both workflows
-- ============================================
SELECT 
  s.name AS "📋 Service",
  sw.sequence_number AS "Step",
  r.room_number AS "Room #",
  r.name AS "Room Name"
FROM services s
JOIN service_workflow sw ON sw.service_id = s.id
JOIN rooms r ON r.id = sw.room_id
ORDER BY s.name, sw.sequence_number;


-- ============================================
-- EXPECTED RESULT:
-- ============================================
-- License Renewal (5 steps):
--   Step 1: R001 - Reception
--   Step 2: R002 - Document Verification
--   Step 3: R003 - Payment Counter
--   Step 4: R004 - Photo and Biometrics
--   Step 5: R005 - Final Processing (unchanged)
--
-- New License Registration (6 steps):
--   Step 1: R001 - Reception
--   Step 2: R002 - Document Verification
--   Step 3: R003 - Payment Counter
--   Step 4: R004 - Photo and Biometrics
--   Step 5: R005 - Written Test (NEW!)
--   Step 6: R006 - Final Processing (NEW!)
-- ============================================
