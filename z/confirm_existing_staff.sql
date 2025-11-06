-- ============================================
-- Confirm Existing Staff Emails
-- ============================================

-- First, create the confirmation function if not exists
CREATE OR REPLACE FUNCTION confirm_user_email(user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE auth.users
  SET email_confirmed_at = NOW()
  WHERE id = user_id;
END;
$$;

-- Get all unconfirmed staff accounts
SELECT 
  u.id,
  u.email,
  u.email_confirmed_at,
  p.full_name
FROM auth.users u
JOIN profiles p ON p.id = u.id
WHERE p.role = 'staff'
  AND u.email_confirmed_at IS NULL;

-- Confirm ALL staff emails automatically
UPDATE auth.users
SET email_confirmed_at = NOW()
WHERE id IN (
  SELECT u.id 
  FROM auth.users u
  JOIN profiles p ON p.id = u.id
  WHERE p.role = 'staff'
    AND u.email_confirmed_at IS NULL
);

-- Verify all staff are now confirmed
SELECT 
  u.email,
  u.email_confirmed_at,
  p.full_name,
  CASE 
    WHEN u.email_confirmed_at IS NOT NULL THEN '✅ Confirmed'
    ELSE '❌ Not Confirmed'
  END as status
FROM auth.users u
JOIN profiles p ON p.id = u.id
WHERE p.role = 'staff'
ORDER BY p.full_name;

SELECT 'All staff emails confirmed!' as result;
