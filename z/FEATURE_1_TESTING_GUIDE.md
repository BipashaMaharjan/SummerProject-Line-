# Feature 1: Real-Time Token Tracking - Testing Guide

## 🎯 What Was Implemented

### New Components Created:
1. **RealtimeTrackingService** (`lib/services/realtime_tracking_service.dart`)
   - Supabase Realtime WebSocket subscriptions
   - Live token status updates
   - Queue position calculation
   - Room information tracking

2. **RealtimeTokenTracker Widget** (`lib/widgets/realtime_token_tracker.dart`)
   - Beautiful real-time tracking UI
   - Live status indicator (green dot)
   - Queue position display
   - Room information
   - Auto-refresh on changes

3. **TokenTrackingScreen** (`lib/screens/user/token_tracking_screen.dart`)
   - Full-screen tracking interface
   - Action buttons (cancel, share)
   - Information cards

4. **Updated TokenCard** (`lib/widgets/token_card.dart`)
   - Added "Tap to track live" indicator
   - Navigation to tracking screen
   - Green live indicator for active tokens

## 🧪 How to Test the Feature

### Step 1: Login to the App
1. Open the app (should be running in Chrome)
2. Sign up or login with your email
3. Complete OTP verification

### Step 2: Book a Token
1. Go to "Services" tab in bottom navigation
2. Select either "License Renewal" or "New License Application"
3. Choose a room and book the token
4. You'll see a success message

### Step 3: View Real-Time Tracking
1. Go to "My Tokens" tab in bottom navigation
2. You'll see your token card with a green "Tap to track live" indicator
3. **Tap on the token card** to open the real-time tracking screen

### Step 4: See Real-Time Updates
On the tracking screen, you'll see:
- ✅ **Token Number** with display format (e.g., T123-1)
- ✅ **Service Name** (License Renewal/New License)
- ✅ **Status Badge** with color coding
- ✅ **Live Indicator** (green dot with "Live" text)
- ✅ **Queue Position** (e.g., "#3 in queue")
- ✅ **Tokens Ahead** count
- ✅ **Current Room** information (when processing)
- ✅ **Last Updated** timestamp
- ✅ **Status Message** (user-friendly description)

### Step 5: Test Real-Time Updates (Advanced)
To see the real-time feature in action:

1. **Option A - Using Staff Dashboard:**
   - Open another browser window
   - Login as staff (if you have staff account)
   - Update the token status
   - Watch the user's tracking screen update automatically!

2. **Option B - Using Supabase Dashboard:**
   - Go to your Supabase dashboard
   - Navigate to Table Editor → tokens
   - Update the status of your token (e.g., from 'waiting' to 'processing')
   - Watch the tracking screen update in real-time!

3. **Option C - Using SQL Editor:**
   ```sql
   -- Update token status
   UPDATE tokens 
   SET status = 'processing', 
       current_room_id = 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79360'
   WHERE id = 'YOUR_TOKEN_ID';
   ```

## 🎨 What You'll See

### Visual Elements:
1. **Status Colors:**
   - 🟠 Orange = Waiting
   - 🔵 Blue = Processing
   - 🟢 Green = Completed
   - 🔴 Red = Hold/Rejected
   - ⚫ Grey = No Show

2. **Live Indicator:**
   - Green pulsing dot
   - "Live" text in green
   - Shows connection is active

3. **Status Messages:**
   - Waiting: "You are #X in queue. Y tokens ahead."
   - Processing: "Being served in Room Name (Room Number)"
   - Completed: "Service completed"

4. **Information Cards:**
   - Queue position for waiting tokens
   - Room information for processing tokens
   - Booking timestamp
   - Service details

## 🔍 Key Features to Notice

### 1. **No Manual Refresh Needed**
   - The screen updates automatically when token status changes
   - No need to pull-to-refresh or tap refresh button

### 2. **Real-Time Queue Position**
   - Shows your exact position in the queue
   - Updates as people ahead of you are served

### 3. **Room Tracking**
   - When your token is being processed, you'll see which room
   - Displays room name and room number

### 4. **Timestamp Updates**
   - Shows "Just now" for recent updates
   - Shows "Xm ago" for updates within the hour
   - Shows time for older updates

### 5. **Action Buttons**
   - Cancel token (for waiting tokens only)
   - Share token details

## 📱 Expected User Experience

### Scenario 1: Waiting in Queue
```
Token: T123-1
Service: License Renewal
Status: WAITING

[Hourglass Icon] You are #5 in queue. 4 tokens ahead.

Queue Position: #5
Tokens Ahead: 4
Booked At: 24/10/2025 19:30

🟢 Live | Last updated: Just now
```

### Scenario 2: Being Processed
```
Token: T123-1
Service: License Renewal
Status: IN PROGRESS

[Play Icon] Being served in Reception (R001)

Current Room: Reception (R001)
Booked At: 24/10/2025 19:30

🟢 Live | Last updated: 2m ago
```

### Scenario 3: Completed
```
Token: T123-1
Service: License Renewal
Status: COMPLETED

[Check Icon] Service completed

Booked At: 24/10/2025 19:30

🟢 Live | Last updated: 5m ago
```

## 🐛 Troubleshooting

### If tracking screen shows error:
1. Check internet connection
2. Verify Supabase connection
3. Check if token exists in database
4. Tap "Retry" button

### If updates are not real-time:
1. Check if Realtime is enabled in Supabase
2. Verify RLS policies allow reading tokens
3. Check browser console for WebSocket errors

### If "Tap to track live" doesn't appear:
1. Only active tokens (waiting, processing, hold) show this
2. Completed/rejected tokens don't have live tracking

## ✅ Success Criteria

You'll know Feature 1 is working when:
- ✅ Token cards show "Tap to track live" indicator
- ✅ Tapping opens the tracking screen
- ✅ Green "Live" indicator is visible
- ✅ Queue position is displayed for waiting tokens
- ✅ Room information shows for processing tokens
- ✅ Status updates happen automatically (no refresh needed)
- ✅ Timestamp shows "Just now" or time since update

## 🎉 What Makes This Feature Special

1. **True Real-Time**: Uses WebSocket connections, not polling
2. **Efficient**: Only subscribes to relevant tokens
3. **User-Friendly**: Clear status messages and visual indicators
4. **Reliable**: Automatic reconnection if connection drops
5. **Beautiful UI**: Material 3 design with smooth animations

## 📝 Notes for Testing

- The app is running in Chrome, so you can open DevTools to see console logs
- Look for logs starting with "RealtimeTrackingService:" to see connection status
- The green "Live" indicator confirms active WebSocket connection
- Try updating token status from Supabase to see instant updates

---

**Ready to test?** Follow the steps above and experience real-time token tracking! 🚀
