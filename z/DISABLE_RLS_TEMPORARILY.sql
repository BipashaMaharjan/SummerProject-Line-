-- TEMPORARY FIX: Disable RLS on tokens table so staff can see all tokens
-- This is a quick fix to get it working NOW

-- 1. Check current RLS status
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'tokens';

-- 2. DISABLE RLS temporarily (uncomment to run)
ALTER TABLE tokens DISABLE ROW LEVEL SECURITY;

-- 3. Verify RLS is disabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'tokens';

-- After this, hot reload your staff app and tokens should appear!

-- NOTE: You can re-enable RLS later with proper policies:
-- ALTER TABLE tokens ENABLE ROW LEVEL SECURITY;
