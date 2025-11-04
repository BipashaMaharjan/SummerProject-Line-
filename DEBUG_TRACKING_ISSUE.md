# Debugging Real-Time Tracking Issue

## Issue
The tracking screen shows "No tracking information available"

## Possible Causes

### 1. Token ID Not Found
The token ID being passed might not exist in the database.

**Check:**
- Open browser DevTools (F12)
- Look for console logs starting with "RealtimeTokenTracker:"
- Check what token ID is being used

### 2. Database Query Failing
The query to fetch token data might be failing due to:
- Missing token in database
- RLS policies blocking access
- Invalid token ID format

### 3. Service/Room Data Missing
The token might exist but service or room data is missing.

## Quick Fix Steps

### Step 1: Check Browser Console
1. Press F12 to open DevTools
2. Go to Console tab
3. Look for error messages
4. Share the error logs

### Step 2: Verify Token Exists
Run this in Supabase SQL Editor:
```sql
SELECT * FROM tokens 
WHERE user_id = auth.uid()
ORDER BY created_at DESC
LIMIT 5;
```

### Step 3: Check RLS Policies
Make sure users can read their own tokens:
```sql
-- Check if policy exists
SELECT * FROM pg_policies 
WHERE tablename = 'tokens';

-- If needed, create a permissive policy
CREATE POLICY "Users can read own tokens"
ON tokens FOR SELECT
TO authenticated
USING (user_id = auth.uid());
```

### Step 4: Test Direct Query
Try this in Supabase SQL Editor:
```sql
SELECT 
  t.*,
  s.name as service_name,
  r.name as room_name,
  r.room_number
FROM tokens t
LEFT JOIN services s ON s.id = t.service_id
LEFT JOIN rooms r ON r.id = t.current_room_id
WHERE t.user_id = auth.uid()
ORDER BY t.created_at DESC
LIMIT 1;
```

## Expected Console Output

When working correctly, you should see:
```
RealtimeTokenTracker: Initializing tracking for token: <token-id>
RealtimeTrackingService: Fetching tracking info for token: <token-id>
RealtimeTrackingService: Token data: {id: ..., token_number: ..., ...}
RealtimeTrackingService: Token created: T123, status: waiting
RealtimeTrackingService: Queue position: 1
RealtimeTrackingService: Tokens ahead: 0
RealtimeTokenTracker: Tracking info result: success
```

## Temporary Workaround

If the issue persists, we can:
1. Use the existing token display from "My Tokens" screen
2. Add a simpler tracking view without real-time features
3. Debug the specific error from console logs

## Next Steps

Please:
1. Open browser DevTools (F12)
2. Go to Console tab
3. Click on a token card to open tracking
4. Share any error messages you see in red
5. Share the console logs

This will help me identify the exact issue and fix it quickly!
