-- FIX TOKEN STATUS ENUM
-- Add 'no_show' value to token_status enum typo
-- This is required to support token cancellation by users

-- We wrap in a block to handle cases where the value might already exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_type t 
        JOIN pg_enum e ON t.oid = e.enumtypid 
        WHERE t.typname = 'token_status' 
        AND e.enumlabel = 'no_show'
    ) THEN
        ALTER TYPE token_status ADD VALUE 'no_show';
    END IF;
END
$$;

-- Verify the change
SELECT 
    t.typname AS enum_name, 
    e.enumlabel AS enum_value
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid 
WHERE t.typname = 'token_status'
ORDER BY e.enumsortorder;
