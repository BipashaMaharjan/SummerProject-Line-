# Fix: Transfer Button Not Showing

## 🔍 Problem Identified

From the console logs:
```
✅ Loaded 3 workflow steps
- Current index: 2
- Is last room: true
- Has next room: false
```

**Issue:** Your workflow only has **3 rooms**, and the token is in the **last room (index 2)**, so there's no next room to transfer to!

## ✅ Solution: Add More Rooms to Workflow

### Step 1: Run the SQL Script

1. Open **Supabase Dashboard**
2. Go to **SQL Editor**
3. Open the file: `add_workflow_rooms.sql`
4. Copy and paste the SQL into Supabase SQL Editor
5. Click **Run**

This will:
- Add 5 rooms (Reception, Document Verification, Payment, Photo/Biometric, Final Processing)
- Create a complete 5-step workflow for both services
- Allow you to test transfers between rooms

### Step 2: Create a New Test Token

After running the SQL:

1. **Book a new token** (as a user)
2. **Login as Staff**
3. **Go to Staff Dashboard**
4. **Find the new token** (it should be in Room 1: Reception)
5. **Click "Start"** to begin processing
6. **Now you'll see the blue Transfer button!**

## 🎯 Expected Result

When you open a token in **Room 1 (Reception)**, you should see:

```
┌─────────────────────────────────────────────────┐
│  Transfer to Document Verification              │  ← Blue button
└─────────────────────────────────────────────────┘

┌──────────────┬──────────────┐
│    Reject    │   Complete   │
└──────────────┴──────────────┘

🔍 Debug Info:
Workflow: 5 rooms | Current: #0 | Has Next: true
➡️ Next Room: Document Verification
```

## 📊 Workflow After Fix

```
Room 1: Reception (current)
   ↓ [Transfer button appears here]
Room 2: Document Verification
   ↓ [Transfer button appears here]
Room 3: Payment Counter
   ↓ [Transfer button appears here]
Room 4: Photo/Biometric
   ↓ [Transfer button appears here]
Room 5: Final Processing
   ↓ [Only Complete button - last room]
```

## 🧪 Testing Steps

1. **Run the SQL script** in Supabase
2. **Refresh your app** (F5)
3. **Book a new token** (or update an existing token to room 1)
4. **Login as Staff**
5. **Click on the token**
6. **Click "Start"** to process
7. **You should now see the blue "Transfer to Document Verification" button!**

## 🔧 Alternative: Update Existing Token

If you want to test with an existing token, run this SQL:

```sql
-- Move an existing token back to Room 1
UPDATE tokens 
SET 
  current_room_id = 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79360',
  current_sequence = 1,
  status = 'processing'
WHERE token_number = 'T21502';  -- Replace with your token number
```

Then refresh and open that token - you'll see the Transfer button!

## 📝 Debug Info Box

The new debug info box will always show you:
- **Workflow: X rooms** - How many rooms in the workflow
- **Current: #X** - Which room index you're in (0 = first room)
- **Has Next: true/false** - Whether transfer is available
- **➡️ Next Room: Name** - The next room name (if available)
- **⚠️ Last room** - If you're in the last room

## ✅ Checklist

- [ ] Run `add_workflow_rooms.sql` in Supabase
- [ ] Verify 5 rooms exist in database
- [ ] Verify workflow has 5 steps
- [ ] Book a new token
- [ ] Token starts in Room 1 (Reception)
- [ ] Login as Staff
- [ ] Start processing the token
- [ ] See blue Transfer button
- [ ] Click Transfer
- [ ] Token moves to Room 2
- [ ] Repeat through all rooms

---

**The Transfer button will ONLY show when:**
1. ✅ Token status is "processing"
2. ✅ Token is NOT in the last room
3. ✅ Workflow has multiple rooms
4. ✅ Current room is found in workflow

**Your issue:** Token was in the last room (room 3 of 3), so no transfer available!
