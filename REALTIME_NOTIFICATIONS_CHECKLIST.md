# Real-Time Notification System - Implementation Checklist

## Pre-Implementation

- [ ] Review `REALTIME_NOTIFICATIONS_QUICK_START.md` (5 min read)
- [ ] Review `REALTIME_NOTIFICATIONS_ARCHITECTURE.md` (understand flow)
- [ ] Backup your database
- [ ] Test in development environment first

---

## Step 1: Database Setup (10 minutes)

### 1.1 Run SQL Script
- [ ] Open Supabase project
- [ ] Navigate to SQL Editor
- [ ] Copy entire content of `z/REALTIME_NOTIFICATIONS_SETUP.sql`
- [ ] Paste into SQL Editor
- [ ] Click "Run" button
- [ ] Wait for completion (should complete in < 30 seconds)
- [ ] Check for errors in output

### 1.2 Verify Setup
```sql
-- Run these verification queries
```

- [ ] Check table exists:
  ```sql
  SELECT * FROM staff_notifications LIMIT 1;
  ```
  ✅ Should not error (table exists)

- [ ] Check triggers exist:
  ```sql
  SELECT trigger_name FROM information_schema.triggers
  WHERE table_name = 'tokens' AND trigger_schema = 'public';
  ```
  ✅ Should show: trg_notify_on_token_transfer, trg_notify_on_token_status_change, trg_notify_on_token_assignment

- [ ] Check RLS enabled:
  ```sql
  SELECT relname, relrowsecurity FROM pg_class 
  WHERE relname = 'staff_notifications';
  ```
  ✅ Should show relrowsecurity = t (true)

- [ ] Check indexes:
  ```sql
  SELECT indexname FROM pg_indexes 
  WHERE tablename = 'staff_notifications';
  ```
  ✅ Should show 5 indexes

---

## Step 2: Flutter Code Integration (15 minutes)

### 2.1 Review Generated Files
- [ ] `lib/models/notification.dart` (247 lines)
- [ ] `lib/services/staff_notification_service.dart` (286 lines)
- [ ] `lib/services/token_transfer_service.dart` (345 lines)
- [ ] `lib/providers/notification_history_provider.dart` (341 lines)
- [ ] `lib/widgets/notification_widgets.dart` (325 lines)
- [ ] `lib/screens/notification_center_screen.dart` (272 lines)

### 2.2 Update main.dart
- [ ] Import NotificationHistoryProvider:
  ```dart
  import 'providers/notification_history_provider.dart';
  ```

- [ ] Add to MultiProvider:
  ```dart
  ChangeNotifierProvider(
    create: (_) => NotificationHistoryProvider(),
  ),
  ```

- [ ] Verify no build errors:
  ```bash
  flutter pub get
  flutter analyze
  ```
  ✅ Should show 0 errors

### 2.3 Update Auth/Login Flow
- [ ] After successful login, add initialization:
  ```dart
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final notificationProvider = 
      context.read<NotificationHistoryProvider>();
    final authProvider = context.read<AuthProvider>();
    
    if (authProvider.currentUser != null) {
      notificationProvider.initialize(authProvider.currentUser!.id);
    }
  });
  ```

- [ ] After logout, add cleanup:
  ```dart
  context.read<NotificationHistoryProvider>().dispose();
  ```

---

## Step 3: UI Integration (20 minutes)

### 3.1 Option A: Simple Badge (Recommended for first try)
- [ ] Add to AppBar of main dashboard:
  ```dart
  AppBar(
    title: const Text('Staff Dashboard'),
    actions: [
      NotificationBadge(
        child: IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationCenterScreen(),
              ),
            );
          },
        ),
      ),
    ],
  )
  ```

- [ ] Test that badge appears
- [ ] Test that badge shows unread count
- [ ] Click badge to open notification center

### 3.2 Option B: Notification Preview Card
- [ ] Add to dashboard body:
  ```dart
  Consumer<NotificationHistoryProvider>(
    builder: (context, provider, _) {
      if (!provider.isInitialized || provider.unreadCount == 0) {
        return const SizedBox.shrink();
      }
      
      final recent = provider.getUnread().take(3).toList();
      return Card(
        child: Column(
          children: [
            Text('Recent Notifications (${provider.unreadCount} unread)'),
            ...recent.map((n) => Text(n.message)),
          ],
        ),
      );
    },
  )
  ```

- [ ] Test that preview shows
- [ ] Test that it updates in real-time

### 3.3 Option C: Full Notification Center
- [ ] Create route in go_router (or your navigation):
  ```dart
  GoRoute(
    path: '/notifications',
    builder: (context, state) => const NotificationCenterScreen(),
  ),
  ```

- [ ] Add navigation to it from badge/menu
- [ ] Test all features:
  - [ ] Shows notification list
  - [ ] Filter by type works
  - [ ] Unread only filter works
  - [ ] Mark as read works
  - [ ] Delete works
  - [ ] Statistics display correctly

---

## Step 4: Token Operations Integration (15 minutes)

### 4.1 Transfer Token Implementation
- [ ] Find where token transfers happen in your code
- [ ] Replace old code with:
  ```dart
  final transferService = TokenTransferService();
  await transferService.initialize();
  
  final success = await transferService.transferTokenToRoom(
    tokenId: token.id,
    tokenNumber: token.tokenNumber,
    newRoomId: nextRoom.id,
    newRoomName: nextRoom.name,
    previousRoomId: currentRoom.id,
    previousRoomName: currentRoom.name,
    currentStaffId: currentStaffId,
  );
  
  if (success) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Token transferred! Notification sent.')),
    );
  }
  ```

- [ ] Test transfer:
  - [ ] Token updates in database
  - [ ] Staff in new room receives notification
  - [ ] Notification appears in real-time
  - [ ] Old staff sees "transferred out" notification

### 4.2 Update Status Implementation
- [ ] Find where status updates happen
- [ ] Replace with:
  ```dart
  final transferService = TokenTransferService();
  await transferService.initialize();
  
  final success = await transferService.updateTokenStatus(
    tokenId: token.id,
    tokenNumber: token.tokenNumber,
    newStatus: TokenStatus.processing,
    currentRoomName: currentRoom.name,
    currentStaffId: currentStaffId,
  );
  ```

- [ ] Test status change:
  - [ ] Status updates in database
  - [ ] Assigned staff gets notification
  - [ ] Admin gets notification
  - [ ] UI updates immediately

---

## Step 5: Testing (30 minutes)

### 5.1 Unit/Service Testing
- [ ] TokenNotification.fromJson() works
- [ ] TokenNotification.toJson() works
- [ ] StaffNotificationService.initialize() succeeds
- [ ] NotificationHistoryProvider.initialize() succeeds

### 5.2 Integration Testing - Single User
- [ ] Login as staff member A
- [ ] See notification center (empty)
- [ ] Create/transfer a token to room where A is assigned
- [ ] A receives notification:
  - [ ] In real-time (no refresh)
  - [ ] In notification list
  - [ ] Badge shows +1
  - [ ] Type is correct
  - [ ] Message is readable

### 5.3 Integration Testing - Multiple Users
- [ ] Open app on 2 devices (or 2 browser windows):
  - [ ] Device 1: Staff in Room 1
  - [ ] Device 2: Staff in Room 2
  
- [ ] On Device 1: Transfer token from Room 1 to Room 2
  
- [ ] On Device 2: Verify
  - [ ] Notification appears instantly
  - [ ] Badge updates instantly
  - [ ] Can tap and see details
  
- [ ] On Device 1: Verify
  - [ ] "Transferred out" notification appears
  - [ ] Details are correct

### 5.4 Filtering/Search Testing
- [ ] Filter by Transfer: Shows only transfers
- [ ] Filter by Status Change: Shows only status changes
- [ ] Unread only: Shows only unread
- [ ] All: Shows all
- [ ] Clear filter: Works
- [ ] Search: Finds by token number and message

### 5.5 CRUD Operations Testing
- [ ] Mark as read: Updates badge, updates in list
- [ ] Mark all as read: All notifications marked
- [ ] Delete single: Removed from list
- [ ] Delete all: List empty, badge 0
- [ ] Refresh: Syncs with database

### 5.6 Admin Access Testing
- [ ] Login as admin
- [ ] Can see all staff notifications
- [ ] Can't see other admin's notifications (RLS should block)
- [ ] Can delete any notification

### 5.7 Security Testing (Important!)
- [ ] Staff can't view other staff's notifications
  ```sql
  -- Try manual query with wrong user_id
  SELECT * FROM staff_notifications 
  WHERE staff_id != auth.uid();
  -- Should return 0 rows (RLS blocks)
  ```

- [ ] Staff can only mark their own as read
- [ ] Staff can only delete their own

### 5.8 Database Testing
- [ ] Triggers fire correctly
- [ ] Notifications created with correct data
- [ ] No duplicate notifications
- [ ] Timestamps correct
- [ ] Room/staff names populated correctly

---

## Step 6: Performance & Optimization (10 minutes)

### 6.1 Database Performance
- [ ] Check trigger execution time (should be < 100ms)
  ```sql
  -- Supabase Log: Look for trigger durations
  ```

- [ ] Monitor database size
  ```sql
  SELECT COUNT(*) FROM staff_notifications;
  ```

- [ ] Consider archiving notifications > 30 days (optional)

### 6.2 App Performance
- [ ] Notification list loads quickly
- [ ] Filtering is instant
- [ ] Search is responsive
- [ ] No memory leaks
  - [ ] Initialize/dispose properly
  - [ ] Cancel subscriptions on logout

### 6.3 Network Performance
- [ ] Real-time updates are instant (< 1 second)
- [ ] Works on 4G/LTE networks
- [ ] Works on WiFi
- [ ] Handles reconnection gracefully

---

## Step 7: Production Readiness (15 minutes)

### 7.1 Code Quality
- [ ] No debug print statements left (remove or guard with kDebugMode)
- [ ] No console errors
- [ ] No warnings in analysis
- [ ] All imports used
- [ ] Proper error handling

### 7.2 Documentation
- [ ] Comments in code explain complex logic
- [ ] README updated with notification feature
- [ ] Team documentation shared
- [ ] API endpoints documented

### 7.3 Monitoring
- [ ] Set up Supabase monitoring/alerts
- [ ] Monitor trigger performance
- [ ] Monitor database growth
- [ ] Monitor error rates

### 7.4 Backup
- [ ] Database backup created
- [ ] SQL script backed up
- [ ] Code committed to version control
- [ ] Documentation version controlled

---

## Step 8: Training & Rollout (Optional)

### 8.1 Team Training
- [ ] Show staff how to use notifications
- [ ] Explain what each notification type means
- [ ] Show filtering/search features
- [ ] Explain real-time updates

### 8.2 Rollout Plan
- [ ] Deploy to test users first
- [ ] Get feedback
- [ ] Make adjustments if needed
- [ ] Roll out to all users

---

## Post-Implementation Checks

### Daily (First Week)
- [ ] Monitor error logs
- [ ] Check if notifications are being created
- [ ] Verify staff are seeing them
- [ ] Check database performance

### Weekly
- [ ] Review unread notification count
- [ ] Check for any stuck notifications
- [ ] Monitor database size growth
- [ ] Review user feedback

### Monthly
- [ ] Archive old notifications (if desired)
- [ ] Review notification statistics
- [ ] Optimize if needed
- [ ] Plan enhancements

---

## Troubleshooting Checklist

If something doesn't work:

### No Notifications Appearing
- [ ] SQL script ran successfully (check for errors)
- [ ] staff_notifications table exists: 
  ```sql
  SELECT * FROM staff_notifications LIMIT 1;
  ```
- [ ] RLS policies enabled:
  ```sql
  SELECT relrowsecurity FROM pg_class 
  WHERE relname = 'staff_notifications';
  ```
- [ ] User has correct role (staff/admin)
- [ ] Supabase real-time enabled in project settings
- [ ] Check browser console for errors

### Real-Time Not Working
- [ ] Supabase real-time is enabled
- [ ] Internet connection is active
- [ ] Browser not blocking WebSockets
- [ ] Try refreshing page
- [ ] Check Supabase status page

### High Database Load
- [ ] Check trigger performance in logs
- [ ] Consider archiving old notifications
- [ ] Review database statistics
- [ ] Contact Supabase support if needed

### Permissions Errors
- [ ] Verify RLS policies were created
- [ ] Check user role in profiles table
- [ ] Verify authenticated session
- [ ] Try logging out and in again

---

## Success Criteria

Your implementation is successful when:

✅ Staff receives notification when token is transferred to their room
✅ Notification appears within 1 second (no refresh needed)
✅ Notification shows: token number, previous room, new room, time
✅ Staff can filter notifications by type
✅ Staff can mark notifications as read
✅ Staff can delete notifications
✅ Unread count badge displays and updates
✅ Admin can see all notifications
✅ Regular staff can only see their own notifications
✅ Database shows no errors in logs
✅ Notifications work on multiple devices simultaneously

---

## When Everything Works! 🎉

You now have a complete real-time notification system that:
- Automatically notifies staff when tokens arrive
- Sends notifications in real-time (WebSocket)
- Stores notification history
- Provides filtering and search
- Ensures security with RLS
- Scales reliably

Congratulations! 🎊
