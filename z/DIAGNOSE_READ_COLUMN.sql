-- ============================================
-- 🔍 DIAGNOSE THE "READ" COLUMN ERROR
-- ============================================
-- This will help us find where the "read" column is coming from
-- Run this in Supabase SQL Editor
-- ============================================

-- Check the actual columns in user_notifications table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'user_notifications'
ORDER BY ordinal_position;

-- Check if there's a column called 'read' anywhere
SELECT table_name, column_name
FROM information_schema.columns
WHERE column_name = 'read'
AND table_schema = 'public';

-- Check all views that might have a 'read' column
SELECT table_name, view_definition
FROM information_schema.views
WHERE table_schema = 'public'
AND view_definition LIKE '%read%';

-- List all columns in user_notifications
\d user_notifications;
