## 🏢 Complete Room-Based Staff Assignment System

### ✅ What This System Does

**1. Service-Based Token Assignment**
- User books License Registration → Automatically assigned to Ram (Room 1)
- User books License Renewal → Automatically assigned to Hari (Room 1)
- Staff only see tickets for their assigned service/room

**2. Room-to-Room Transfer**
- Ram transfers ticket → Automatically assigned to Geeta (Room 2)
- Geeta gets notification: "New ticket #A105 assigned to you"
- Ram sees: "Ticket successfully transferred to Room 2"

**3. Privacy & Data Separation**
- Each staff sees ONLY their assigned tickets
- No cross-department visibility
- Real-time updates for relevant staff only

---

## 📋 Setup Steps

### Step 1: Run Main Setup SQL

**File:** `fix_transfer_permissions_and_complete_system.sql`

**In Supabase SQL Editor:**
1. Copy entire file
2. Paste and RUN

**This creates:**
- ✅ Fixed transfer permissions
- ✅ Room assignment columns
- ✅ Staff notifications table
- ✅ Auto-assignment triggers
- ✅ Privacy RLS policies

---

### Step 2: Assign Staff to Rooms

**Get Staff IDs:**
```sql
SELECT id, full_name, email 
FROM profiles 
WHERE role = 'staff';
```

**Assign to Rooms:**
```sql
-- Ram -> Room 1 (Reception)
UPDATE profiles 
SET assigned_room_id = 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79360' 
WHERE id = 'RAM_STAFF_ID_HERE';

-- Geeta -> Room 2 (Document Verification)
UPDATE profiles 
SET assigned_room_id = 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79361' 
WHERE id = 'GEETA_STAFF_ID_HERE';

-- Continue for all 5 rooms...
```

---

### Step 3: Verify Setup

```sql
-- Check assignments
SELECT 
  r.room_number,
  r.name as room_name,
  p.full_name as assigned_staff
FROM rooms r
LEFT JOIN profiles p ON p.assigned_room_id = r.id
ORDER BY r.room_number;
```

You should see:
```
room_number | room_name              | assigned_staff
------------|------------------------|---------------
5-1         | Reception              | Ram
5-2         | Document Verification  | Geeta
5-3         | Payment Counter        | [Staff 3]
5-4         | Photo/Biometric        | [Staff 4]
5-5         | Final Processing       | [Staff 5]
```

---

## 🎯 How It Works

### Scenario 1: User Books Token

```
1. User books "License Registration"
   ↓
2. System finds first room (Reception)
   ↓
3. System finds staff assigned to Reception (Ram)
   ↓
4. Token.assigned_staff_id = Ram's ID
   ↓
5. Notification created for Ram
   ↓
6. Ram sees token in his dashboard
```

**Ram's Dashboard:**
```
📋 My Tokens (1)
┌─────────────────────────────────┐
│ Token #A105                     │
│ License Registration            │
│ Status: Waiting                 │
│ 🔔 New ticket assigned to you   │
└─────────────────────────────────┘
```

**Geeta's Dashboard:**
```
📋 My Tokens (0)
No tokens assigned yet
```

---

### Scenario 2: Ram Transfers Token

```
1. Ram clicks "Transfer to Document Verification"
   ↓
2. System updates:
   - token.current_room_id = Room 2
   - token.status = 'waiting'
   ↓
3. Trigger fires:
   - Finds Geeta (assigned to Room 2)
   - Sets token.assigned_staff_id = Geeta's ID
   - Creates notification for Geeta
   ↓
4. Ram sees: "✅ Transferred to Document Verification - Assigned to: Geeta"
   ↓
5. Geeta sees: "🔔 New ticket #A105 assigned to you"
```

**Ram's Dashboard (after transfer):**
```
📋 My Tokens (0)
No tokens in queue
```

**Geeta's Dashboard (after transfer):**
```
📋 My Tokens (1)
┌─────────────────────────────────┐
│ Token #A105                     │
│ License Registration            │
│ Status: Waiting                 │
│ 🔔 New ticket received          │
└─────────────────────────────────┘
```

---

## 🔐 Privacy Features

### RLS Policy Logic

**Staff can ONLY see tokens if:**
1. Token is assigned to them (`assigned_staff_id = their ID`)
2. Token is in their room (`current_room_id = their assigned room`)

**Staff CANNOT see:**
- Tokens in other rooms
- Tokens assigned to other staff
- Tokens for services they don't handle

---

## 🧪 Testing Checklist

### Test 1: Token Booking
- [ ] User books token
- [ ] Token appears in first room staff's dashboard
- [ ] Other staff don't see it
- [ ] Notification created for assigned staff

### Test 2: Token Transfer
- [ ] Staff 1 transfers token
- [ ] Token disappears from Staff 1's dashboard
- [ ] Token appears in Staff 2's dashboard
- [ ] Staff 2 gets notification
- [ ] Transfer message shows Staff 2's name

### Test 3: Privacy
- [ ] Login as Ram → See only Ram's tokens
- [ ] Login as Geeta → See only Geeta's tokens
- [ ] No cross-visibility

### Test 4: Real-time Updates
- [ ] Transfer token
- [ ] Both dashboards update instantly
- [ ] No manual refresh needed

---

## 📊 Database Tables

### tokens
```sql
- id
- token_number
- user_id
- service_id
- current_room_id
- assigned_staff_id  ← NEW (auto-assigned)
- status
```

### profiles
```sql
- id
- full_name
- email
- role
- assigned_room_id     ← NEW (manual assignment)
- assigned_service_id  ← NEW (optional)
```

### staff_notifications
```sql
- id
- staff_id
- token_id
- message
- type (assigned/transferred_in/transferred_out)
- is_read
- created_at
```

---

## 🚀 Quick Start Commands

### 1. Setup
```bash
Run: fix_transfer_permissions_and_complete_system.sql
```

### 2. Assign Staff
```bash
Run: assign_staff_simple.sql
```

### 3. Test
```bash
1. Book token as user
2. Login as staff (Room 1)
3. See token in dashboard
4. Transfer to next room
5. Login as staff (Room 2)
6. See token in their dashboard
```

---

## ✅ Success Criteria

You'll know it's working when:
- ✅ New tokens auto-appear in correct staff's dashboard
- ✅ Transfers work without errors
- ✅ Staff only see their assigned tokens
- ✅ Notifications show up for relevant staff
- ✅ Real-time updates work
- ✅ Transfer messages show next staff's name

---

**Your complete room-based staff assignment system is ready!** 🎉

Each department operates independently with clear ownership and privacy.
