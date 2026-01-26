-- ============================================
-- 🔧 QUICK FIX: Create Token Counters Table
-- ============================================
-- This is needed for the atomic token generation
-- Run this if "Book Token" button is not working
-- ============================================

-- Create the token_counters table
CREATE TABLE IF NOT EXISTS token_counters (
    service_id UUID NOT NULL,
    service_type TEXT NOT NULL,
    current_number INTEGER DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (service_id, service_type)
);

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_token_counters_service 
ON token_counters(service_id, service_type);

-- Grant permissions
GRANT ALL ON token_counters TO authenticated;

-- Enable RLS
ALTER TABLE token_counters ENABLE ROW LEVEL SECURITY;

-- Create RLS policy (allow all authenticated users to read/write)
CREATE POLICY "Allow authenticated users to manage counters"
ON token_counters
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- ============================================
-- ✅ DONE! Now try booking a token again
-- ============================================
