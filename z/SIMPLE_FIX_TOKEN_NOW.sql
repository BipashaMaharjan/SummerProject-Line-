-- ============================================
-- 🚀 SIMPLE FIX: Token Generation (Run This!)
-- ============================================
-- This is a simplified version that will work
-- even if you ran the previous script
-- ============================================

-- STEP 1: Create counters table (safe to run multiple times)
CREATE TABLE IF NOT EXISTS token_counters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    service_type TEXT NOT NULL DEFAULT 'renewal',
    current_number INTEGER DEFAULT 0,
    last_reset_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_service_counter UNIQUE(service_id, service_type)
);

-- STEP 2: Add service_type to services (safe to run multiple times)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'services' AND column_name = 'service_type'
    ) THEN
        ALTER TABLE services ADD COLUMN service_type TEXT DEFAULT 'renewal';
    END IF;
END $$;

-- STEP 3: Initialize counters for all services
INSERT INTO token_counters (service_id, service_type, current_number)
SELECT id, 'renewal', 0 FROM services
ON CONFLICT (service_id, service_type) DO NOTHING;

-- STEP 4: Create the atomic function
CREATE OR REPLACE FUNCTION generate_token_number(service_id_param UUID)
RETURNS TEXT AS $$
DECLARE
    v_next_number INTEGER;
    v_token_number TEXT;
    v_today DATE := CURRENT_DATE;
BEGIN
    -- ATOMIC UPDATE with row-level lock
    UPDATE token_counters
    SET 
        current_number = CASE
            WHEN last_reset_date < v_today THEN 1
            ELSE current_number + 1
        END,
        last_reset_date = v_today,
        updated_at = NOW()
    WHERE service_id = service_id_param
      AND service_type = 'renewal'
    RETURNING current_number INTO v_next_number;
    
    -- If no counter exists, create it
    IF v_next_number IS NULL THEN
        INSERT INTO token_counters (service_id, service_type, current_number, last_reset_date)
        VALUES (service_id_param, 'renewal', 1, v_today)
        ON CONFLICT (service_id, service_type) DO UPDATE
        SET current_number = token_counters.current_number + 1,
            updated_at = NOW()
        RETURNING current_number INTO v_next_number;
    END IF;
    
    -- Generate padded token number (always 3 digits for now)
    v_token_number := LPAD(v_next_number::TEXT, 3, '0');
    
    RETURN v_token_number;
END;
$$ LANGUAGE plpgsql;

-- STEP 5: Grant execute permission
GRANT EXECUTE ON FUNCTION generate_token_number(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_token_number(UUID) TO anon;

-- ============================================
-- VERIFY IT WORKED
-- ============================================

-- Test the function
SELECT 
    'Test Result' as test,
    generate_token_number((SELECT id FROM services LIMIT 1)) as token_number;
-- Expected: Should return '001' or next number

-- Check counters
SELECT 
    s.name,
    tc.current_number,
    tc.last_reset_date
FROM token_counters tc
JOIN services s ON tc.service_id = s.id;

-- ============================================
-- ✅ DONE! Now hot restart your app
-- ============================================
