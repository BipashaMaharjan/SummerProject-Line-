-- ============================================
-- 🔥 EMERGENCY: DISABLE ALL USER NOTIFICATION TRIGGERS
-- ============================================
-- Copy this ENTIRE file
-- Paste into Supabase SQL Editor
-- Click RUN
-- ============================================

-- Drop ALL triggers related to user notifications
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT trigger_name
        FROM information_schema.triggers
        WHERE event_object_table = 'tokens'
        AND trigger_name LIKE '%user%'
    ) LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || r.trigger_name || ' ON tokens';
        RAISE NOTICE 'Dropped trigger: %', r.trigger_name;
    END LOOP;
END $$;

-- Drop the functions
DROP FUNCTION IF EXISTS notify_user_on_room_transfer() CASCADE;
DROP FUNCTION IF EXISTS notify_user_on_status_change() CASCADE;

-- Drop the table if it exists (we'll recreate it properly later)
DROP TABLE IF EXISTS user_notifications CASCADE;

-- ============================================
-- ✅ DONE!
-- ============================================
-- All user notification triggers are removed
-- "Start Processing" should work now
-- ============================================
