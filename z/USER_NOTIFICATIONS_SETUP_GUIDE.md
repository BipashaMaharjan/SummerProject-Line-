# 🔔 User Notifications Setup Guide

## Quick Start

Follow these steps to enable user notifications in your app:

### Step 1: Run Database Setup Script

1. Open **Supabase Dashboard** → **SQL Editor**
2. Open the file: `d:\SummerProject-Line- - Copy - Copy\z\USER_NOTIFICATIONS_SETUP.sql`
3. Copy all the SQL code
4. Paste it into the Supabase SQL Editor
5. Click **Run** button
6. Wait for confirmation message: "✅ SETUP COMPLETE!"

### Step 2: Restart Flutter App

1. Stop the running Flutter app (Ctrl+C in terminal)
2. Run `flutter run` again
3. Login as a customer/user

### Step 3: Test Notifications

**Test 1: Status Change Notification**
1. Login as a customer and create a token
2. Login as staff (in another browser/device)
3. Change the token status from "waiting" to "processing"
4. Check customer's notification screen - you should see: "Your Turn! 🎯 - Token T12345 is now being served"

**Test 2: Room Transfer Notification**
1. As staff, transfer a token to a different room
2. Check customer's notification screen - you should see: "Token Transferred 🔄 - Token T12345 transferred from Reception to Room 1"

**Test 3: Real-time Updates**
1. Keep customer app open on notifications screen
2. As staff, make changes to the token
3. Notifications should appear instantly without refresh

## What Was Implemented

### Database Changes
- ✅ Created `user_notifications` table
- ✅ Added triggers for room transfers
- ✅ Added triggers for status changes
- ✅ Set up RLS policies (users can only see their own notifications)
- ✅ Created indexes for performance

### Flutter App Changes
- ✅ Created `UserNotificationService` for database operations
- ✅ Updated `NotificationProvider` to use real database
- ✅ Updated notifications screen with pull-to-refresh
- ✅ Added real-time subscriptions
- ✅ Initialized notifications on user login

## Notification Types

### 1. Room Transfer Notifications
**When**: Token is moved from one room to another
**Example**: "Token Transferred 🔄 - Token T12345 transferred from Reception to Room 1"

### 2. Status Change Notifications
**When**: Token status changes
**Examples**:
- "Your Turn! 🎯 - Token T12345 is now being served in Room 1"
- "Service Completed ✅ - Token T12345 has been completed successfully"
- "Token On Hold ⏸️ - Token T12345 is on hold. Please wait for further instructions."

## Troubleshooting

### No notifications appearing?

1. **Check database setup**:
   ```sql
   -- Run in Supabase SQL Editor
   SELECT COUNT(*) FROM user_notifications;
   ```
   If count is 0, triggers might not be working.

2. **Check triggers exist**:
   ```sql
   SELECT trigger_name FROM information_schema.triggers 
   WHERE event_object_table = 'tokens' 
   AND trigger_name LIKE '%user%';
   ```
   Should show 2 triggers.

3. **Check RLS policies**:
   ```sql
   SELECT * FROM pg_policies WHERE tablename = 'user_notifications';
   ```
   Should show 4 policies.

4. **Check Flutter console**:
   Look for messages like:
   - "NotificationProvider: Initialized successfully"
   - "UserNotificationService: New notification received"

### Notifications not updating in real-time?

1. Check internet connection
2. Restart the Flutter app
3. Check Supabase dashboard for any connection issues

## Files Changed

### Database
- `d:\SummerProject-Line- - Copy - Copy\z\USER_NOTIFICATIONS_SETUP.sql` (NEW)

### Flutter
- `lib/services/user_notification_service.dart` (NEW)
- `lib/providers/notification_provider.dart` (UPDATED)
- `lib/screens/home/notifications_screen.dart` (UPDATED)
- `lib/screens/home/home_screen.dart` (UPDATED)

## Next Steps

After testing, you can:
1. Customize notification messages in the database triggers
2. Add more notification types (e.g., queue position alerts)
3. Add push notifications for mobile devices
4. Add notification settings (enable/disable certain types)

---

**Need help?** Check the console logs for detailed debugging information.
