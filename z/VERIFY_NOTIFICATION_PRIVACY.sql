-- ============================================
-- 🔒 VERIFY NOTIFICATION PRIVACY
-- ============================================
-- Run these queries to check if notifications are going to the right users
-- ============================================

-- 1. Check user_notifications table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_notifications'
ORDER BY ordinal_position;

-- 2. Check recent notifications - WHO got them?
SELECT 
  un.id,
  un.user_id,
  un.token_number,
  un.type,
  un.title,
  un.created_at,
  t.user_id as token_owner_id,
  CASE 
    WHEN un.user_id = t.user_id THEN '✅ CORRECT'
    ELSE '❌ WRONG USER!'
  END as privacy_check
FROM user_notifications un
LEFT JOIN tokens t ON t.id = un.token_id
ORDER BY un.created_at DESC
LIMIT 10;

-- 3. Check if any notifications went to wrong users
SELECT 
  COUNT(*) as wrong_notifications,
  COUNT(DISTINCT un.user_id) as affected_users
FROM user_notifications un
LEFT JOIN tokens t ON t.id = un.token_id
WHERE un.user_id != t.user_id;

-- ============================================
-- ✅ EXPECTED RESULTS:
-- ============================================
-- Query 2 should show "✅ CORRECT" for all rows
-- Query 3 should show 0 wrong_notifications
-- 
-- If you see "❌ WRONG USER!" or wrong_notifications > 0,
-- then there's a privacy issue!
-- ============================================
