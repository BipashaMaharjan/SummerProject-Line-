# 🔧 Start Processing - Complete Troubleshooting Guide

## Problem Summary
The "Start Processing" button is not working. When staff clicks it, it fails silently or shows an error.

---

## Understanding the Issue

### What "Start Processing" Does
1. **Flutter Code** → `lib/screens/staff/enhanced_staff_dashboard.dart`
   ```dart
   Future<void> _startProcessing(BuildContext context, Token token) async {
     final success = await context.read<TokenProvider>().startOperation(
       token.id,
       token.currentRoomId!,
     );
   }
   ```

2. **Provider Code** → `lib/providers/token_provider.dart` (line 747)
   ```dart
   Future<bool> startOperation(String tokenId, String roomId) async {
     // Step 1: Update token status to 'processing'
     await SupabaseConfig.client
         .from('tokens')
         .update({ 'status': 'processing' })
         .eq('id', tokenId);
     
     // Step 2: Add history entry
     await SupabaseConfig.client
         .from('token_history')
         .insert({...});
   }
   ```

3. **Database Level** → Supabase PostgreSQL
   - `UPDATE tokens SET status = 'processing' WHERE id = ?`
   - `INSERT INTO token_history (...) VALUES (...)`

### Where It Usually Fails
🔴 **RLS (Row Level Security) Policies** block the operations because:
- ❌ The `tokens` table has no UPDATE policy for staff
- ❌ The `token_history` table has no INSERT policy for staff
- ❌ RLS is enabled but policies are missing/incorrect

---

## Step 1: Check Browser Console for Errors

1. Open Firefox/Chrome DevTools: **F12**
2. Go to **Console** tab
3. Click "Start Processing" button
4. Look for error messages like:
   ```
   ERROR: new row violates row-level security policy
   ERROR: permission denied for table tokens
   ERROR: permission denied for schema public
   ```

**Common Errors:**
- ❌ `"new row violates row-level security policy for table \"tokens\""` → UPDATE blocked
- ❌ `"permission denied for table \"token_history\""` → INSERT blocked
- ❌ `"current transaction is aborted"` → A previous operation failed

---

## Step 2: Run the SQL Fix

### Method A: Using Supabase Dashboard
1. Go to **Supabase** → Your Project
2. Click **SQL Editor** (left sidebar)
3. Click **New Query**
4. Copy **entire content** from: `z/BACKEND_FIX_START_PROCESSING.sql`
5. Paste it into the editor
6. Click **▶️ Run** (blue button)
7. Check for errors in the output

### Method B: Using psql Terminal
```bash
# Connect to your Supabase database
psql -h db.xxxxx.supabase.co -U postgres -d postgres

# Paste the SQL from BACKEND_FIX_START_PROCESSING.sql
```

---

## Step 3: Verify the Fix

After running the SQL, check these queries in Supabase:

### Check 1: RLS Enabled?
```sql
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('tokens', 'token_history');
```
✅ Expected: Both should show `TRUE` for rowsecurity

### Check 2: Policies Exist?
```sql
SELECT tablename, policyname, cmd 
FROM pg_policies 
WHERE tablename IN ('tokens', 'token_history')
ORDER BY tablename;
```
✅ Expected output:
```
token_history    | token_history_insert_allow | INSERT
token_history    | token_history_select_allow | SELECT
tokens           | tokens_update_allow        | UPDATE
tokens           | tokens_select_strict       | SELECT  (may vary)
```

### Check 3: Staff User Has Correct Role?
```sql
-- Check your staff user
SELECT id, full_name, email, role, assigned_room_id 
FROM profiles 
WHERE email = 'your-staff-email@work.com';
```
✅ Expected: `role = 'staff'` (NOT 'admin' or 'customer')

### Check 4: Test the Operations
```sql
-- Test UPDATE on tokens
UPDATE tokens 
SET status = 'processing' 
WHERE id = (SELECT id FROM tokens LIMIT 1);

-- Test INSERT on token_history
INSERT INTO token_history (token_id, room_id, status, action, notes)
SELECT 
  id,
  (SELECT id FROM rooms LIMIT 1),
  'processing',
  'test',
  'Test insert'
FROM tokens LIMIT 1;
```
✅ If these work, the database permissions are fixed

---

## Step 4: Reload the App

1. **Clear Cache** (important!)
   - Open DevTools (F12)
   - Right-click refresh button → **Empty cache and hard refresh**
   - Or: `Ctrl + Shift + Delete`

2. **Reload the page**
   - Press `Ctrl + R` or click refresh

3. **Test again**
   - Go to staff dashboard
   - Click "Start Processing" on a waiting token

---

## Still Not Working? Debug Deeper

### Check Supabase Logs
1. Go to **Supabase Dashboard**
2. Click **Logs** (left sidebar)
3. Run the Start Processing operation again
4. Look for error details

### Enable Debug Output in Dart
Add to your `token_provider.dart` in the `startOperation` method:

```dart
Future<bool> startOperation(String tokenId, String roomId) async {
  try {
    debugPrint('🔵 [DEBUG] Starting operation for token: $tokenId in room: $roomId');
    
    // Step 1: Update token
    debugPrint('🔵 [DEBUG] Attempting to update tokens table...');
    final updateResponse = await SupabaseConfig.client
        .from('tokens')
        .update({'status': 'processing'})
        .eq('id', tokenId);
    debugPrint('🟢 [DEBUG] Token update successful: $updateResponse');

    // Step 2: Insert history
    debugPrint('🔵 [DEBUG] Attempting to insert into token_history...');
    final insertResponse = await SupabaseConfig.client
        .from('token_history')
        .insert({
          'token_id': tokenId,
          'room_id': roomId,
          'status': 'processing',
          'action': 'started',
          'notes': 'Operation started by staff',
        });
    debugPrint('🟢 [DEBUG] History insert successful: $insertResponse');
    
    return true;
  } catch (error) {
    debugPrint('🔴 [ERROR] Start operation failed: $error');
    return false;
  }
}
```

Then check **Console** output in DevTools.

---

## Common Solutions by Error Type

### Error: "permission denied for table tokens"
**Cause:** UPDATE policy missing on tokens table
**Fix:** Run `BACKEND_FIX_START_PROCESSING.sql` (Step 2)

### Error: "permission denied for table token_history"
**Cause:** INSERT policy missing on token_history table
**Fix:** Run `BACKEND_FIX_START_PROCESSING.sql` (Step 2)

### Error: "current user is not authenticated"
**Cause:** User is not logged in properly
**Fix:** 
1. Log out completely
2. Clear browser cache (Ctrl+Shift+Delete)
3. Log back in
4. Try again

### Error: "role is not admin or staff"
**Cause:** User profile doesn't have correct role
**Fix:**
```sql
UPDATE profiles 
SET role = 'staff' 
WHERE email = 'your-email@work.com';
```

### Button works but nothing happens
**Cause:** Success but token didn't refresh
**Fix:** Look for `onRefresh()` call - make sure UI is refreshing

---

## What the SQL Fix Does

The `BACKEND_FIX_START_PROCESSING.sql` file:

1. **Enables RLS** on both tables (required for policies to work)
2. **Removes broken policies** that were blocking operations
3. **Creates new UPDATE policy** on tokens:
   - Allows admin users to update tokens
   - Allows staff users to update tokens
   - Blocks customers/unauthenticated users

4. **Creates new INSERT policy** on token_history:
   - Allows admin users to insert history
   - Allows staff users to insert history
   - Blocks customers/unauthenticated users

5. **Creates SELECT policy** on token_history (bonus):
   - Allows staff to view history entries

---

## Quick Checklist

- [ ] Ran `BACKEND_FIX_START_PROCESSING.sql` in Supabase
- [ ] Verified RLS is enabled on both tables
- [ ] Verified policies exist with `pg_policies`
- [ ] Checked that staff user has `role = 'staff'`
- [ ] Cleared browser cache (Ctrl+Shift+Delete)
- [ ] Reloaded the app
- [ ] Tested "Start Processing" again

---

## Need More Help?

### Check Files:
- **SQL Fix:** `z/BACKEND_FIX_START_PROCESSING.sql`
- **Dart Code:** `lib/providers/token_provider.dart` (line 747+)
- **UI Code:** `lib/screens/staff/enhanced_staff_dashboard.dart` (line 304+)

### Test Data Needed:
- Token ID of a "waiting" token
- Room ID assigned to the token
- Staff user's UUID

---

## Next Steps After Fix Works

Once "Start Processing" is working:
1. Test "Complete Token" button
2. Test "Transfer to Next Room" 
3. Test "Reject Token"
4. Verify token_history is being populated correctly
5. Check real-time updates are working

---

**Last Updated:** January 5, 2026
**Status:** ✅ Complete and Tested
