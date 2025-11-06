# Token Transfer Testing Guide

## 🎯 Quick Test: Real-Time Transfer

### Setup (2 Browser Windows)

1. **Window 1:** Staff Dashboard - Room 1 (Reception)
   ```
   http://localhost:XXXX
   Login as Staff → Go to Dashboard
   ```

2. **Window 2:** Staff Dashboard - Room 2 (Document Verification)
   ```
   http://localhost:XXXX (Incognito/Private)
   Login as different Staff → Go to Dashboard
   ```

### Test Steps

#### Step 1: Create a Test Token
1. Open User view (or use existing token)
2. Book a token for License Renewal
3. Token should appear in Room 1 (Reception) queue

#### Step 2: Start Processing
1. In Window 1 (Room 1 Staff):
   - Click on the token
   - Click "Start" or "Pick Token"
   - Status changes to "Processing"

#### Step 3: Transfer to Next Room
1. In Window 1 (Room 1 Staff):
   - Click "Transfer" button
   - See confirmation: "✅ Transferred to Document Verification"
   - Token disappears from Room 1 queue

2. **Watch Window 2 (Room 2 Staff):**
   - Token should appear INSTANTLY (no refresh needed)
   - Status shows "Waiting"
   - Queue count increases by 1

#### Step 4: Verify Console Logs
Open browser console (F12) and look for:
```
🔄 ========== TOKEN TRANSFER STARTED ==========
📋 Token ID: ...
📋 Token Number: T21502
📍 Current Room: Reception
📍 Next Room: Document Verification
🔄 Updating token in database...
✅ Token updated in database
📝 Recording transfer in history...
✅ Transfer recorded in history
🔔 Real-time update triggered automatically by Supabase
📡 All connected dashboards will receive update
✅ ========== TOKEN TRANSFER COMPLETED ==========

🔔 Token update received: UPDATE
📡 Refreshing token queue...
✅ Loaded XX tokens
```

## ✅ Expected Results

### Room 1 (Previous Room)
- ✅ Token disappears from queue immediately
- ✅ Queue count decreases
- ✅ Next token moves up in queue
- ✅ No manual refresh needed

### Room 2 (Next Room)
- ✅ Token appears in queue immediately
- ✅ Queue count increases
- ✅ Token status shows "Waiting"
- ✅ Token ready for processing

### User Dashboard (if open)
- ✅ Current room updates to "Document Verification"
- ✅ Status changes to "Waiting"
- ✅ Queue position recalculates
- ✅ Notification sent (if enabled)

## 🔍 What to Check

### 1. Transfer Button Visibility
- ✅ Shows "Transfer" button when NOT in last room
- ✅ Shows next room name below buttons
- ✅ Button is blue and prominent

### 2. Real-Time Updates
- ✅ Updates happen within 1 second
- ✅ No page refresh required
- ✅ All connected dashboards update

### 3. Token History
- ✅ Transfer recorded in history
- ✅ Shows from/to rooms
- ✅ Shows staff member who transferred
- ✅ Timestamp recorded

### 4. Workflow Progress
- ✅ Current room indicator updates
- ✅ Sequence number increments
- ✅ Progress bar/steps update

## 🐛 Troubleshooting

### Token not appearing in next room?

**Check:**
1. Is the workflow configured correctly?
2. Are there multiple rooms in the workflow?
3. Check console for errors
4. Verify Supabase connection

**Debug:**
```dart
// In token_details_screen.dart, check debug logs:
🔍 Action Section Debug:
  - Workflow length: 5
  - Current room ID: ...
  - Current index: 0
  - Has next room: true
  - Next room: Document Verification
```

### Real-time not working?

**Check:**
1. Open browser console (F12)
2. Look for WebSocket connection
3. Check for subscription errors
4. Verify Supabase Realtime is enabled

**Fix:**
```dart
// Verify subscription is active
context.read<TokenProvider>().subscribeToTokenUpdates((data) {
  debugPrint('Subscription callback triggered');
});
```

### Transfer button not showing?

**Check:**
1. Is token status "processing"?
2. Is this the last room in workflow?
3. Check workflow configuration
4. Look for debug message: "⚠️ Current room not found in workflow"

## 📊 Performance Benchmarks

- **Transfer Time:** < 500ms
- **Real-time Update:** < 100ms
- **Dashboard Refresh:** < 200ms
- **Total Time:** < 1 second

## 🎓 Test Scenarios

### Scenario 1: Normal Flow
```
Reception → Document Verification → Payment → Photo → Final
```
Transfer through each room, verify updates at each step.

### Scenario 2: Multiple Tokens
Transfer 3-5 tokens in quick succession, verify all update correctly.

### Scenario 3: Concurrent Transfers
Two staff members transfer different tokens simultaneously.

### Scenario 4: Network Delay
Simulate slow network, verify updates still work.

### Scenario 5: Page Reload
Transfer token, reload dashboard, verify correct state.

## 📝 Test Checklist

- [ ] Transfer button appears when not in last room
- [ ] Transfer button shows correct next room name
- [ ] Transfer updates token in database
- [ ] Token disappears from previous room instantly
- [ ] Token appears in next room instantly
- [ ] Queue counts update correctly
- [ ] Token status changes to "waiting"
- [ ] Transfer recorded in history
- [ ] User dashboard updates (if open)
- [ ] Console logs show transfer steps
- [ ] Real-time subscription active
- [ ] No errors in console
- [ ] Works across multiple browser tabs
- [ ] Works after page reload

## 🚀 Quick Commands

### Check Subscription Status
```javascript
// In browser console
console.log('Channels:', window.supabase?.getChannels());
```

### Force Refresh
```javascript
// If needed for testing
location.reload();
```

### Clear Cache
```javascript
// Clear local storage
localStorage.clear();
sessionStorage.clear();
```

## 📞 Support

If issues persist:
1. Check `REALTIME_TRANSFER_SYSTEM.md` for detailed documentation
2. Review console logs for errors
3. Verify Supabase Realtime is enabled in project settings
4. Check network tab for WebSocket connection

---

**Happy Testing!** 🎉
