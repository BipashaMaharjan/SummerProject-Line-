# Real-Time Notification System - Architecture & Diagrams

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        FLUTTER APPLICATION                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    PRESENTATION LAYER                        │  │
│  ├──────────────────────────────────────────────────────────────┤  │
│  │                                                              │  │
│  │  NotificationCenterScreen          StaffDashboard           │  │
│  │  ┌─────────────────────────┐    ┌──────────────────┐        │  │
│  │  │ • Notification list     │    │ • Badge (unread) │        │  │
│  │  │ • Filter bar            │    │ • Recent preview │        │  │
│  │  │ • Statistics            │    │ • Quick actions  │        │  │
│  │  │ • Mark as read/delete   │    │ • Integration    │        │  │
│  │  └─────────────────────────┘    └──────────────────┘        │  │
│  │                                                              │  │
│  │  UI Components                                              │  │
│  │  ┌────────────────────────────────────────────────────────┐ │  │
│  │  │ NotificationCard  NotificationListView  FilterBar    │ │  │
│  │  │ NotificationBadge                                    │ │  │
│  │  └────────────────────────────────────────────────────────┘ │  │
│  │                                                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                           ↓                                         │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    STATE MANAGEMENT LAYER                   │  │
│  ├──────────────────────────────────────────────────────────────┤  │
│  │                                                              │  │
│  │  NotificationHistoryProvider (Provider Pattern)             │  │
│  │  ┌──────────────────────────────────────────────────────┐   │  │
│  │  │ • List<TokenNotification> _notifications            │   │  │
│  │  │ • Stream subscription to real-time updates          │   │  │
│  │  │ • Filtering (type, unread)                          │   │  │
│  │  │ • Search functionality                              │   │  │
│  │  │ • Statistics calculations                           │   │  │
│  │  │ • CRUD operations                                   │   │  │
│  │  └──────────────────────────────────────────────────────┘   │  │
│  │                                                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                           ↓                                         │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                      SERVICES LAYER                         │  │
│  ├──────────────────────────────────────────────────────────────┤  │
│  │                                                              │  │
│  │  StaffNotificationService      TokenTransferService         │  │
│  │  ┌──────────────────────────┐  ┌─────────────────────────┐  │  │
│  │  │ • Real-time stream       │  │ • Transfer token        │  │  │
│  │  │ • Supabase subscription  │  │ • Update status         │  │  │
│  │  │ • Get notifications      │  │ • Get room/staff info   │  │  │
│  │  │ • Mark as read           │  │ • Create notifications  │  │  │
│  │  │ • Delete                 │  │ • Get next room         │  │  │
│  │  │ • Search & filter        │  │ • Admin logic           │  │  │
│  │  └──────────────────────────┘  └─────────────────────────┘  │  │
│  │                                                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                           ↓ WebSocket (Real-time Channel)         │
├─────────────────────────────────────────────────────────────────────┤
│                   SUPABASE CLIENT LIBRARY                          │
├─────────────────────────────────────────────────────────────────────┤
│                           ↓ HTTPS/WebSocket                        │
└─────────────────────────────────────────────────────────────────────┘


┌──────────────────────────────────────────────────────────────────────┐
│                    SUPABASE (PostgreSQL Backend)                     │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                     DATABASE LAYER                            │ │
│  ├────────────────────────────────────────────────────────────────┤ │
│  │                                                                │ │
│  │  staff_notifications Table (Main)                             │ │
│  │  ┌──────────────────────────────────────────────────────────┐ │ │
│  │  │ • id (UUID PK)                                           │ │ │
│  │  │ • staff_id (FK → profiles)                               │ │ │
│  │  │ • token_id (FK → tokens)                                 │ │ │
│  │  │ • token_number (TEXT)                                    │ │ │
│  │  │ • type (tokenTransfer | statusChange | ...)              │ │ │
│  │  │ • message (TEXT)                                         │ │ │
│  │  │ • previous_room_id (FK → rooms)                          │ │ │
│  │  │ • new_room_id (FK → rooms)                               │ │ │
│  │  │ • previous_status, new_status (TEXT)                     │ │ │
│  │  │ • is_read (BOOLEAN)                                      │ │ │
│  │  │ • created_at, updated_at (TIMESTAMPTZ)                   │ │ │
│  │  └──────────────────────────────────────────────────────────┘ │ │
│  │                                                                │ │
│  │  Related Tables (Referenced)                                 │ │
│  │  ┌──────────────────────────────────────────────────────────┐ │ │
│  │  │ tokens, rooms, profiles                                  │ │ │
│  │  │ (Existing tables, no modifications needed)                │ │ │
│  │  └──────────────────────────────────────────────────────────┘ │ │
│  │                                                                │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                   TRIGGERS (Automation)                       │ │
│  ├────────────────────────────────────────────────────────────────┤ │
│  │                                                                │ │
│  │  notify_on_token_transfer()                                  │ │
│  │  Trigger: AFTER UPDATE ON tokens                             │ │
│  │  ├─ Check if current_room_id changed                         │ │
│  │  ├─ Get staff for new and previous rooms                     │ │
│  │  ├─ Create notifications for new staff                       │ │
│  │  ├─ Create notifications for previous staff (if different)    │ │
│  │  └─ Create admin notifications                               │ │
│  │                                                                │ │
│  │  notify_on_token_status_change()                              │ │
│  │  Trigger: AFTER UPDATE ON tokens                             │ │
│  │  ├─ Check if status changed                                  │ │
│  │  ├─ Skip initial creation (NULL → waiting)                   │ │
│  │  ├─ Get assigned staff for token                             │ │
│  │  ├─ Create notifications for assigned staff                  │ │
│  │  └─ Create admin notifications                               │ │
│  │                                                                │ │
│  │  notify_on_token_assignment()                                 │ │
│  │  Trigger: AFTER UPDATE ON tokens                             │ │
│  │  ├─ Check if assigned_staff_id changed                       │ │
│  │  ├─ Create notification for newly assigned staff             │ │
│  │  ├─ Create notification for previous staff (if applicable)    │ │
│  │  └─ Create admin notifications                               │ │
│  │                                                                │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │              INDEXES (Performance)                            │ │
│  ├────────────────────────────────────────────────────────────────┤ │
│  │ • idx_staff_notifications_staff_id (staff_id)                 │ │
│  │ • idx_staff_notifications_token_id (token_id)                 │ │
│  │ • idx_staff_notifications_created_at (created_at DESC)        │ │
│  │ • idx_staff_notifications_is_read (is_read)                   │ │
│  │ • idx_staff_notifications_staff_created (staff_id, created_at)│ │
│  │                                                                │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │          ROW LEVEL SECURITY (RLS)                            │ │
│  ├────────────────────────────────────────────────────────────────┤ │
│  │                                                                │ │
│  │  SELECT Policy: Staff can view own notifications              │ │
│  │  INSERT Policy: System can insert (triggers)                  │ │
│  │  UPDATE Policy: Staff can update own (mark read)              │ │
│  │  DELETE Policy: Staff can delete own                          │ │
│  │                                                                │ │
│  │  Admin Role: Can see all + all operations                     │ │
│  │                                                                │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Diagram

```
                          TOKEN TRANSFER EVENT
                                  │
                                  ▼
                  ┌───────────────────────────────┐
                  │  Staff A Transfers Token      │
                  │  Current Room → Next Room     │
                  └───────────────────────────────┘
                                  │
                                  ▼
              ┌──────────────────────────────────────┐
              │ TokenTransferService.transferToken   │
              │ Updates: tokens table                │
              │ - current_room_id = NEW_ROOM         │
              │ - assigned_staff_id = NEW_STAFF      │
              │ - updated_at = NOW()                 │
              └──────────────────────────────────────┘
                                  │
                                  ▼
                        ┌──────────────────────┐
                        │ UPDATE tokens        │
                        │ WHERE id = 'xxx'     │
                        │ IN Supabase          │
                        └──────────────────────┘
                                  │
                                  ▼
                ┌─────────────────────────────────────────┐
                │ DATABASE TRIGGER FIRES                  │
                │ notify_on_token_transfer()              │
                │                                         │
                │ Actions:                                │
                │ ├─ Get new room name                    │
                │ ├─ Get previous room name               │
                │ ├─ Get new staff (by room)              │
                │ ├─ Get previous staff (by room)         │
                │ ├─ Create notification for new staff    │
                │ ├─ Create notification for old staff    │
                │ └─ Create admin notifications           │
                │                                         │
                │ INSERT INTO staff_notifications         │
                │ (staff_id, token_id, message, type...)  │
                └─────────────────────────────────────────┘
                                  │
                   ┌──────────────┴──────────────┐
                   │                             │
                   ▼                             ▼
        ┌─────────────────────┐       ┌──────────────────────┐
        │ New Staff Gets:      │       │ Previous Staff Gets: │
        │                      │       │                      │
        │ Type: tokenTransfer  │       │ Type: transferredOut │
        │ Message: "New token  │       │ Message: "Token XXX  │
        │ received — Token     │       │ has been transferred │
        │ #XXX has been        │       │ to Reception Room"   │
        │ transferred to you"  │       │                      │
        │ Token: #XXX          │       │ Token: #XXX          │
        │ Previous Room: →     │       │ New Room: ←          │
        │ New Room: ←          │       │ Previous: ←          │
        │                      │       │                      │
        └─────────────────────┘       └──────────────────────┘
                   │                             │
                   └──────────────┬──────────────┘
                                  │
                                  ▼
                   ┌─────────────────────────────┐
                   │ Supabase Real-time Event    │
                   │ Broadcast to channel:       │
                   │ 'staff_notifications_XXX'   │
                   └─────────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
                    ▼                           ▼
        ┌──────────────────────┐   ┌─────────────────────┐
        │ Staff A's App        │   │ Staff B's App       │
        │ Receives event       │   │ Receives event      │
        └──────────────────────┘   └─────────────────────┘
                    │                           │
                    ▼                           ▼
        ┌──────────────────────┐   ┌──────────────────────┐
        │ StaffNotificationSvc │   │ StaffNotificationSvc │
        │ Emits to stream      │   │ Emits to stream      │
        │ (TokenNotification)  │   │ (TokenNotification)  │
        └──────────────────────┘   └──────────────────────┘
                    │                           │
                    ▼                           ▼
        ┌──────────────────────┐   ┌──────────────────────┐
        │ NotificationHistory  │   │ NotificationHistory  │
        │ Provider             │   │ Provider             │
        │ - Add to list        │   │ - Add to list        │
        │ - notifyListeners()  │   │ - notifyListeners()  │
        │ - Update UI          │   │ - Update UI          │
        └──────────────────────┘   └──────────────────────┘
                    │                           │
                    ▼                           ▼
        ┌──────────────────────┐   ┌──────────────────────┐
        │ Staff A Sees:        │   │ Staff B Sees:        │
        │ "Token transferred"  │   │ "New token received" │
        │ notification         │   │ notification         │
        │ (Marked as read)     │   │ (Unread - highlighted)
        │                      │   │                      │
        │ Badge: -1 if had     │   │ Badge: +1            │
        └──────────────────────┘   └──────────────────────┘
                                             │
                                             ▼
                                   User taps notification
                                   Marks as read
                                   Service updates DB
                                   UI updates immediately
```

---

## State Management Data Flow

```
                    Flutter App Start
                           │
                           ▼
                  ┌──────────────────────┐
                  │ main() initializes   │
                  │ MultiProvider        │
                  └──────────────────────┘
                           │
                           ▼
                  ┌──────────────────────────────┐
                  │ User logs in                 │
                  │ AuthProvider                 │
                  │ stores: staffId, userData    │
                  └──────────────────────────────┘
                           │
                           ▼
                  ┌──────────────────────────────────┐
                  │ Post-login: Dashboard loads      │
                  │ initializeNotifications()        │
                  └──────────────────────────────────┘
                           │
                           ▼
                  ┌──────────────────────────────────────┐
                  │ NotificationHistoryProvider.init()   │
                  │ - Initialize StaffNotificationSvc    │
                  │ - Subscribe to real-time stream      │
                  │ - Load initial notifications         │
                  │ - notifyListeners()                  │
                  └──────────────────────────────────────┘
                           │
                           ▼
                  ┌──────────────────────────────────┐
                  │ UI Rebuilds (Consumers)          │
                  │ - Notification list displays     │
                  │ - Badge shows count              │
                  │ - Filter options available       │
                  └──────────────────────────────────┘
                           │
                ┌──────────┴───────────┬──────────────┐
                │                      │              │
                ▼                      ▼              ▼
         User taps      User applies   New real-time
         notification   filter         notification
         arrives
                │              │              │
                ▼              ▼              ▼
         Mark as read   Update _selectedFilter   StaffNotificationSvc
         Update DB      notifyListeners()        Receives via stream
         notifyListeners()  UI filters list       Emits to controller
                │              │                      │
                ▼              ▼                      ▼
         Filter removed   Filtered view   NotificationHistoryProvider
         Show badge-1     shows           Add to _notifications
                          filtered only   notifyListeners()
                                               │
                                               ▼
                                          UI Rebuilds
                                          Shows new notification
                                          Badge +1
                                          List updates
```

---

## Database Event Cascade

```
                    SINGLE UPDATE STATEMENT
                    ┌──────────────────────────┐
                    │ UPDATE tokens SET        │
                    │ current_room_id = 'id'   │
                    │ WHERE id = 'token-id'    │
                    └──────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
    ┌──────────────────┐┌──────────────┐┌─────────────────┐
    │ Trigger 1        ││ Trigger 2    ││ Trigger 3       │
    │ Token Transfer   ││ Status Change││ Assignment      │
    │                  ││              ││                 │
    │ Fires if:        ││ Fires if:    ││ Fires if:       │
    │ room_id changed  ││ status       ││ assigned_staff  │
    │                  ││ changed      ││ changed         │
    └──────────────────┘└──────────────┘└─────────────────┘
              │                │                │
    ┌─────────┴─────────────────┼────────────────┴──────┐
    │                           │                       │
    ▼                           ▼                       ▼
 INSERT 1-3             INSERT 1-3                 INSERT 1-2
 notifications         notifications              notifications
 for staff             for staff                  for staff
    │                       │                         │
    ├─ New staff        ├─ Assigned staff       ├─ New assigned
    ├─ Old staff        └─ All admins           ├─ Old assigned
    └─ All admins                               └─ All admins
                                                     │
                                    ┌────────────────┴──────────┐
                                    │                           │
                                    ▼                           ▼
                            Total: 2-9 new rows          All inserted with:
                            in staff_notifications    ├─ staff_id (recipient)
                            table                     ├─ token_id
                                                      ├─ message
                                                      ├─ type
                                                      ├─ room info
                                                      ├─ status info
                                                      ├─ is_read = false
                                                      └─ created_at = NOW()
                                                           │
                                                           ▼
                                                  Real-time Event Published
                                                  WebSocket Broadcast
                                                  To subscribed clients
```

---

## Class Relationship Diagram

```
                                  ┌──────────────────────┐
                                  │ TokenNotification    │
                                  ├──────────────────────┤
                                  │ - id: String         │
                                  │ - tokenId: String    │
                                  │ - tokenNumber: String│
                                  │ - type: NotificationType
                                  │ - message: String    │
                                  │ - previousRoomId     │
                                  │ - newRoomId          │
                                  │ - previousStatus     │
                                  │ - newStatus          │
                                  │ - isRead: bool       │
                                  │ - createdAt: DateTime│
                                  └──────────────────────┘
                                          ▲
                                          │ used by
                  ┌───────────────────────┼───────────────────┐
                  │                       │                   │
                  ▼                       ▼                   ▼
    ┌──────────────────────┐  ┌────────────────────────┐ ┌─────────────┐
    │ StaffNotification    │  │ NotificationHistory    │ │ UI Components
    │ Service              │  │ Provider               │ │ (Widgets)
    ├──────────────────────┤  ├────────────────────────┤ ├─────────────┤
    │ - initialize()       │  │ - notifications: List  │ │ - NotCard
    │ - markAsRead()       │  │ - unreadCount: int     │ │ - NotList
    │ - markAllAsRead()    │  │ - selectedFilter       │ │ - FilterBar
    │ - deleteNotif()      │  │ - showUnreadOnly       │ │ - Badge
    │ - getUnreadCount()   │  │                        │ │ - Center
    │ - getByType()        │  │ - initialize()         │ │
    │ - getRecent()        │  │ - setTypeFilter()      │ │
    │ - getUnread()        │  │ - toggleUnreadOnly()   │ │
    │                      │  │ - getStatistics()      │ │
    │ - notificationStream │  │ - search()             │ │
    │   (Stream<Token      │  │ - refresh()            │ │
    │    Notification>)    │  │ - dispose()            │ │
    └──────────────────────┘  └────────────────────────┘ └─────────────┘
            △                           △                      △
            │ uses                      │ uses                 │ uses
            │                           │                      │
            │ Supabase                  │ StaffNotification    │ Provider
            │ client                    │ Service              │
            │                           │                      │
            └───────────────┬───────────┴──────────────────────┘
                            │
                    ┌───────┴──────┐
                    │              │
                    ▼              ▼
            ┌─────────────┐ ┌────────────────┐
            │ Token       │ │ TokenTransfer  │
            │ Transfer    │ │ Service        │
            │ Service     │ ├────────────────┤
            │             │ │ - transferToken
            │             │ │ - updateStatus
            │             │ │ - getNextRoom
            │             │ │ - notify()
            │             │ └────────────────┘
            └─────────────┘
                    │
                    ▼
            ┌──────────────────┐
            │ Supabase DB      │
            │ staff_notifications
            │ tokens           │
            │ rooms            │
            │ profiles         │
            └──────────────────┘
```

---

## Sequence Diagram: Token Transfer with Notifications

```
Staff A          Supabase         Triggers         Staff B's App
(UI)            (Database)       (PL/pgSQL)       (Real-time)
│                  │                  │                  │
│ Transfer Token   │                  │                  │
├─ tokenId        │                  │                  │
├─ newRoomId      │                  │                  │
└─ newStaffId ────>│                  │                  │
                   │                  │                  │
                   │ UPDATE tokens    │                  │
                   │ current_room_id  │                  │
                   │ assigned_staff   │                  │
                   │ status = waiting │                  │
                   ├─────────────────>│                  │
                   │                  │                  │
                   │                  │ Query rooms      │
                   │                  │ Query staff      │
                   │                  │ Build message    │
                   │                  │                  │
                   │<─────────────────┤                  │
                   │                  │                  │
                   │ INSERT 3-4       │                  │
                   │ notifications    │                  │
                   │ (staff, prev, adm│                  │
                   ├─────────────────>│                  │
                   │                  │                  │
                   │ BROADCAST Event  │                  │
                   │ type: INSERT     │                  │
                   │ staff_noti.      │                  │
                   │─────────────────────────────────────>│
                   │                  │                  │
                   │                  │                  │ StaffNotif
                   │                  │                  │ Service
                   │                  │                  │ receives
                   │                  │                  │
                   │                  │                  │ Emit stream
                   │                  │                  │ TokenNotif
                   │                  │                  │
                   │<─────────────────────────────────────┤
                   │                  │                  │
                   │                  │                  │ Provider
                   │                  │                  │ receives
                   │                  │                  │ Add to list
                   │                  │                  │ notify()
                   │                  │                  │
                   │                  │                  │ Rebuild UI
                   │                  │                  │ Show card
                   │                  │                  │ Update badge
                   │                  │                  │
                   │                  │                  │ "New token!"
                   │                  │                  │ Toast/badge
                   │                  │                  │
```

---

## Component Integration Points

```
┌─────────────────────────────────────────────────────────────────────┐
│                         YOUR APP                                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Login Screen                                                        │
│  └─> Call after successful auth:                                    │
│      ├─ context.read<NotificationHistoryProvider>()                │
│      │  .initialize(staffId)                                       │
│      │                                                              │
│      └─ context.read<TokenTransferService>()                       │
│         .initialize()                                              │
│                                                                      │
│  Dashboard/Home Screen                                             │
│  ├─ Add NotificationBadge to AppBar                                │
│  │  └─ Shows unread count                                          │
│  │     └─ Updates in real-time                                     │
│  │                                                                  │
│  └─ Add notification preview card                                  │
│     └─ Shows recent unread notifications                           │
│        └─ Real-time updates                                        │
│                                                                      │
│  Token Operations Screen                                           │
│  ├─ When transferring token:                                       │
│  │  └─ Call TokenTransferService.transferTokenToRoom()             │
│  │     └─ Service creates notifications automatically              │
│  │        └─ Staff receive instantly                               │
│  │                                                                  │
│  └─ When updating status:                                          │
│     └─ Call TokenTransferService.updateTokenStatus()               │
│        └─ Service creates notifications automatically              │
│           └─ Staff receive instantly                               │
│                                                                      │
│  Navigation/Router                                                 │
│  ├─ Add route to NotificationCenterScreen:                         │
│  │  └─ path: '/notifications'                                      │
│  │  └─ builder: () => const NotificationCenterScreen()            │
│  │                                                                  │
│  └─ Link from badge or menu:                                       │
│     └─ onTap: () => context.go('/notifications')                  │
│                                                                      │
│  Admin Dashboard                                                    │
│  └─ Add admin notification center                                  │
│     └─ Filter by type                                              │
│     └─ View all staff notifications                                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

This documentation provides complete visual understanding of how the notification system is architected and how data flows through it.
