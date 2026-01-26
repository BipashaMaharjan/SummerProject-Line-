-- ============================================
-- 🔍 DIAGNOSTIC: Check Token Generation Setup
-- ============================================
-- Run this to see what's wrong
-- ============================================

-- CHECK 1: Does token_counters table exist?
SELECT 
    'token_counters table' as check_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'token_counters')
        THEN '✅ EXISTS'
        ELSE '❌ MISSING - Run FIX_TOKEN_GENERATION_ATOMIC.sql'
    END as status;

-- CHECK 2: Does the function exist?
SELECT 
    'generate_token_number_atomic function' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'generate_token_number_atomic'
        )
        THEN '✅ EXISTS'
        ELSE '❌ MISSING - Run FIX_TOKEN_GENERATION_ATOMIC.sql'
    END as status;

-- CHECK 3: Does the backward-compatible function exist?
SELECT 
    'generate_token_number function' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'generate_token_number'
        )
        THEN '✅ EXISTS'
        ELSE '❌ MISSING - Run FIX_TOKEN_GENERATION_ATOMIC.sql'
    END as status;

-- CHECK 4: Are there any counters initialized?
SELECT 
    'Initialized counters' as check_name,
    CASE 
        WHEN (SELECT COUNT(*) FROM token_counters) > 0
        THEN '✅ ' || (SELECT COUNT(*) FROM token_counters)::TEXT || ' counters found'
        ELSE '❌ NO COUNTERS - Run FIX_TOKEN_GENERATION_ATOMIC.sql'
    END as status;

-- CHECK 5: Do services have service_type?
SELECT 
    'Services with service_type' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'services' AND column_name = 'service_type'
        )
        THEN '✅ Column exists'
        ELSE '❌ MISSING - Run FIX_TOKEN_GENERATION_ATOMIC.sql'
    END as status;

-- CHECK 6: View actual counters (if they exist)
SELECT 
    s.name as service_name,
    tc.service_type,
    tc.current_number,
    tc.last_reset_date
FROM token_counters tc
JOIN services s ON tc.service_id = s.id
ORDER BY s.name;

-- CHECK 7: Test the function directly
-- Uncomment and replace with your actual service ID:
-- SELECT generate_token_number((SELECT id FROM services LIMIT 1));

-- ============================================
-- INTERPRETATION:
-- ============================================
-- If ANY check shows ❌, you need to run the fix
-- If ALL show ✅, the problem is elsewhere
-- ============================================
