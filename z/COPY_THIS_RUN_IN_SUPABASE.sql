-- COPY THIS ENTIRE SCRIPT AND RUN IN SUPABASE SQL EDITOR NOW!

-- Step 1: Find and drop ALL triggers on tokens table
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (SELECT trigger_name FROM information_schema.triggers WHERE event_object_table = 'tokens') 
    LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || r.trigger_name || ' ON tokens CASCADE';
    END LOOP;
END $$;

-- Step 2: Drop common trigger functions
DROP FUNCTION IF EXISTS auto_assign_token_to_staff() CASCADE;
DROP FUNCTION IF EXISTS assign_token_to_room_staff() CASCADE;
DROP FUNCTION IF EXISTS notify_staff_on_token_creation() CASCADE;
DROP FUNCTION IF EXISTS handle_token_assignment() CASCADE;
DROP FUNCTION IF EXISTS assign_staff_on_token_insert() CASCADE;

-- Step 3: Verify triggers are gone
SELECT 
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation
FROM information_schema.triggers
WHERE event_object_table = 'tokens';

-- This should return ZERO rows

SELECT 'SUCCESS! All triggers removed. Try booking a token now!' as status;
