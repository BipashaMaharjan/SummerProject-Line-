-- Digital Queue Management System Database Schema
-- Run this SQL in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create custom types
CREATE TYPE user_role AS ENUM ('customer', 'staff', 'admin');
CREATE TYPE token_status AS ENUM ('waiting', 'hold', 'processing', 'completed', 'rejected');
CREATE TYPE service_type AS ENUM ('license_renewal', 'new_license');

-- 1. Profiles table (extends Supabase auth.users)
CREATE TABLE profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    full_name TEXT,
    phone TEXT UNIQUE,
    role user_role DEFAULT 'customer',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Services table
CREATE TABLE services (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    type service_type NOT NULL,
    description TEXT,
    estimated_time_minutes INTEGER DEFAULT 30,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Rooms table
CREATE TABLE rooms (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    room_number TEXT UNIQUE NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Staff assignments table (which staff works in which room)
CREATE TABLE staff_rooms (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    staff_id UUID REFERENCES profiles(id),
    room_id UUID REFERENCES rooms(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(staff_id, room_id)
);

-- 5. Service workflow (which rooms a service goes through)
CREATE TABLE service_workflow (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    service_id UUID REFERENCES services(id),
    room_id UUID REFERENCES rooms(id),
    sequence_order INTEGER NOT NULL,
    is_required BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(service_id, room_id),
    UNIQUE(service_id, sequence_order)
);

-- 6. Tokens table (main token management)
CREATE TABLE tokens (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    token_number INTEGER NOT NULL,
    user_id UUID REFERENCES profiles(id),
    service_id UUID REFERENCES services(id),
    status token_status DEFAULT 'waiting',
    current_room_id UUID REFERENCES rooms(id),
    current_sequence INTEGER DEFAULT 1,
    priority INTEGER DEFAULT 0, -- Higher number = higher priority
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE
);

-- 7. Token history (track token movement through rooms)
CREATE TABLE token_history (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    token_id UUID REFERENCES tokens(id),
    room_id UUID REFERENCES rooms(id),
    staff_id UUID REFERENCES profiles(id),
    status token_status NOT NULL,
    sequence_number INTEGER NOT NULL,
    action TEXT, -- 'picked', 'transferred', 'completed', 'rejected', 'hold'
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. Holiday calendar (for blocking bookings)
CREATE TABLE holidays (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    date DATE NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 9. System settings
CREATE TABLE system_settings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    key TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_profiles_phone ON profiles(phone);
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_tokens_user_id ON tokens(user_id);
CREATE INDEX idx_tokens_service_id ON tokens(service_id);
CREATE INDEX idx_tokens_status ON tokens(status);
CREATE INDEX idx_tokens_created_at ON tokens(created_at);
CREATE INDEX idx_tokens_current_room ON tokens(current_room_id);
CREATE INDEX idx_token_history_token_id ON token_history(token_id);
CREATE INDEX idx_token_history_created_at ON token_history(created_at);

-- Create immutable function for date extraction
CREATE OR REPLACE FUNCTION extract_date_immutable(timestamp with time zone)
RETURNS date AS $$
BEGIN
    RETURN $1::date;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create unique index for daily token numbers
CREATE UNIQUE INDEX idx_unique_daily_token ON tokens (token_number, extract_date_immutable(created_at));

-- Create functions for automatic token numbering
CREATE OR REPLACE FUNCTION get_next_token_number()
RETURNS INTEGER AS $$
DECLARE
    next_num INTEGER;
BEGIN
    SELECT COALESCE(MAX(token_number), 0) + 1 
    INTO next_num 
    FROM tokens 
    WHERE extract_date_immutable(created_at) = CURRENT_DATE;
    
    RETURN next_num;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-assign token numbers
CREATE OR REPLACE FUNCTION assign_token_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.token_number IS NULL THEN
        NEW.token_number := get_next_token_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_assign_token_number
    BEFORE INSERT ON tokens
    FOR EACH ROW
    EXECUTE FUNCTION assign_token_number();

-- Trigger to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_tokens_updated_at
    BEFORE UPDATE ON tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert default data
INSERT INTO services (name, type, description, estimated_time_minutes) VALUES
('License Renewal', 'license_renewal', 'Renew existing driving license', 30),
('New License Application', 'new_license', 'Apply for new driving license', 45);

INSERT INTO rooms (name, room_number, description) VALUES
('Reception', 'R001', 'Initial document verification and form submission'),
('Document Verification', 'R002', 'Detailed document checking and validation'),
('Payment Counter', 'R003', 'Fee payment and receipt generation'),
('Photo & Biometric', 'R004', 'Photo capture and biometric data collection'),
('Final Processing', 'R005', 'License printing and final approval');

-- Set up service workflows
INSERT INTO service_workflow (service_id, room_id, sequence_order) VALUES
-- License Renewal workflow
((SELECT id FROM services WHERE type = 'license_renewal'), (SELECT id FROM rooms WHERE room_number = 'R001'), 1),
((SELECT id FROM services WHERE type = 'license_renewal'), (SELECT id FROM rooms WHERE room_number = 'R002'), 2),
((SELECT id FROM services WHERE type = 'license_renewal'), (SELECT id FROM rooms WHERE room_number = 'R003'), 3),
((SELECT id FROM services WHERE type = 'license_renewal'), (SELECT id FROM rooms WHERE room_number = 'R005'), 4),

-- New License workflow
((SELECT id FROM services WHERE type = 'new_license'), (SELECT id FROM rooms WHERE room_number = 'R001'), 1),
((SELECT id FROM services WHERE type = 'new_license'), (SELECT id FROM rooms WHERE room_number = 'R002'), 2),
((SELECT id FROM services WHERE type = 'new_license'), (SELECT id FROM rooms WHERE room_number = 'R003'), 3),
((SELECT id FROM services WHERE type = 'new_license'), (SELECT id FROM rooms WHERE room_number = 'R004'), 4),
((SELECT id FROM services WHERE type = 'new_license'), (SELECT id FROM rooms WHERE room_number = 'R005'), 5);

-- Insert system settings
INSERT INTO system_settings (key, value, description) VALUES
('max_tokens_per_day', '100', 'Maximum tokens that can be booked per day'),
('booking_start_time', '09:00', 'Daily booking start time'),
('booking_end_time', '16:00', 'Daily booking end time'),
('advance_booking_days', '7', 'How many days in advance can users book');

-- Row Level Security (RLS) Policies

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_workflow ENABLE ROW LEVEL SECURITY;
ALTER TABLE tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE token_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE holidays ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view their own profile" ON profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Staff can view all profiles" ON profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role IN ('staff', 'admin')
        )
    );

-- Services policies (public read)
CREATE POLICY "Anyone can view active services" ON services
    FOR SELECT USING (is_active = true);

-- Rooms policies (public read)
CREATE POLICY "Anyone can view active rooms" ON rooms
    FOR SELECT USING (is_active = true);

-- Tokens policies
CREATE POLICY "Users can view their own tokens" ON tokens
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own tokens" ON tokens
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Staff can view all tokens" ON tokens
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role IN ('staff', 'admin')
        )
    );

CREATE POLICY "Staff can update tokens" ON tokens
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role IN ('staff', 'admin')
        )
    );

-- Token history policies
CREATE POLICY "Users can view their token history" ON token_history
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM tokens 
            WHERE id = token_history.token_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Staff can view all token history" ON token_history
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role IN ('staff', 'admin')
        )
    );

CREATE POLICY "Staff can create token history" ON token_history
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role IN ('staff', 'admin')
        )
    );

-- Admin-only policies
CREATE POLICY "Admin can manage staff rooms" ON staff_rooms
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admin can manage holidays" ON holidays
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admin can manage system settings" ON system_settings
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Create a function to handle new user registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, phone, role)
    VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name', NEW.phone, 'customer');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user registration
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Views for easier querying

-- Current queue view
CREATE VIEW current_queue AS
SELECT 
    t.id,
    t.token_number,
    t.status,
    t.current_sequence,
    t.created_at,
    p.full_name as user_name,
    p.phone as user_phone,
    s.name as service_name,
    s.type as service_type,
    r.name as current_room_name,
    r.room_number as current_room_number,
    -- Generate dash notation (token_number-sequence)
    CONCAT(t.token_number, '-', t.current_sequence) as display_token
FROM tokens t
JOIN profiles p ON t.user_id = p.id
JOIN services s ON t.service_id = s.id
LEFT JOIN rooms r ON t.current_room_id = r.id
WHERE extract_date_immutable(t.created_at) = CURRENT_DATE
ORDER BY t.created_at;

-- Token statistics view
CREATE VIEW token_stats AS
SELECT 
    extract_date_immutable(created_at) as date,
    COUNT(*) as total_tokens,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_tokens,
    COUNT(CASE WHEN status = 'waiting' THEN 1 END) as waiting_tokens,
    COUNT(CASE WHEN status = 'processing' THEN 1 END) as processing_tokens,
    COUNT(CASE WHEN status = 'rejected' THEN 1 END) as rejected_tokens
FROM tokens
GROUP BY extract_date_immutable(created_at)
ORDER BY date DESC;

-- Add default workflows for any services that don't have one
DO $$
DECLARE
    service_record RECORD;
    reception_room_id UUID;
BEGIN
    -- Get the reception room (R001)
    SELECT id INTO reception_room_id 
    FROM rooms 
    WHERE room_number = 'R001' 
    LIMIT 1;
    
    IF reception_room_id IS NULL THEN
        RAISE NOTICE 'Reception room (R001) not found. Cannot create default workflows.';
        RETURN;
    END IF;
    
    -- For each service without a workflow, create a default one
    FOR service_record IN 
        SELECT id, name 
        FROM services s
        WHERE NOT EXISTS (
            SELECT 1 
            FROM service_workflow sw 
            WHERE sw.service_id = s.id
        )
        AND s.is_active = true
    LOOP
        INSERT INTO service_workflow (service_id, room_id, sequence_order, is_required)
        VALUES (service_record.id, reception_room_id, 1, true);
        
        RAISE NOTICE 'Created default workflow for service: % (ID: %)', 
            service_record.name, service_record.id;
    END LOOP;
    
    RAISE NOTICE 'Default workflow creation completed.';
END $$;

-- Verify the workflows were created
SELECT 
    s.id as service_id,
    s.name as service_name,
    sw.sequence_order,
    r.name as room_name,
    r.room_number
FROM services s
LEFT JOIN service_workflow sw ON s.id = sw.service_id
LEFT JOIN rooms r ON sw.room_id = r.id
ORDER BY s.name, sw.sequence_order;
