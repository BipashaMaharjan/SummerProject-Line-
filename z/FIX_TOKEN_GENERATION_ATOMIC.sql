-- ============================================
-- 🔧 FIX: Atomic Token Generation System
-- ============================================
-- Fixes race conditions and implements proper counters
-- Separates renewal (001) from new registration (0001)
-- ============================================

-- STEP 1: Create atomic counter table
CREATE TABLE IF NOT EXISTS token_counters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    service_type TEXT NOT NULL CHECK (service_type IN ('renewal', 'new_registration')),
    current_number INTEGER DEFAULT 0 CHECK (current_number >= 0),
    last_reset_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_service_type UNIQUE(service_id, service_type)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_token_counters_service 
ON token_counters(service_id, service_type);

-- STEP 2: Add service_type column to services table
ALTER TABLE services 
ADD COLUMN IF NOT EXISTS service_type TEXT 
DEFAULT 'renewal' 
CHECK (service_type IN ('renewal', 'new_registration'));

-- STEP 3: Update existing services based on name
UPDATE services 
SET service_type = 'new_registration' 
WHERE LOWER(name) LIKE '%new%' 
   OR LOWER(name) LIKE '%registration%'
   OR LOWER(name) LIKE '%first%time%';

UPDATE services 
SET service_type = 'renewal' 
WHERE service_type IS NULL 
   OR LOWER(name) LIKE '%renew%' 
   OR LOWER(name) LIKE '%extend%';

-- STEP 4: Initialize counters for all existing services
INSERT INTO token_counters (service_id, service_type, current_number, last_reset_date)
SELECT 
    id,
    service_type,
    0,
    CURRENT_DATE
FROM services
ON CONFLICT (service_id, service_type) DO NOTHING;

-- STEP 5: Drop old function
DROP FUNCTION IF EXISTS generate_token_number(uuid);

-- STEP 6: Create new ATOMIC token generation function
CREATE OR REPLACE FUNCTION generate_token_number_atomic(
    p_service_id UUID,
    p_service_type TEXT DEFAULT 'renewal'
)
RETURNS TEXT AS $$
DECLARE
    v_next_number INTEGER;
    v_token_number TEXT;
    v_padding INTEGER;
    v_today DATE := CURRENT_DATE;
BEGIN
    -- Validate service type
    IF p_service_type NOT IN ('renewal', 'new_registration') THEN
        RAISE EXCEPTION 'Invalid service_type: %. Must be renewal or new_registration', p_service_type;
    END IF;
    
    -- Determine padding based on service type
    v_padding := CASE 
        WHEN p_service_type = 'renewal' THEN 3
        WHEN p_service_type = 'new_registration' THEN 4
        ELSE 3
    END;
    
    -- ATOMIC UPDATE with row-level lock (prevents race conditions)
    UPDATE token_counters
    SET 
        current_number = CASE
            -- Reset to 1 if it's a new day
            WHEN last_reset_date < v_today THEN 1
            -- Otherwise increment
            ELSE current_number + 1
        END,
        last_reset_date = v_today,
        updated_at = NOW()
    WHERE service_id = p_service_id
      AND service_type = p_service_type
    RETURNING current_number INTO v_next_number;
    
    -- Check if update succeeded
    IF v_next_number IS NULL THEN
        -- Counter doesn't exist, create it
        INSERT INTO token_counters (service_id, service_type, current_number, last_reset_date)
        VALUES (p_service_id, p_service_type, 1, v_today)
        ON CONFLICT (service_id, service_type) DO UPDATE
        SET current_number = token_counters.current_number + 1,
            updated_at = NOW()
        RETURNING current_number INTO v_next_number;
    END IF;
    
    -- Generate padded token number
    v_token_number := LPAD(v_next_number::TEXT, v_padding, '0');
    
    RAISE NOTICE 'Generated token: % for service % type %', v_token_number, p_service_id, p_service_type;
    
    RETURN v_token_number;
END;
$$ LANGUAGE plpgsql;

-- STEP 7: Create helper function to get service type
CREATE OR REPLACE FUNCTION get_service_type(p_service_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_service_type TEXT;
BEGIN
    SELECT service_type INTO v_service_type
    FROM services
    WHERE id = p_service_id;
    
    RETURN COALESCE(v_service_type, 'renewal');
END;
$$ LANGUAGE plpgsql STABLE;

-- STEP 8: Create backward-compatible wrapper
CREATE OR REPLACE FUNCTION generate_token_number(p_service_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_service_type TEXT;
BEGIN
    -- Get service type from services table
    v_service_type := get_service_type(p_service_id);
    
    -- Call atomic function with service type
    RETURN generate_token_number_atomic(p_service_id, v_service_type);
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check counters table
SELECT 
    s.name as service_name,
    tc.service_type,
    tc.current_number,
    tc.last_reset_date
FROM token_counters tc
JOIN services s ON tc.service_id = s.id
ORDER BY s.name, tc.service_type;

-- Test token generation (run this to verify)
-- SELECT generate_token_number_atomic('your-service-id', 'renewal');
-- Expected: 001, 002, 003...

-- SELECT generate_token_number_atomic('your-service-id', 'new_registration');
-- Expected: 0001, 0002, 0003...

-- ============================================
-- ✅ DONE! Token generation is now:
-- ✅ Atomic (no race conditions)
-- ✅ Separated by service type
-- ✅ Properly padded (001 vs 0001)
-- ✅ Concurrency-safe
-- ============================================
