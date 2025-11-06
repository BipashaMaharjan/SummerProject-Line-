-- ============================================
-- 🔍 CHECK STAFF ASSIGNMENTS
-- ============================================

-- Check which staff are assigned to which rooms
SELECT 
  p.full_name as "Staff Name",
  p.email as "Email",
  p.assigned_room_id as "Room ID",
  r.name as "Assigned Room",
  r.room_number as "Room Number",
  CASE 
    WHEN p.assigned_room_id IS NULL THEN '❌ NOT ASSIGNED'
    ELSE '✅ ASSIGNED'
  END as "Status"
FROM profiles p
LEFT JOIN rooms r ON r.id = p.assigned_room_id
WHERE p.role = 'staff'
ORDER BY r.room_number;

-- Check current RLS policy
SELECT 
  '========================================' as section,
  'Current SELECT Policy' as description;

SELECT 
  policyname,
  qual as using_clause
FROM pg_policies
WHERE tablename = 'tokens' AND cmd = 'SELECT';

-- Check sample tokens and their rooms
SELECT 
  '========================================' as section,
  'Sample Tokens' as description;

SELECT 
  t.token_number,
  r.name as current_room,
  r.room_number,
  t.status,
  t.assigned_staff_id
FROM tokens t
LEFT JOIN rooms r ON r.id = t.current_room_id
ORDER BY t.created_at DESC
LIMIT 10;

SELECT '
========================================
🔍 DIAGNOSIS
========================================

CHECK THE RESULTS ABOVE:

1. STAFF ASSIGNMENTS:
   - Are all staff assigned to rooms?
   - If "NOT ASSIGNED" → Staff will see ALL tokens
   - Each staff should have a room_number

2. RLS POLICY:
   - Should check: assigned_room_id = current_room_id
   - If missing this check → Staff see all tokens

3. SAMPLE TOKENS:
   - Which rooms do tokens belong to?
   - Are they distributed across rooms?

SEND ME THE OUTPUT!

========================================
' as instructions;
