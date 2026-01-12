# Real-Time Notifications - Quick Start Guide

## 5-Minute Setup

### 1. Database (1 minute)
```sql
-- Run this in Supabase SQL Editor
-- File: z/REALTIME_NOTIFICATIONS_SETUP.sql
```

### 2. Code Setup (2 minutes)

**In main.dart:**
```dart
import 'package:provider/provider.dart';
import 'providers/notification_history_provider.dart';

MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => NotificationHistoryProvider()),
  ],
  child: MyApp(),
)
```

**After login:**
```dart
await context.read<NotificationHistoryProvider>().initialize(staffId);
```

### 3. Add UI (2 minutes)

**Add notification center to your routing:**
```dart
GoRoute(
  path: '/notifications',
  builder: (context, state) => const NotificationCenterScreen(),
),

// Or add badge to app bar
NotificationBadge(
  child: IconButton(
    icon: const Icon(Icons.notifications),
    onPressed: () => context.go('/notifications'),
  ),
)
```

**Or show notifications list:**
```dart
NotificationFilterBar(),
NotificationListView(),
```

Done! ✅

---

## Common Usage Examples

### Transfer Token
```dart
final service = TokenTransferService();
await service.initialize();

await service.transferTokenToRoom(
  tokenId: token.id,
  tokenNumber: token.tokenNumber,
  newRoomId: nextRoom.id,
  newRoomName: nextRoom.name,
  previousRoomId: currentRoom.id,
  previousRoomName: currentRoom.name,
  currentStaffId: currentStaffId,
);
// ✅ Notifications automatically created
```

### Update Status
```dart
await service.updateTokenStatus(
  tokenId: token.id,
  tokenNumber: token.tokenNumber,
  newStatus: TokenStatus.processing,
  currentRoomName: currentRoom.name,
  currentStaffId: currentStaffId,
);
// ✅ Notifications automatically created
```

### Show Unread Count
```dart
Consumer<NotificationHistoryProvider>(
  builder: (context, provider, _) {
    return Text('Unread: ${provider.unreadCount}');
  },
)
```

### Filter Notifications
```dart
Consumer<NotificationHistoryProvider>(
  builder: (context, provider, _) {
    // By type
    provider.setTypeFilter(NotificationType.tokenTransfer);
    
    // Unread only
    provider.toggleUnreadOnly();
    
    // Get filtered list
    return ListView(
      children: provider.notifications.map((n) => 
        NotificationCard(notification: n)
      ).toList(),
    );
  },
)
```

### Search Notifications
```dart
final results = provider.search('token number or message');
```

### Get Statistics
```dart
final stats = provider.getStatistics();
// Returns: {
//   'total': 25,
//   'unread': 3,
//   'transfers': 10,
//   'status_changes': 8,
//   'assignments': 4,
//   'transferred_out': 0,
//   'admin': 0,
// }
```

---

## Notification Types Quick Reference

| Type | Emoji | When | Who Gets It |
|------|-------|------|------------|
| Transfer | → | Token moves to new room | New staff, admins |
| Status Change | 🔄 | Token status updated | Assigned staff, admins |
| Assigned | ✅ | Token assigned to staff | New staff, admins |
| Transferred Out | ➡️ | Token leaves staff queue | Previous staff |
| Admin | 👨‍💼 | Any significant event | All admins |

---

## File Structure

```
lib/
├── models/
│   └── notification.dart          # TokenNotification model
├── services/
│   ├── staff_notification_service.dart      # Real-time listener
│   └── token_transfer_service.dart          # Token operations
├── providers/
│   └── notification_history_provider.dart   # State management
├── widgets/
│   └── notification_widgets.dart    # UI components
└── screens/
    └── notification_center_screen.dart  # Full notification center

z/
└── REALTIME_NOTIFICATIONS_SETUP.sql # Database schema
```

---

## Real-Time Updates

All updates happen automatically:

1. **Staff A** transfers token → Database updated
2. **Trigger fires** → Notifications created
3. **Real-time event** → Sent to all connected users
4. **Staff B receives** → Notification appears instantly (no refresh needed)

---

## Permissions

| User Type | Can Do |
|-----------|--------|
| Staff | See own notifications, mark read, delete |
| Admin | See all notifications, mark read, delete |
| Customer | See token status (in separate service) |

---

## Customization

### Change Notification Message
Edit in `token_transfer_service.dart`:
```dart
message: 'Custom message here — Token #$tokenNumber ...'
```

### Customize UI Colors
Edit in `notification_widgets.dart`:
```dart
Color _getTypeColor(NotificationType type) {
  switch (type) {
    case NotificationType.tokenTransfer:
      return Colors.orange[100]!; // Change here
    // ...
  }
}
```

### Adjust Notification Retention
Edit in SQL:
```sql
WHERE created_at < NOW() - INTERVAL '30 days'
-- Change '30 days' to desired retention period
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Notifications not appearing | Run SQL setup script again |
| Real-time not working | Check Supabase real-time is enabled |
| High database load | Run cleanup query, archive old notifications |
| User sees others' notifications | Check RLS policies (should be fixed by SQL script) |

---

## Performance Tips

1. **Limit notification list** to 50 recent items
2. **Archive old notifications** after 90 days
3. **Use indexes** (created automatically)
4. **Batch insert** when creating many notifications
5. **Lazy load** notification details on demand

---

## Testing Checklist

- [ ] Database setup script runs without errors
- [ ] Notifications table created with correct schema
- [ ] RLS policies enabled
- [ ] Triggers are active
- [ ] NotificationHistoryProvider initializes correctly
- [ ] Real-time stream receives updates
- [ ] UI shows notifications in real-time
- [ ] Filtering works (by type, unread)
- [ ] Mark as read updates database
- [ ] Delete removes notification
- [ ] Unread badge shows correct count
- [ ] Admin can see all notifications
- [ ] Staff can only see own notifications

---

## What's Included

✅ Real-time notification system  
✅ Database triggers for automatic notifications  
✅ Flutter state management with Provider  
✅ Full UI components and screens  
✅ Notification filtering and search  
✅ RLS security policies  
✅ Offline support  
✅ Complete documentation  

---

## Need Help?

1. Check `REALTIME_NOTIFICATIONS_IMPLEMENTATION.md` for detailed guide
2. Review example code in service files
3. Check Supabase documentation for RLS policies
4. Verify database triggers are active in Supabase

---

**Status: Ready to Use** ✅
