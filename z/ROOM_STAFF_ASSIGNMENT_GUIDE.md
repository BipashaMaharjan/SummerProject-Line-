# 🏢 Room-Based Staff Assignment System

## Overview

This system implements **department-based queue flow** where each room has assigned staff, and tokens are automatically assigned to the appropriate staff when transferred between rooms.

## 🎯 Key Features

### 1. **Room-Specific Staff Assignment**
- Each room can have one or more assigned staff members
- Staff only see tokens assigned to their room
- Tokens are auto-assigned when transferred

### 2. **Targeted Notifications**
- **Current Room Staff**: "✅ Ticket successfully transferred to Room 2"
- **Next Room Staff**: "New ticket received — Token #A104 has been assigned to you"
- No global notifications - only relevant staff are notified

### 3. **Real-Time Updates**
- Both dashboards update instantly
- Token status changes automatically
- Assignment happens seamlessly

## 📋 Setup Instructions

### Step 1: Run Database Setup Script

```sql
-- Run this in Supabase SQL Editor
-- File: setup_room_staff_assignment.sql
```

This script will:
1. Add `assigned_staff_id` column to `tokens` table
2. Add `assigned_room_id` column to `profiles` table
3. Create `staff_notifications` table
4. Create `get_room_staff()` function
5. Create auto-assignment trigger
6. Set up RLS policies

### Step 2: Assign Staff to Rooms

```sql
-- Get your staff user IDs first
SELECT user_id, full_name, email 
FROM profiles 
WHERE role = 'staff';

-- Then assign each staff to their room
-- Example: Assign staff to Room 1 (Reception)
UPDATE profiles 
SET assigned_room_id = 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79360'
WHERE user_id = 'YOUR_STAFF_USER_ID_HERE' AND role = 'staff';

-- Repeat for each room
```

### Step 3: Verify Setup

```sql
-- Check staff-room assignments
SELECT 
  r.name as room_name,
  r.room_number,
  p.full_name as assigned_staff,
  p.user_id as staff_id
FROM rooms r
LEFT JOIN profiles p ON p.assigned_room_id = r.id AND p.role = 'staff'
ORDER BY r.room_number;
```

## 🔄 How It Works

### Transfer Flow

```
┌─────────────────────────────────────────────────────────┐
│ ROOM 1 (Reception) - Staff: John                       │
│ Token #A104 is being processed                         │
└─────────────────────────────────────────────────────────┘
                         │
                         │ Staff clicks "Transfer"
                         ▼
┌─────────────────────────────────────────────────────────┐
│ SYSTEM ACTIONS:                                         │
│ 1. Update token.current_room_id = Room 2               │
│ 2. Fetch staff assigned to Room 2 (get_room_staff)     │
│ 3. Update token.assigned_staff_id = Room 2 Staff ID    │
│ 4. Set token.status = 'waiting'                        │
│ 5. Create notification for Room 2 staff                │
│ 6. Record in token_history                             │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│ ROOM 1 STAFF (John) SEES:                               │
│ ✅ "Ticket successfully transferred to Room 2"          │
│ "Assigned to: Sarah"                                    │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│ ROOM 2 (Document Verification) - Staff: Sarah          │
│ 🔔 NOTIFICATION:                                        │
│ "New ticket received — Token #A104 has been            │
│  assigned to you."                                      │
│                                                         │
│ Token appears in Sarah's queue instantly                │
└─────────────────────────────────────────────────────────┘
```

### Database Trigger Logic

```sql
-- Automatic assignment happens via trigger
CREATE TRIGGER trigger_assign_token_to_room_staff
  BEFORE UPDATE ON tokens
  FOR EACH ROW
  EXECUTE FUNCTION assign_token_to_room_staff();

-- Function logic:
1. Detect when current_room_id changes
2. Get staff assigned to new room
3. Set assigned_staff_id automatically
4. Create notification for that staff
```

## 📊 Database Schema

### tokens table (updated)
```sql
- id: UUID
- token_number: TEXT
- current_room_id: UUID → rooms(id)
- assigned_staff_id: UUID → auth.users(id)  ← NEW
- status: TEXT ('waiting', 'processing', 'completed', etc.)
- ...
```

### profiles table (updated)
```sql
- user_id: UUID
- full_name: TEXT
- role: TEXT ('customer', 'staff', 'admin')
- assigned_room_id: UUID → rooms(id)  ← NEW
- ...
```

### staff_notifications table (new)
```sql
- id: UUID
- staff_id: UUID → auth.users(id)
- token_id: UUID → tokens(id)
- message: TEXT
- type: TEXT ('assigned', 'transfer_in', 'transfer_out')
- is_read: BOOLEAN
- created_at: TIMESTAMPTZ
```

## 🎨 UI Changes

### Transfer Success Message

**Before:**
```
✅ Transferred to Document Verification
Token is now in Document Verification queue
```

**After:**
```
✅ Ticket successfully transferred to Document Verification
Assigned to: Sarah Johnson
```

### Notification Display (Next Room Staff)

```
┌─────────────────────────────────────────────┐
│ 🔔 Notifications                            │
├─────────────────────────────────────────────┤
│ New ticket received — Token #A104 has been │
│ assigned to you.                            │
│ Just now                                    │
└─────────────────────────────────────────────┘
```

## 🔍 Staff Dashboard Filtering

### Option 1: Show Only Assigned Tokens (Recommended)
```dart
// Staff only see tokens assigned to them
final myTokens = tokens.where((t) => 
  t.assignedStaffId == currentUserId
).toList();
```

### Option 2: Show All Room Tokens
```dart
// Staff see all tokens in their assigned room
final roomTokens = tokens.where((t) => 
  t.currentRoomId == myAssignedRoomId
).toList();
```

## 🧪 Testing Checklist

### Setup Testing
- [ ] Run `setup_room_staff_assignment.sql`
- [ ] Assign at least 2 staff to different rooms
- [ ] Verify assignments with query
- [ ] Check that `get_room_staff()` function works

### Transfer Testing
- [ ] Create a test token in Room 1
- [ ] Staff 1 processes and transfers to Room 2
- [ ] Verify Staff 1 sees success message with Staff 2's name
- [ ] Verify Staff 2 receives notification
- [ ] Verify token appears in Staff 2's dashboard
- [ ] Check `assigned_staff_id` in database
- [ ] Verify token_history records transfer

### Notification Testing
- [ ] Transfer token between rooms
- [ ] Check `staff_notifications` table
- [ ] Verify only next room staff gets notification
- [ ] Verify notification message is correct
- [ ] Test marking notification as read

### Multi-Room Flow Testing
- [ ] Transfer token through all 5 rooms
- [ ] Verify each staff gets notified
- [ ] Verify no duplicate notifications
- [ ] Check final completion

## 📝 Example Workflow

### Scenario: License Renewal Process

**Room 1 - Reception (Staff: John)**
1. Customer arrives, token T71156 created
2. John starts processing
3. John clicks "Transfer to Document Verification"
4. ✅ "Ticket successfully transferred to Document Verification - Assigned to: Sarah"

**Room 2 - Document Verification (Staff: Sarah)**
1. 🔔 Notification: "New ticket received — Token #T71156 has been assigned to you"
2. Token appears in Sarah's queue
3. Sarah clicks on token, starts processing
4. Sarah verifies documents
5. Sarah clicks "Transfer to Payment Counter"
6. ✅ "Ticket successfully transferred to Payment Counter - Assigned to: Mike"

**Room 3 - Payment Counter (Staff: Mike)**
1. 🔔 Notification: "New ticket received — Token #T71156 has been assigned to you"
2. Mike processes payment
3. Mike clicks "Transfer to Photo/Biometric"

**Room 4 - Photo/Biometric (Staff: Lisa)**
1. 🔔 Notification received
2. Lisa takes photo and biometrics
3. Lisa clicks "Transfer to Final Processing"

**Room 5 - Final Processing (Staff: David)**
1. 🔔 Notification received
2. David does final review
3. David clicks "Complete"
4. ✅ Token marked as completed

## 🚨 Troubleshooting

### Issue: Staff not getting notifications
**Solution:**
```sql
-- Check if staff is assigned to room
SELECT * FROM profiles WHERE user_id = 'STAFF_ID';

-- Check if function exists
SELECT * FROM pg_proc WHERE proname = 'get_room_staff';

-- Check if trigger is active
SELECT * FROM pg_trigger WHERE tgname = 'trigger_assign_token_to_room_staff';
```

### Issue: Token not auto-assigned
**Solution:**
```sql
-- Manually check function
SELECT * FROM get_room_staff('ROOM_ID');

-- Check if assigned_staff_id column exists
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'tokens' AND column_name = 'assigned_staff_id';
```

### Issue: Multiple staff in same room
**Solution:**
- Modify `get_room_staff()` function to implement round-robin or load balancing
- Current implementation assigns to first available staff

## 🎯 Next Steps

1. **Run the setup script** in Supabase
2. **Assign staff to rooms** using UPDATE statements
3. **Test the transfer flow** with real tokens
4. **Verify notifications** are working
5. **Deploy to production**

## 📚 Related Files

- `setup_room_staff_assignment.sql` - Database setup script
- `lib/screens/staff/token_details_screen.dart` - Transfer logic
- `lib/models/token.dart` - Token model (may need assignedStaffId field)

---

**Your room-based staff assignment system is now ready!** 🎉

Each room operates independently with its own staff, and tokens flow smoothly from one department to another with automatic assignment and targeted notifications.
