# Real-Time Notification System - Implementation Guide

## 📋 Overview

This guide explains how to implement the real-time notification system for token transfers and status changes in your Digital Queue Management system.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│          Flutter App (Staff/Admin)                   │
├─────────────────────────────────────────────────────┤
│  NotificationHistoryProvider (State Management)      │
│  StaffNotificationService (Real-time Listener)       │
│  TokenTransferService (Token Operations)             │
└────────────────┬────────────────────────────────────┘
                 │
          Real-time Channel
                 │
┌─────────────────────────────────────────────────────┐
│           Supabase (PostgreSQL)                      │
├─────────────────────────────────────────────────────┤
│  staff_notifications table                           │
│  tokens table + triggers                             │
│  rooms table                                         │
│  profiles table                                      │
└─────────────────────────────────────────────────────┘
```

## 📦 Components

### 1. Models
- **TokenNotification** (`lib/models/notification.dart`)
  - Represents a single notification
  - Contains token info, room transitions, status changes
  - Supports filtering and display formatting

### 2. Services

#### StaffNotificationService (`lib/services/staff_notification_service.dart`)
Real-time listener for staff notifications
```dart
// Initialize
final service = StaffNotificationService();
await service.initialize(staffId);

// Listen to notifications
service.notificationStream.listen((notification) {
  // Handle notification
});

// Get notifications
final unread = await service.getUnreadNotifications();
final byType = await service.getNotificationsByType(NotificationType.tokenTransfer);

// Update status
await service.markAsRead(notificationId);
await service.markAllAsRead();
```

#### TokenTransferService (`lib/services/token_transfer_service.dart`)
Handle token operations with automatic notifications
```dart
final transferService = TokenTransferService();
await transferService.initialize();

// Transfer token to new room
await transferService.transferTokenToRoom(
  tokenId: 'token-123',
  tokenNumber: 'A-001',
  newRoomId: 'room-456',
  newRoomName: 'Registration',
  previousRoomId: 'room-123',
  previousRoomName: 'Reception',
  currentStaffId: 'staff-789',
);

// Update token status
await transferService.updateTokenStatus(
  tokenId: 'token-123',
  tokenNumber: 'A-001',
  newStatus: TokenStatus.processing,
  currentRoomName: 'Registration',
  currentStaffId: 'staff-789',
);
```

### 3. Providers

#### NotificationHistoryProvider (`lib/providers/notification_history_provider.dart`)
Manages notification state with filtering and real-time sync
```dart
// Initialize in your app
final provider = context.read<NotificationHistoryProvider>();
await provider.initialize(staffId);

// Use in widgets
Consumer<NotificationHistoryProvider>(
  builder: (context, provider, _) {
    return ListView.builder(
      itemCount: provider.notifications.length,
      itemBuilder: (context, index) {
        final notification = provider.notifications[index];
        // Build UI
      },
    );
  },
);

// Filter by type
provider.setTypeFilter(NotificationType.tokenTransfer);
provider.clearTypeFilter();

// Toggle unread filter
provider.toggleUnreadOnly();

// Get statistics
final stats = provider.getStatistics();
// Returns: {total: 25, unread: 3, transfers: 10, ...}
```

### 4. UI Components

#### NotificationCard (`lib/widgets/notification_widgets.dart`)
Displays individual notifications with action buttons
```dart
NotificationCard(
  notification: notification,
  onTap: () { /* Mark as read */ },
  onDismiss: () { /* Delete */ },
)
```

#### NotificationListView
Shows list of notifications with refresh
```dart
NotificationListView(
  onNotificationTap: (notification) {
    // Handle tap
  },
)
```

#### NotificationFilterBar
Filter notifications by type
```dart
const NotificationFilterBar()
```

#### NotificationBadge
Shows unread count badge
```dart
NotificationBadge(
  child: IconButton(icon: Icon(Icons.notifications)),
)
```

#### NotificationCenterScreen
Full notification center screen
```dart
const NotificationCenterScreen()
```

## 🚀 Integration Steps

### Step 1: Database Setup
Run the SQL script to create the notification system:
```sql
-- File: z/REALTIME_NOTIFICATIONS_SETUP.sql
-- This creates:
// - staff_notifications table
// - RLS policies
// - Triggers for token transfers
// - Triggers for status changes
// - Triggers for assignments
```

**Run in Supabase SQL Editor:**
1. Go to your Supabase project
2. Navigate to SQL Editor
3. Copy the entire content of `REALTIME_NOTIFICATIONS_SETUP.sql`
4. Execute it

### Step 2: Update pubspec.yaml
Ensure you have these dependencies (already included):
```yaml
supabase_flutter: ^2.5.6
provider: ^6.1.2
flutter_local_notifications: ^17.2.1+2
```

### Step 3: Update main.dart
Add providers to your app:
```dart
import 'package:provider/provider.dart';
import 'providers/notification_history_provider.dart';

// In your MultiProvider
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => NotificationHistoryProvider()),
    // ... other providers
  ],
  child: MyApp(),
)
```

### Step 4: Initialize in Auth Screen
After successful login:
```dart
final authProvider = context.read<AuthProvider>();
final notificationProvider = context.read<NotificationHistoryProvider>();

// After login
await notificationProvider.initialize(authProvider.currentStaffId);
```

### Step 5: Add to Your UI

#### Option A: Notification Center Screen
Add route to your navigation:
```dart
// In your go_router configuration
GoRoute(
  path: '/notifications',
  builder: (context, state) => const NotificationCenterScreen(),
),
```

#### Option B: Notification Badge
Add badge to app bar:
```dart
AppBar(
  title: const Text('Staff Dashboard'),
  actions: [
    NotificationBadge(
      child: IconButton(
        icon: const Icon(Icons.notifications),
        onPressed: () => context.go('/notifications'),
      ),
    ),
  ],
)
```

#### Option C: Notification List in Sidebar
```dart
Expanded(
  child: Consumer<NotificationHistoryProvider>(
    builder: (context, provider, _) {
      if (!provider.isInitialized) {
        return const Center(child: CircularProgressIndicator());
      }

      return NotificationListView(
        onNotificationTap: (notification) {
          // Navigate based on notification
        },
      );
    },
  ),
)
```

### Step 6: Using Token Transfer Service

#### When Staff Transfers Token:
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
    const SnackBar(content: Text('Token transferred successfully')),
  );
}
```

#### When Staff Updates Token Status:
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

## 📊 Notification Types

| Type | When Triggered | Recipients | Icon |
|------|---|---|---|
| `tokenTransfer` | Token moved to new room | New staff member, Admin | → |
| `statusChange` | Token status updated | Assigned staff, Admin | 🔄 |
| `tokenAssigned` | Token assigned to staff | Assigned staff, Admin | ✅ |
| `transferredOut` | Token moved from staff's queue | Previous staff | ➡️ |
| `admin` | Any token operation | All admins | 👨‍💼 |

## 🔄 Real-Time Flow

```
Staff A in Room 1          Token Status Change         Staff B in Room 2
         │                          │                           │
         │─ transferTokenToRoom ───→│                           │
         │                          │                           │
         │                   [Trigger fires]                    │
         │                          │                           │
         │                   [DB updates]                       │
         │                          │                           │
         │    [Notification created for B]────────→ [Receives Real-time Update]
         │    [Notification created for A]                      │
         │    [Admin notifications]                             │
         │                          │                           │
         │                  [Message sent via                   │
         │                   WebSocket channel]                 │
         │                          │                           │
         │←─────── [Stream emits]──────────────────→ [UI updates]
         │
    [Badge shows +1]         [Real-time sync]        [Notification shown]
```

## 🔐 Security

### Row Level Security (RLS)
- Staff can only view their own notifications
- Admins can view all notifications
- System can insert notifications (security definer)
- Staff can mark their own as read/delete

### Database Triggers
- Automatically trigger on token updates
- Run with SECURITY DEFINER to ensure permissions
- No direct staff manipulation possible

## ⚙️ Configuration

### Notification Retention
By default, notifications are kept for 30 days. Modify in `cleanup_old_notifications()`:
```sql
WHERE created_at < NOW() - INTERVAL '30 days'
-- Change to: '90 days', '7 days', etc.
```

### Disable Notifications for Testing
Comment out triggers temporarily:
```sql
-- DROP TRIGGER IF EXISTS trg_notify_on_token_transfer ON tokens;
```

## 🧪 Testing

### 1. Test Database Setup
```sql
-- Check table exists
SELECT * FROM staff_notifications LIMIT 1;

-- Check triggers exist
SELECT trigger_name FROM information_schema.triggers
WHERE table_name = 'tokens';

-- Test manual notification
INSERT INTO staff_notifications (
  staff_id, token_id, token_number, type, message, is_read
) VALUES (
  'staff-uuid', 'token-uuid', 'A-001', 'statusChange', 'Test message', false
);
```

### 2. Test Flutter App
```dart
// Add to your widget
Consumer<NotificationHistoryProvider>(
  builder: (context, provider, _) {
    return Column(
      children: [
        Text('Total: ${provider.allNotifications.length}'),
        Text('Unread: ${provider.unreadCount}'),
        NotificationListView(),
      ],
    );
  },
)
```

### 3. Manual Test Workflow
1. Login as Staff A
2. Create a token
3. Transfer token to next room
4. Observe notification in Staff B's app
5. Check notification center
6. Mark as read
7. Verify unread count updates

## 📱 Mobile Considerations

### Local Notifications
For foreground notifications, use `NotificationService`:
```dart
await NotificationService().showNotification(
  id: notification.id.hashCode,
  title: notification.displayTitle,
  body: notification.message,
  payload: 'token:${notification.tokenNumber}',
);
```

### Offline Support
Notifications are stored in Supabase. When reconnected:
1. App syncs with database
2. Missing notifications are fetched
3. UI updates automatically

### Background Notifications
When app is closed, notifications are queued in Supabase and fetched when reopened.

## 🐛 Troubleshooting

### Notifications Not Appearing
1. Check RLS policies are enabled
2. Verify user has `staff` or `admin` role
3. Check triggers are active: `SELECT trigger_name FROM ...`
4. Look for errors in Supabase logs

### Real-time Not Working
1. Verify Supabase real-time is enabled
2. Check internet connection
3. Confirm channel subscription is active
4. Check browser console for errors

### High Database Load
1. Increase cleanup interval (delete old notifications)
2. Archive old notifications to separate table
3. Add database connection pooling

## 📞 Support

For issues or questions:
1. Check Supabase logs: Project → Logs
2. Verify RLS policies: Auth → Policies
3. Test triggers: Run manual test queries
4. Check Flutter debug output

## 🎯 Next Steps

1. **Email Notifications** - Send email summaries
2. **Push Notifications** - FCM for mobile
3. **Webhook Integrations** - Notify external systems
4. **Analytics Dashboard** - Track notification metrics
5. **Notification Templates** - Customize messages
