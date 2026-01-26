-- ============================================
-- Add 'cancelled' to token_status enum
-- ============================================
-- This allows users to cancel their tokens
-- Distinct from 'rejected' (staff action)
-- ============================================

-- Check if 'cancelled' already exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_enum e
        JOIN pg_type t ON e.enumtypid = t.oid
        WHERE t.typname = 'token_status'
        AND e.enumlabel = 'cancelled'
    ) THEN
        -- Add 'cancelled' to the enum
        ALTER TYPE token_status ADD VALUE 'cancelled';
        RAISE NOTICE '✅ Added cancelled to token_status enum';
    ELSE
        RAISE NOTICE 'ℹ️  cancelled already exists in token_status enum';
    END IF;
END$$;

-- Verify the enum values
SELECT 
    '✅ Current token_status values:' as status,
    e.enumlabel AS value
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid  
WHERE t.typname = 'token_status'
ORDER BY e.enumsortorder;

-- ============================================
-- ✅ DONE! Now you can use 'cancelled' status
-- ============================================
