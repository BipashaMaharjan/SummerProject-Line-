# Feature 2: Queue Estimation & Wait Time Prediction - Implementation Guide

## ✅ What Was Implemented

### Core Components:

1. **QueueEstimationService** (`lib/services/queue_estimation_service.dart`)
   - Calculates queue position
   - Counts tokens ahead
   - Computes average handling time
   - Estimates wait time
   - Formats time displays

2. **QueueEstimationWidget** (`lib/widgets/queue_estimation_widget.dart`)
   - Beautiful blue card showing wait time
   - Queue position display
   - People ahead count
   - Average service time
   - Estimated completion time
   - Refresh button

3. **TokenTrackingScreenV2** (`lib/screens/user/token_tracking_screen_v2.dart`)
   - Enhanced tracking screen with queue estimation
   - Integrates QueueEstimationWidget
   - Shows all token information plus wait time

## 🎯 Features Added:

### 1. Queue Position Calculation
- Shows exact position in queue (e.g., "Position #3")
- Counts tokens ahead
- Only for waiting tokens

### 2. Average Handling Time
- Calculates from last 7 days of completed tokens
- Falls back to default times if no data:
  - License Renewal: 15 minutes
  - New License: 25 minutes
  - Default: 20 minutes

### 3. Estimated Wait Time
- Formula: `tokens_ahead × average_handling_time`
- Smart formatting:
  - "Next in line" for 0 minutes
  - "Less than 5 minutes" for < 5 min
  - "~15 minutes" for < 60 min
  - "~1 hour 30 min" for >= 60 min

### 4. Estimated Completion Time
- Shows expected time (e.g., "Expected around 3:45 PM")
- Based on current time + estimated wait

### 5. Real-Time Updates
- Refresh button to recalculate
- Auto-loads on screen open
- Updates when queue changes

## 📱 User Interface:

### Queue Estimation Card (Blue):
```
┌─────────────────────────────────────┐
│ ⏰ Estimated Wait Time              │
│    ~30 minutes                       │
│ ─────────────────────────────────   │
│ 📋 Queue Position: Position #3      │
│ 👥 People Ahead: 2 people ahead     │
│ ⏱️  Avg. Service Time: ~15 minutes  │
│ ─────────────────────────────────   │
│ 🕐 Expected around 3:45 PM          │
│                         [Refresh] ↻  │
└─────────────────────────────────────┘
```

### Complete Tracking Screen:
```
Token: T123-1        [WAITING]
License Renewal

┌─────────────────────────────────────┐
│ ⏰ Estimated Wait Time              │
│    ~30 minutes                       │
│ Queue Position: #3                   │
│ People Ahead: 2                      │
└─────────────────────────────────────┘

[⏳] Waiting                    🟢 Live
You are in the queue.
Please wait for your turn.

Token Details
...
```

## 🔧 How It Works:

### 1. Queue Position Calculation:
```dart
// Count tokens created before this one with same service
SELECT COUNT(*) FROM tokens
WHERE service_id = token.serviceId
  AND status = 'waiting'
  AND created_at < token.createdAt
```

### 2. Average Handling Time:
```dart
// Get completed tokens from last 7 days
SELECT started_at, completed_at FROM tokens
WHERE service_id = token.serviceId
  AND status = 'completed'
  AND completed_at >= (NOW() - INTERVAL '7 days')

// Calculate average: (completed_at - started_at)
```

### 3. Wait Time Estimation:
```dart
estimatedMinutes = tokensAhead × avgHandlingTime
```

## 📊 Data Requirements:

### For Accurate Predictions:
1. **Tokens need `started_at` timestamp** - When staff starts processing
2. **Tokens need `completed_at` timestamp** - When service completes
3. **Historical data** - More completed tokens = better predictions

### Fallback Behavior:
- If no historical data: Uses default times
- If calculation fails: Shows "Calculating..."
- If not waiting: Widget doesn't show

## 🎨 Visual Design:

### Colors:
- **Blue card** (`Colors.blue.shade50`) - Stands out from other cards
- **Blue text** (`Colors.blue.shade700`) - Matches card theme
- **Icons** - Intuitive (clock, people, timer, schedule)

### Layout:
- Large wait time display (24px bold)
- Clear section dividers
- Right-aligned refresh button
- Consistent spacing

## 🚀 Testing the Feature:

### Steps:
1. Run the app
2. Login and book a token
3. Go to "My Tokens" tab
4. Tap on a waiting token
5. See the blue "Estimated Wait Time" card!

### What to Test:
- ✅ Queue position shows correctly
- ✅ Wait time is reasonable
- ✅ Refresh button updates the estimate
- ✅ Completion time makes sense
- ✅ Card only shows for waiting tokens

## 💡 Smart Features:

### 1. Only Shows for Waiting Tokens
- Processing tokens don't need estimates
- Completed tokens are done
- Widget automatically hides

### 2. Handles Edge Cases
- No historical data → Uses defaults
- First in line → "Next in line"
- Very short wait → "Less than 5 minutes"

### 3. User-Friendly Messages
- "Position #3" instead of "3"
- "2 people ahead" instead of "2"
- "~30 minutes" instead of "30"

## 📈 Future Enhancements:

### Possible Improvements:
1. **Real-time updates** - Auto-refresh every minute
2. **Historical trends** - Show typical wait times by hour
3. **Accuracy indicator** - Show confidence level
4. **Push notifications** - Alert when wait time drops
5. **Queue velocity** - Show how fast queue is moving

## ✅ Success Criteria - ACHIEVED:

- ✅ Queue position displayed
- ✅ Tokens ahead counted
- ✅ Average handling time calculated
- ✅ Wait time estimated
- ✅ Completion time shown
- ✅ Beautiful UI design
- ✅ Refresh functionality
- ✅ Smart formatting
- ✅ Edge cases handled

## 🎉 Summary:

Feature 2 adds intelligent queue estimation to your Digital Queue Management System!

Users can now see:
- How long they'll wait
- Where they are in queue
- When they'll likely be served

This significantly improves user experience by setting clear expectations and reducing anxiety about wait times.

**Status: ✅ READY FOR TESTING**

---

**Next:** Feature 3 - Instant Notifications & Alerts
