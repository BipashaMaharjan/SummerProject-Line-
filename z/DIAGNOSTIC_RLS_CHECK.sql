-- ============================================
-- 🔍 DIAGNOSTIC: Check Current RLS State
-- ============================================
-- Run this to see what's currently blocking token creation
-- ============================================

-- Check 1: What policies exist on tokens table?
SELECT 
  '========================================' as section,
  'CURRENT POLICIES ON TOKENS TABLE' as info;

SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'tokens'
ORDER BY cmd, policyname;

-- Check 2: Is RLS enabled on tokens table?
SELECT 
  '========================================' as section,
  'RLS STATUS' as info;

SELECT 
  schemaname,
  tablename,
  rowsecurity as "RLS Enabled"
FROM pg_tables
WHERE tablename = 'tokens';

-- Check 3: What triggers exist on tokens table?
SELECT 
  '========================================' as section,
  'TRIGGERS ON TOKENS TABLE' as info;

SELECT 
  trigger_name,
  event_manipulation,
  action_timing,
  action_statement
FROM information_schema.triggers
WHERE event_object_table = 'tokens'
ORDER BY trigger_name;

-- Check 4: What are the table permissions?
SELECT 
  '========================================' as section,
  'TABLE PERMISSIONS' as info;

SELECT 
  grantee,
  privilege_type
FROM information_schema.role_table_grants
WHERE table_name = 'tokens'
ORDER BY grantee, privilege_type;

-- Check 5: Test if current user can insert
SELECT 
  '========================================' as section,
  'CURRENT USER INFO' as info;

SELECT 
  auth.uid() as "Current User ID",
  auth.role() as "Current Role",
  auth.jwt() ->> 'email' as "Email";

-- ============================================
-- 📋 INSTRUCTIONS
-- ============================================
-- Run this diagnostic script in Supabase SQL Editor
-- Copy the results and share them to identify the issue
-- ============================================
