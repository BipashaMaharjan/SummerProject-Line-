# Staff Room Visibility Fix

## Problem
Staff members were able to see ALL tokens in the system, regardless of which room they were assigned to. For example, if user `abc` was assigned to Room 3, they could see tokens from all rooms (Room 1, Room 2, Room 3, etc.), which is incorrect.

## Solution
Implemented room-based filtering so that staff members only see tokens that belong to their assigned room.

## Changes Made

### 1. **UserProfile Model** (`lib/models/user_profile.dart`)
- Added `assignedRoomId` field to store staff's assigned room
- Updated `fromJson()` to parse `assigned_room_id` from database
- Updated `toJson()` to include `assigned_room_id`
- Updated `copyWith()` method to support `assignedRoomId`

```dart
class UserProfile {
  final String? assignedRoomId; // For staff - their assigned room
  // ... other fields
}
```

### 2. **TokenProvider** (`lib/providers/token_provider.dart`)
- Modified `getTodaysQueue()` to accept optional `filterByRoomId` parameter
- Added room filtering logic when `filterByRoomId` is provided
- Tokens are now filtered by `current_room_id` matching the staff's assigned room

```dart
Future<List<Token>> getTodaysQueue({String? filterByRoomId}) async {
  // ... 
  if (filterByRoomId != null) {
    query = query.eq('current_room_id', filterByRoomId);
  }
  // ...
}
```

### 3. **EnhancedStaffDashboard** (`lib/screens/staff/enhanced_staff_dashboard.dart`)
- Imported `AuthProvider` to access staff profile
- Updated `_refresh()` method to get staff's `assignedRoomId` from their profile
- Passes `assignedRoomId` to `getTodaysQueue()` for filtering

```dart
Future<void> _refresh() async {
  final authProvider = context.read<AuthProvider>();
  final assignedRoomId = authProvider.profile?.assignedRoomId;
  
  await context.read<TokenProvider>().getTodaysQueue(
    filterByRoomId: assignedRoomId,
  );
}
```

## How It Works

1. **Staff Login**: When a staff member logs in, their profile is loaded including their `assigned_room_id`
2. **Token Fetching**: When the staff dashboard loads, it fetches tokens filtered by the staff's assigned room
3. **Room Filtering**: Only tokens where `current_room_id` matches the staff's `assigned_room_id` are displayed
4. **Admin/User Not Affected**: 
   - Admins don't have an `assigned_room_id`, so they see all tokens (no filter applied)
   - Users only see their own tokens (different logic)

## Example

**Before Fix:**
- Staff `abc` assigned to Room 3
- Could see: Token #1 (Room 1), Token #2 (Room 2), Token #3 (Room 3), Token #4 (Room 1)
- **Problem**: Seeing all tokens from all rooms

**After Fix:**
- Staff `abc` assigned to Room 3
- Can see: Only Token #3 (Room 3) and any other tokens in Room 3
- **Correct**: Only seeing tokens in their assigned room

## Database Requirements

Ensure that:
1. The `profiles` table has an `assigned_room_id` column
2. Staff members have their `assigned_room_id` properly set in the database
3. Tokens have their `current_room_id` set when transferred to rooms

## Testing

To verify the fix:
1. Login as a staff member assigned to a specific room
2. Check the staff dashboard
3. Verify only tokens in that room are visible
4. Transfer a token to the staff's room from another room
5. Verify the token now appears in the dashboard

## Notes

- ✅ No changes to admin functionality (admins see all tokens)
- ✅ No changes to user functionality (users see only their tokens)
- ✅ No changes to transfer, countdown, or status update functionality
- ✅ Only affects staff token visibility based on assigned room
- ✅ If a staff member has no assigned room (`null`), they will see all tokens (fallback behavior)
