-- ============================================
-- Auto-Confirm Email for Staff Accounts
-- ============================================

-- Create function to confirm user email
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION confirm_user_email(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION confirm_user_email(UUID) TO service_role;

-- Test the function (optional)
-- SELECT confirm_user_email('PASTE_USER_ID_HERE');

SELECT 'Email confirmation function created!' as status;
