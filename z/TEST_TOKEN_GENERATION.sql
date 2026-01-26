-- ============================================
-- 🧪 TEST: Token Generation Concurrency
-- ============================================
-- Run these tests to verify the fix works
-- ============================================

-- TEST 1: Check if counters table exists
SELECT 
    'token_counters table exists' as test,
    COUNT(*) as counter_count
FROM token_counters;

-- TEST 2: Verify service types are set
SELECT 
    name,
    service_type,
    CASE 
        WHEN service_type IS NULL THEN '❌ MISSING'
        ELSE '✅ OK'
    END as status
FROM services
ORDER BY name;

-- TEST 3: Generate tokens sequentially (run multiple times)
DO $$
DECLARE
    v_service_id UUID;
    v_token TEXT;
    i INTEGER;
BEGIN
    -- Get first service ID
    SELECT id INTO v_service_id FROM services LIMIT 1;
    
    -- Generate 10 tokens
    FOR i IN 1..10 LOOP
        v_token := generate_token_number_atomic(v_service_id, 'renewal');
        RAISE NOTICE 'Token %: %', i, v_token;
    END LOOP;
END $$;

-- TEST 4: Verify no duplicates in today's tokens
SELECT 
    token_number,
    service_id,
    COUNT(*) as count,
    CASE 
        WHEN COUNT(*) > 1 THEN '❌ DUPLICATE'
        ELSE '✅ UNIQUE'
    END as status
FROM tokens
WHERE DATE(booked_at) = CURRENT_DATE
GROUP BY token_number, service_id
ORDER BY count DESC;

-- TEST 5: Verify padding is correct
SELECT 
    s.name,
    s.service_type,
    t.token_number,
    LENGTH(t.token_number) as length,
    CASE 
        WHEN s.service_type = 'renewal' AND LENGTH(t.token_number) = 3 THEN '✅ CORRECT'
        WHEN s.service_type = 'new_registration' AND LENGTH(t.token_number) = 4 THEN '✅ CORRECT'
        ELSE '❌ WRONG LENGTH'
    END as padding_status
FROM tokens t
JOIN services s ON t.service_id = s.id
WHERE DATE(t.booked_at) = CURRENT_DATE
ORDER BY t.booked_at DESC
LIMIT 20;

-- TEST 6: Simulate concurrent token generation
-- Run this in multiple database sessions simultaneously
DO $$
DECLARE
    v_service_id UUID;
    v_tokens TEXT[];
    v_token TEXT;
    i INTEGER;
BEGIN
    SELECT id INTO v_service_id FROM services WHERE service_type = 'renewal' LIMIT 1;
    
    -- Generate 50 tokens rapidly
    FOR i IN 1..50 LOOP
        v_token := generate_token_number_atomic(v_service_id, 'renewal');
        v_tokens := array_append(v_tokens, v_token);
    END LOOP;
    
    -- Check for duplicates
    IF array_length(v_tokens, 1) != array_length(array_agg(DISTINCT x), 1) 
       FROM unnest(v_tokens) x THEN
        RAISE EXCEPTION '❌ DUPLICATES FOUND!';
    ELSE
        RAISE NOTICE '✅ All 50 tokens are unique';
    END IF;
END $$;

-- TEST 7: Check counter state
SELECT 
    s.name as service_name,
    tc.service_type,
    tc.current_number as current_count,
    tc.last_reset_date,
    CASE 
        WHEN tc.last_reset_date = CURRENT_DATE THEN '✅ TODAY'
        ELSE '⚠️ OLD'
    END as reset_status
FROM token_counters tc
JOIN services s ON tc.service_id = s.id
ORDER BY s.name, tc.service_type;

-- ============================================
-- EXPECTED RESULTS:
-- ============================================
-- TEST 1: Should show counter_count > 0
-- TEST 2: All services should have service_type set
-- TEST 3: Should show 001, 002, 003... (sequential)
-- TEST 4: All tokens should be UNIQUE
-- TEST 5: Renewal=3 digits, New Registration=4 digits
-- TEST 6: Should complete without errors
-- TEST 7: All counters should show TODAY
-- ============================================
