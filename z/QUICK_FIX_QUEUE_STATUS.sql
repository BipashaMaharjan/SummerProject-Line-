-- ============================================
-- ⚡ QUICK FIX: Run this if queue status is loading
-- ============================================
-- This creates the queue_status table and all triggers
-- Just copy and paste this entire file into Supabase SQL Editor
-- ============================================

-- Step 1: Create the table
CREATE TABLE IF NOT EXISTS queue_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id UUID REFERENCES services(id) ON DELETE CASCADE NOT NULL,
  room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  current_token_id UUID REFERENCES tokens(id) ON DELETE SET NULL,
  current_token_number TEXT,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(service_id)
);

-- Step 2: Create indexes
CREATE INDEX IF NOT EXISTS idx_queue_status_service_id ON queue_status(service_id);
CREATE INDEX IF NOT EXISTS idx_queue_status_room_id ON queue_status(room_id);

-- Step 3: Enable RLS
ALTER TABLE queue_status ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view queue status" ON queue_status;
CREATE POLICY "Anyone can view queue status" ON queue_status FOR SELECT USING (true);

DROP POLICY IF EXISTS "System can manage queue status" ON queue_status;
CREATE POLICY "System can manage queue status" ON queue_status FOR ALL USING (true) WITH CHECK (true);

-- Step 4: Create update trigger
CREATE OR REPLACE FUNCTION update_queue_status()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'processing' AND (OLD.status IS NULL OR OLD.status != 'processing') THEN
    INSERT INTO queue_status (service_id, room_id, current_token_id, current_token_number, started_at, updated_at)
    VALUES (NEW.service_id, NEW.current_room_id, NEW.id, NEW.token_number, NOW(), NOW())
    ON CONFLICT (service_id) 
    DO UPDATE SET
      room_id = EXCLUDED.room_id,
      current_token_id = EXCLUDED.current_token_id,
      current_token_number = EXCLUDED.current_token_number,
      started_at = EXCLUDED.started_at,
      updated_at = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_update_queue_status ON tokens;
CREATE TRIGGER trg_update_queue_status
AFTER UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION update_queue_status();

-- Step 5: Grant permissions
GRANT SELECT ON queue_status TO authenticated;
GRANT SELECT ON queue_status TO anon;

-- ============================================
-- ✅ DONE! Now hot reload your app (press 'r')
-- ============================================
-- You should see "No token currently being served"
-- instead of "Loading..."
-- ============================================
