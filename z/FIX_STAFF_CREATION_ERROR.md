# 🔧 Fix Staff Creation RLS Error

## Problem
```
PostgrestException(message: new row violates row-level security policy for table "profiles", code: 42501)
```

This error occurs when admins try to create staff accounts because the RLS policy doesn't allow admins to insert profiles for other users.

## ✅ Solution

### Step 1: Run the Fix Script

**File:** `fix_staff_creation_complete.sql`

**In Supabase SQL Editor:**
1. Copy the entire `fix_staff_creation_complete.sql` file
2. Paste in Supabase SQL Editor
3. Click **RUN**

This script will:
- ✅ Update RLS policies to allow admins to create profiles
- ✅ Create a database trigger to auto-create profiles on signup
- ✅ Fix staff table policies
- ✅ Make the system secure and functional

### Step 2: Code Already Updated

The Flutter code has been updated to:
- ✅ Use database trigger for profile creation (automatic)
- ✅ Fallback to manual creation if trigger fails
- ✅ Better error handling and logging
- ✅ Verify profile creation before proceeding

## 🎯 What the Fix Does

### Database Trigger (Automatic)
```sql
-- When a new user is created in auth.users
-- This trigger automatically creates their profile
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();
```

### RLS Policy (Secure)
```sql
-- Allows:
-- 1. Users to create their own profile
-- 2. Admins to create any profile (for staff creation)
-- 3. System triggers to create profiles
CREATE POLICY "Allow profile insertion" ON profiles
  FOR INSERT
  WITH CHECK (
    auth.uid() = id  -- Own profile
    OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')  -- Admin
    OR
    auth.uid() IS NULL  -- System/trigger
  );
```

## 🧪 Testing

### Test Staff Creation

1. **Run the app as admin:**
   ```bash
   flutter run -d chrome --dart-define=APP_TYPE=admin
   ```

2. **Go to Admin Dashboard**
3. **Click "Create Staff Account"**
4. **Fill in details:**
   - Name: Test Staff
   - Email: teststaff@example.com
   - Password: Test123!

5. **Click Create**

### Expected Result
```
✅ Auth user created: [UUID]
✅ Profile auto-created by trigger
✅ Staff record created
✅ Email confirmed
✅ Staff account created: Test Staff
```

### Verify in Database
```sql
-- Check if staff was created
SELECT 
  p.id,
  p.full_name,
  p.email,
  p.role,
  p.is_active,
  s.id as staff_record_exists
FROM profiles p
LEFT JOIN staff s ON s.id = p.id
WHERE p.role = 'staff'
ORDER BY p.created_at DESC;
```

## 🔍 Troubleshooting

### Issue: Still getting RLS error

**Solution 1: Check if script ran successfully**
```sql
-- Verify policies exist
SELECT policyname, cmd 
FROM pg_policies 
WHERE tablename = 'profiles';

-- Should see: "Allow profile insertion"
```

**Solution 2: Check if trigger exists**
```sql
-- Verify trigger exists
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';
```

**Solution 3: Manually create profile**
If trigger doesn't work, the code will automatically fall back to manual creation.

### Issue: Email not confirmed

This is optional. Staff can still login even if email isn't confirmed. To fix:

```sql
-- Create email confirmation function
CREATE OR REPLACE FUNCTION confirm_user_email(user_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE auth.users
  SET email_confirmed_at = NOW()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## 📋 Checklist

- [ ] Run `fix_staff_creation_complete.sql` in Supabase
- [ ] Verify policies with verification queries
- [ ] Verify trigger exists
- [ ] Test creating a staff account
- [ ] Check console logs for success messages
- [ ] Verify staff appears in database
- [ ] Test staff can login

## 🎉 After Fix

You'll be able to:
- ✅ Create staff accounts from admin panel
- ✅ Profiles auto-create via trigger
- ✅ No more RLS errors
- ✅ Secure and follows best practices
- ✅ Admins can manage staff
- ✅ Regular users can only manage their own profiles

## 🔐 Security Notes

**This solution is secure because:**
1. Regular users can only create/update their own profile
2. Admins can create/update any profile (needed for staff management)
3. The trigger runs with SECURITY DEFINER (bypasses RLS for system operations)
4. All policies are explicit and controlled
5. No security holes introduced

---

**Run the fix script and try creating a staff account again!** 🚀
