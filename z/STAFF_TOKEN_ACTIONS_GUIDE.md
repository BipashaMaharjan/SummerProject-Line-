# Staff Token Actions Guide

## Overview
This guide explains the enhanced token management actions available to staff members in the Token Details screen.

## Action Buttons

### 1. **Transfer to Next Room** (Blue Button)
**When it appears:**
- Token is being processed
- Token is NOT in the last room of the workflow
- There are more rooms in the service workflow

**What it does:**
- Moves the token to the next room in the workflow
- Changes token status to "waiting" in the new room
- Records the transfer in history
- Updates queue position for the next room

**Example:**
```
Current Room: Reception (Room 1)
Next Room: Document Verification (Room 2)
Button shows: "Transfer to Document Verification"
```

### 2. **Hold** (Orange Outlined Button)
**When it appears:**
- Always available when token is being processed

**What it does:**
- Puts the token on hold temporarily
- Useful when:
  - Customer needs to get additional documents
  - Staff needs to consult with supervisor
  - Technical issues need to be resolved
  - Customer stepped away temporarily

**After holding:**
- Token appears in "On Hold" section
- Staff can resume processing later
- Token maintains its position in the workflow

### 3. **Reject** (Red Outlined Button)
**When it appears:**
- Always available when token is being processed

**What it does:**
- Rejects the token permanently
- Shows confirmation dialog
- Asks for rejection reason (optional but recommended)
- Useful when:
  - Customer has incomplete/invalid documents
  - Service request doesn't meet requirements
  - Customer is ineligible for the service
  - Duplicate or fraudulent request

**Rejection Process:**
1. Click "Reject" button
2. Confirmation dialog appears
3. Enter reason for rejection (recommended)
4. Click "Reject" to confirm or "Cancel" to abort
5. Token status changes to "Rejected"
6. Reason is recorded in history

**After rejecting:**
- Token is marked as completed (rejected)
- Customer is notified
- Token removed from active queue
- Rejection reason visible in history

### 4. **Complete** (Green/Orange Button)
**When it appears:**
- Always available when token is being processed

**Button variations:**
- **Green "Complete"**: When in the last room
  - Marks token as fully completed
  - Records completion time
  - Removes from active queue
  
- **Orange "Complete (Skip Steps)"**: When NOT in last room
  - Completes token early
  - Skips remaining workflow steps
  - Use when service can be completed early

## Workflow Example

### License Renewal Service (5 rooms)
1. **Reception** → Transfer to Document Verification
2. **Document Verification** → Transfer to Payment Counter
3. **Payment Counter** → Transfer to Photo/Biometric
4. **Photo/Biometric** → Transfer to Final Processing
5. **Final Processing** → Complete (Green button)

### Staff Actions at Each Step:

#### At Reception (Room 1):
```
┌─────────────────────────────────────────┐
│ Transfer to Document Verification       │ ← Click to move forward
└─────────────────────────────────────────┘
┌──────────┬──────────┬──────────────────┐
│   Hold   │  Reject  │    Complete      │
└──────────┴──────────┴──────────────────┘
```

#### At Final Processing (Room 5):
```
┌──────────┬──────────┬──────────────────┐
│   Hold   │  Reject  │    Complete      │ ← Click to finish
└──────────┴──────────┴──────────────────┘
```

## Best Practices

### ✅ DO:
- **Use Transfer** for normal workflow progression
- **Use Hold** when customer needs to return later
- **Use Complete** in the last room when service is done
- Check workflow progress before taking action

### ❌ DON'T:
- Don't use "Complete (Skip Steps)" unless authorized
- Don't transfer if customer hasn't completed current step
- Don't hold tokens indefinitely without notes

## Troubleshooting

### Transfer button not showing?
**Check:**
1. Is the token in "processing" status?
2. Is this the last room in the workflow?
3. Are there more rooms defined in the service workflow?
4. Check debug logs in console for workflow information

### Debug Information
The screen shows debug info if there's an issue:
- "⚠️ Current room not found in workflow" - Contact admin

### Console Logs
Look for these debug messages:
```
🔍 Action Section Debug:
  - Workflow length: 5
  - Current room ID: abc-123
  - Current index: 0
  - Current sequence: 1
  - Is last room: false
  - Has next room: true
  - Next room: Document Verification
```

## Token History
All actions are recorded in the token history:
- ✅ **Transferred**: Token moved to next room
- ⏸️ **Hold**: Token put on hold
- ✅ **Completed**: Token service completed

## Quick Reference

| Action | Color | When to Use |
|--------|-------|-------------|
| Transfer to [Room] | Blue | Normal workflow progression |
| Hold | Orange (Outlined) | Temporary pause needed |
| Complete | Green | Service finished (last room) |
| Complete (Skip Steps) | Orange | Early completion (not last room) |

## Support
If you encounter issues:
1. Check the workflow progress section
2. Look for debug messages
3. Refresh the screen (top-right refresh button)
4. Contact system administrator if problem persists
