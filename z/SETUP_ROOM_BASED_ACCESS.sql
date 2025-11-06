-- Setup Room-Based Access for Staff
-- This ensures staff only see tokens in their assigned room

-- Step 1: Re-enable RLS on tokens table
ALTER TABLE tokens ENABLE ROW LEVEL SECURITY;

-- Step 2: Drop all existing policies on tokens table
DROP POLICY IF EXISTS "Staff can see all tokens" ON tokens;
DROP POLICY IF EXISTS "Users can only see their own tokens" ON tokens;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON tokens;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON tokens;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON tokens;

-- Step 3: Create new policies for room-based access

-- Policy 1: Customers can see their own tokens
CREATE POLICY "Customers can see own tokens" ON tokens
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
);

-- Policy 2: Staff can see tokens in their assigned room
CREATE POLICY "Staff can see assigned room tokens" ON tokens
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role = 'staff'
    AND profiles.assigned_room_id = tokens.current_room_id
  )
);

-- Policy 3: Admins can see all tokens
CREATE POLICY "Admins can see all tokens" ON tokens
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role = 'admin'
  )
);

-- Policy 4: Allow authenticated users to insert tokens
CREATE POLICY "Authenticated users can create tokens" ON tokens
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Policy 5: Staff can update tokens in their room
CREATE POLICY "Staff can update assigned room tokens" ON tokens
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role IN ('staff', 'admin')
  )
);

-- Step 4: Assign staff to Reception room (R001)
-- This ensures they can see new tokens
UPDATE profiles
SET assigned_room_id = (SELECT id FROM rooms WHERE room_number = 'R001')
WHERE role = 'staff' AND assigned_room_id IS NULL;

-- Step 5: Verify setup - Staff assignments
SELECT 
    'Staff' as type,
    p.full_name as name,
    p.email,
    r.name as room_name,
    r.room_number
FROM profiles p
LEFT JOIN rooms r ON p.assigned_room_id = r.id
WHERE p.role = 'staff';

-- Step 6: Verify setup - Token rooms
SELECT 
    'Token' as type,
    t.token_number as name,
    t.status::text as email,
    r.name as room_name,
    r.room_number
FROM tokens t
LEFT JOIN rooms r ON t.current_room_id = r.id
WHERE t.status = 'waiting';

-- Expected result: Staff should be assigned to same room as waiting tokens
