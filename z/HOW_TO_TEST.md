# 🧪 How to Test - Digital Queue Management System

## 🚀 Quick Start

### Running the Application
```bash
cd "d:\major\major - Copy"
flutter pub get
flutter run -d chrome
```

The app is currently running at: **http://localhost:61986**

---

## 📋 Complete Testing Checklist

### ✅ 1. Authentication Features

#### Login Screen
- [ ] Navigate to login screen
- [ ] Enter email and password
- [ ] Click "Login" button
- [ ] Verify successful login and navigation to home

#### Signup Screen
- [ ] Click "Sign Up" link on login screen
- [ ] Enter phone number
- [ ] Receive and enter OTP
- [ ] Complete profile with name
- [ ] Verify account creation

#### **NEW: Forgot Password** ✨
- [ ] Click "Forgot Password?" on login screen
- [ ] Enter your email address
- [ ] Click "Send Reset Link"
- [ ] Check email for reset link
- [ ] Verify success message appears
- [ ] Test "Resend" functionality
- [ ] Click "Back to Login" to return

---

### ✅ 2. Token Management Features

#### Book Token
- [ ] Go to "Services" tab or click "New Token"
- [ ] Select a service (License Renewal or New License)
- [ ] Click "Book Token"
- [ ] Verify booking confirmation
- [ ] Check token appears in "My Tokens"

#### Track Token
- [ ] Go to "My Tokens" tab
- [ ] Tap on any active token
- [ ] View token tracking screen
- [ ] Check queue position display
- [ ] Verify estimated wait time
- [ ] See token status and details

#### **NEW: Cancel Token** ✨
- [ ] Open token tracking screen for waiting token
- [ ] Click "Cancel Token" button
- [ ] Confirm cancellation in dialog
- [ ] Verify success message
- [ ] Check token is removed from active list

#### **NEW: Token History** ✨
- [ ] Go to Profile tab
- [ ] Click "Token History"
- [ ] View all past tokens
- [ ] Test filter chips (All, Completed, Rejected, Cancelled)
- [ ] Pull down to refresh
- [ ] Verify token details display correctly
- [ ] Check processing time for completed tokens

---

### ✅ 3. Profile Management Features

#### View Profile
- [ ] Go to "Profile" tab
- [ ] View your profile information
- [ ] Check name, phone, and role display

#### **NEW: Edit Profile** ✨
- [ ] Click "Edit Profile" in profile menu
- [ ] Modify your full name
- [ ] Update phone number
- [ ] Click "Save Changes"
- [ ] Verify success message
- [ ] Check profile updates on profile screen
- [ ] Test form validation (empty fields, short names)
- [ ] Click "Cancel" to discard changes

---

### ✅ 4. Settings Features

#### **NEW: Settings Screen** ✨
- [ ] Go to Profile tab
- [ ] Click "Settings"
- [ ] Toggle "Push Notifications" switch
- [ ] Toggle "Sound" switch
- [ ] Toggle "Vibration" switch
- [ ] Click "Language" and select language
- [ ] View app version information
- [ ] Test "Terms of Service" link
- [ ] Test "Privacy Policy" link
- [ ] Click "Logout" button

---

### ✅ 5. Help & Support Features

#### **NEW: Help & Support Screen** ✨
- [ ] Go to Profile tab
- [ ] Click "Help & Support"
- [ ] View contact information
- [ ] Expand FAQ items
- [ ] Click "Report a Problem"
- [ ] Enter problem description
- [ ] Submit report
- [ ] Click "Send Feedback"
- [ ] Enter feedback
- [ ] Submit feedback
- [ ] Test "Rate Our App" option

---

### ✅ 6. Navigation Testing

#### Bottom Navigation
- [ ] Click "Dashboard" tab
- [ ] Click "Services" tab
- [ ] Click "My Tokens" tab
- [ ] Click "Profile" tab
- [ ] Verify smooth transitions

#### Quick Actions (Dashboard)
- [ ] Click "New Token" card
- [ ] Verify navigation to service selection
- [ ] Click "History" card
- [ ] Verify navigation to token history

#### Profile Menu
- [ ] Test "Edit Profile" navigation
- [ ] Test "Token History" navigation
- [ ] Test "Settings" navigation
- [ ] Test "Help & Support" navigation
- [ ] Test "Logout" functionality

---

### ✅ 7. Notifications Testing

#### Notification Bell
- [ ] Check notification icon in app bar
- [ ] Verify unread count badge
- [ ] Click notification bell
- [ ] View notifications screen
- [ ] Mark notification as read
- [ ] Swipe to delete notification
- [ ] Click "Mark All as Read"

---

### ✅ 8. Real-time Features

#### Queue Updates
- [ ] Book a token
- [ ] Watch queue position update
- [ ] Verify estimated wait time changes
- [ ] Check real-time status updates

---

## 🎯 Feature-Specific Test Scenarios

### Scenario 1: Complete User Journey
1. Sign up with phone number
2. Complete profile
3. Book a token for License Renewal
4. Track token in real-time
5. View queue position
6. Edit profile information
7. Check token history
8. Cancel the token
9. View settings
10. Get help from support

### Scenario 2: Forgot Password Flow
1. Go to login screen
2. Click "Forgot Password?"
3. Enter registered email
4. Click "Send Reset Link"
5. Check email inbox
6. Click reset link in email
7. Set new password
8. Login with new password

### Scenario 3: Profile Management
1. Login to account
2. Go to Profile tab
3. Click "Edit Profile"
4. Update name and phone
5. Save changes
6. Verify updates appear
7. Go to Settings
8. Adjust notification preferences
9. Change language preference

### Scenario 4: Token Lifecycle
1. Book new token
2. View in My Tokens
3. Track live status
4. Check queue position
5. Wait for processing
6. View completion
7. Check in history
8. View processing time

---

## 🐛 Error Handling Tests

### Test Invalid Inputs
- [ ] Login with wrong credentials
- [ ] Forgot password with invalid email
- [ ] Edit profile with empty name
- [ ] Edit profile with short phone number
- [ ] Book token without selecting service

### Test Network Errors
- [ ] Disconnect internet
- [ ] Try to book token
- [ ] Verify error message
- [ ] Reconnect and retry

### Test Edge Cases
- [ ] Cancel already cancelled token
- [ ] Edit profile without changes
- [ ] Send forgot password for non-existent email
- [ ] Submit empty feedback form

---

## 📱 UI/UX Verification

### Visual Checks
- [ ] All buttons are visible and styled
- [ ] Icons are appropriate and clear
- [ ] Colors are consistent
- [ ] Text is readable
- [ ] Spacing is proper
- [ ] Loading indicators appear
- [ ] Success/error messages show

### Interaction Checks
- [ ] Buttons respond to clicks
- [ ] Forms validate input
- [ ] Dialogs appear and dismiss
- [ ] Navigation is smooth
- [ ] Scrolling works properly
- [ ] Pull-to-refresh functions

---

## ✅ Acceptance Criteria

### All Features Must:
- ✅ Be accessible from the UI
- ✅ Work without errors
- ✅ Show appropriate feedback
- ✅ Handle errors gracefully
- ✅ Have consistent styling
- ✅ Be user-friendly

### Specific Requirements:
- ✅ Forgot Password sends email
- ✅ Edit Profile updates database
- ✅ Token History shows all tokens
- ✅ Token Cancellation works
- ✅ Settings save preferences
- ✅ Help & Support is informative

---

## 🎉 Success Indicators

### You'll know it's working when:
1. ✅ No "TODO" comments in functionality
2. ✅ All buttons perform actions
3. ✅ No broken navigation links
4. ✅ Forms validate and submit
5. ✅ Database updates reflect in UI
6. ✅ Error messages are helpful
7. ✅ Success messages confirm actions
8. ✅ App doesn't crash

---

## 📊 Test Results Template

```
Feature: [Feature Name]
Status: [ ] Pass / [ ] Fail
Notes: [Any observations]

Issues Found:
- [List any bugs or issues]

Suggestions:
- [List any improvements]
```

---

## 🔧 Troubleshooting

### If something doesn't work:
1. Check browser console for errors
2. Verify internet connection
3. Clear browser cache
4. Restart the app
5. Check Supabase connection
6. Review error messages

### Common Issues:
- **Email not received**: Check spam folder
- **Profile not updating**: Refresh the page
- **Token not cancelling**: Check token status
- **Navigation not working**: Clear cache

---

## 📞 Support

If you encounter any issues during testing:
1. Check the error message
2. Review the console logs
3. Check the FEATURE_COMPLETION_REPORT.md
4. Verify database connection
5. Contact development team

---

**Happy Testing! 🎉**

All features are implemented and ready for your testing!
