-- ============================================
-- CREATE DIFFERENT WORKFLOWS FOR EACH SERVICE
-- ============================================

-- First, let's see what services we have
SELECT id, name, type FROM services;

-- ============================================
-- STEP 1: Clear existing workflows
-- ============================================
DELETE FROM service_workflow;

-- ============================================
-- STEP 2: Create workflow for LICENSE RENEWAL (Simpler - 3 steps)
-- ============================================
-- Assumption: License Renewal is faster, skips reception and document verification

INSERT INTO service_workflow (service_id, room_id, sequence_number)
SELECT 
  s.id,
  r.id,
  1
FROM services s
CROSS JOIN rooms r
WHERE s.name ILIKE '%renewal%'
  AND r.room_number = 'R003'; -- Start at Payment Counter

INSERT INTO service_workflow (service_id, room_id, sequence_number)
SELECT 
  s.id,
  r.id,
  2
FROM services s
CROSS JOIN rooms r
WHERE s.name ILIKE '%renewal%'
  AND r.room_number = 'R004'; -- Photo and Biometrics

INSERT INTO service_workflow (service_id, room_id, sequence_number)
SELECT 
  s.id,
  r.id,
  3
FROM services s
CROSS JOIN rooms r
WHERE s.name ILIKE '%renewal%'
  AND r.room_number = 'R005'; -- Final Processing


-- ============================================
-- STEP 3: Create workflow for NEW LICENSE (Complete - 5 steps)
-- ============================================
-- New License needs full process

INSERT INTO service_workflow (service_id, room_id, sequence_number)
SELECT 
  s.id,
  r.id,
  1
FROM services s
CROSS JOIN rooms r
WHERE s.name ILIKE '%new%'
  AND r.room_number = 'R001'; -- Reception

INSERT INTO service_workflow (service_id, room_id, sequence_number)
SELECT 
  s.id,
  r.id,
  2
FROM services s
CROSS JOIN rooms r
WHERE s.name ILIKE '%new%'
  AND r.room_number = 'R002'; -- Document Verification

INSERT INTO service_workflow (service_id, room_id, sequence_number)
SELECT 
  s.id,
  r.id,
  3
FROM services s
CROSS JOIN rooms r
WHERE s.name ILIKE '%new%'
  AND r.room_number = 'R003'; -- Payment Counter

INSERT INTO service_workflow (service_id, room_id, sequence_number)
SELECT 
  s.id,
  r.id,
  4
FROM services s
CROSS JOIN rooms r
WHERE s.name ILIKE '%new%'
  AND r.room_number = 'R004'; -- Photo and Biometrics

INSERT INTO service_workflow (service_id, room_id, sequence_number)
SELECT 
  s.id,
  r.id,
  5
FROM services s
CROSS JOIN rooms r
WHERE s.name ILIKE '%new%'
  AND r.room_number = 'R005'; -- Final Processing


-- ============================================
-- STEP 4: Verify the new workflows
-- ============================================
SELECT 
  s.name AS service,
  sw.sequence_number AS step,
  r.room_number,
  r.name AS room_name
FROM services s
JOIN service_workflow sw ON sw.service_id = s.id
JOIN rooms r ON r.id = sw.room_id
ORDER BY s.name, sw.sequence_number;


-- ============================================
-- EXPECTED RESULT:
-- ============================================
-- License Renewal:
--   Step 1: R003 - Payment Counter
--   Step 2: R004 - Photo and Biometrics
--   Step 3: R005 - Final Processing
--
-- New License Registration:
--   Step 1: R001 - Reception
--   Step 2: R002 - Document Verification
--   Step 3: R003 - Payment Counter
--   Step 4: R004 - Photo and Biometrics
--   Step 5: R005 - Final Processing
-- ============================================
