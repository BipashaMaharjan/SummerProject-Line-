# Digital Queue Management System

A Flutter-based digital queue management system with Supabase backend for managing service tokens, user authentication, and multi-room workflows.

## Features

### Authentication
- **User Authentication**: OTP-based signup and login with persistent sessions
- **Staff Authentication**: Admin-managed staff accounts
- **Secure Sessions**: Automatic session handling with re-login capability

### Services
- **License Renewal**: Existing license renewal service
- **New License**: New license application service

### Token Management
- **Token Statuses**: Waiting → Hold → Processing → Completed
- **Multi-Room Flow**: Dash system (5-1, 5-2, 5-3) for room transfers
- **Staff Actions**: Pick, Transfer, Reject, Complete tokens
- **Real-time Updates**: Live status tracking and notifications

### Admin Panel
- **Staff Management**: Create and manage staff accounts
- **Calendar Configuration**: Block bookings on public holidays
- **Analytics**: Monitor token flows, room workload, and performance metrics

## Setup Instructions

### Prerequisites
- Flutter SDK (latest stable version)
- Supabase account and project

### Installation

1. **Clone and setup**:
   ```bash
   cd d:\major
   flutter pub get
   ```

2. **Configure Supabase**:
   - Create a new Supabase project
   - Copy your project URL and anon key
   - Update `lib/config/supabase_config.dart`:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── config/
│   └── supabase_config.dart      # Supabase configuration
├── providers/
│   └── auth_provider.dart        # Authentication state management
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart     # Phone number login
│   │   └── otp_verification_screen.dart  # OTP verification
│   ├── home/
│   │   └── home_screen.dart      # Main dashboard with tabs
│   └── splash_screen.dart        # App initialization screen
└── main.dart                     # App entry point
```

## Current Status

✅ **Completed**:
- Flutter project setup with Supabase dependencies
- Basic authentication flow (OTP login/verification)
- Main app structure with navigation
- Splash screen and home dashboard

🚧 **Next Steps**:
- Database schema creation
- Token booking system
- Staff dashboard
- Admin panel
- Multi-room workflow implementation

## Tech Stack

- **Frontend**: Flutter with Provider for state management
- **Backend**: Supabase (PostgreSQL + Auth + Real-time)
- **Navigation**: Bottom navigation with multiple tabs
- **UI**: Material Design 3 with custom theming
