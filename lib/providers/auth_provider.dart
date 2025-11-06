import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:major/screens/staff/enhanced_staff_dashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_profile.dart';import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;
  UserProfile? _profile;
  bool _profileLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  UserProfile? get profile => _profile;
  bool get isProfileLoading => _profileLoading;
  bool get isAdmin => _profile?.role == UserRole.admin;
  bool get isStaff => _profile?.role == UserRole.staff;

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    // Load current session if exists
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      _user = session.user;
      await _loadProfile(session.user.id);
      notifyListeners();
    }
    
    // Set up auth state listener
    SupabaseConfig.client.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      final event = data.event;
      
      if (kDebugMode) {
        print('🔐 Auth state changed: $event');
        print('🔐 User: ${user?.id}');
      }
      
      _user = user;
      
      if (user != null) {
        await _loadProfile(user.id);
      } else {
        _profile = null;
      }
      
      // Schedule the notification for the next frame
      Future.delayed(Duration.zero, () {
        if (!_disposed) {
          notifyListeners();
        }
      });
    });
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> loadUser() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final session = SupabaseConfig.client.auth.currentSession;
      if (session != null) {
        _user = session.user;
        if (_user != null) {
          await _loadProfile(_user!.id);
        }
      }
    } catch (e) {
      _error = 'Failed to load user: $e';
      if (kDebugMode) {
        print('Error loading user: $e');
      }
    } finally {
      _isLoading = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> _loadProfile(String userId) async {
    _profileLoading = true;
    notifyListeners();

    try {
      final response = await SupabaseConfig.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        _profile = UserProfile.fromJson(response);
        if (kDebugMode) {
          print('✅ Profile loaded: ${_profile?.fullName} (${_profile?.role})');
        }
      } else {
        // Profile doesn't exist - create one for old accounts
        if (kDebugMode) {
          print('⚠️ No profile found for user: $userId');
          print('🔄 Creating profile for existing user...');
        }
        
        final user = SupabaseConfig.client.auth.currentUser;
        if (user != null) {
          try {
            // Create a default profile for this user
            await SupabaseConfig.client.from('profiles').upsert({
              'id': userId,
              'email': user.email ?? 'user@example.com',
              'full_name': user.userMetadata?['name'] ?? 
                           user.userMetadata?['full_name'] ?? 
                           user.email?.split('@')[0] ?? 
                           'User',
              'role': 'customer',
              'is_active': true,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
            
            if (kDebugMode) {
              print('✅ Profile created for existing user');
            }
            
            // Reload the profile
            final newResponse = await SupabaseConfig.client
                .from('profiles')
                .select()
                .eq('id', userId)
                .maybeSingle();
            
            if (newResponse != null) {
              _profile = UserProfile.fromJson(newResponse);
            }
          } catch (createError) {
            if (kDebugMode) {
              print('❌ Error creating profile: $createError');
            }
            _profile = null;
          }
        } else {
          _profile = null;
        }
      }
    } catch (e) {
      _error = 'Failed to load profile: $e';
      if (kDebugMode) {
        print('❌ Error loading profile: $e');
      }
      _profile = null;
    } finally {
      _profileLoading = false;
      notifyListeners();
    }
  }

  // Check if email is a staff email
  bool _isStaffEmail(String email) {
    return email.endsWith('@work.com');
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Sign in with email and password
      final response = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _user = response.user;
        
        // Load or create user profile
        try {
          await _loadProfile(_user!.id);
          
          // If profile doesn't exist, create one based on email domain
          if (_profile == null) {
            final isStaff = _isStaffEmail(email);
            final role = isStaff ? 'staff' : 'customer';
            
            await SupabaseConfig.client.from('profiles').upsert({
              'id': _user!.id,
              'email': email,
              'full_name': email.split('@')[0],
              'role': role,
              'is_active': true,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
            
            // Reload profile with updated data
            await _loadProfile(_user!.id);
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error handling user profile: $e');
          }
        }
      }
    } on AuthException catch (e) {
      _error = e.message;
      rethrow;
    } catch (e) {
      _error = 'An unexpected error occurred';
      rethrow;
    } finally {
      _isLoading = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> signUp(String email, String password, String fullName) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );

      if (response.user != null) {
        // Create profile in database
        await SupabaseConfig.client.from('profiles').upsert({
          'id': response.user!.id,
          'email': email,
          'full_name': fullName,
          'role': 'customer', // Default role
          'is_active': true,
        });
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await SupabaseConfig.client.auth.signOut();
      _user = null;
      _profile = null;
    } catch (e) {
      _error = 'Failed to sign out';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithOTP(String phone) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await SupabaseConfig.client.auth.signInWithOtp(
        phone: phone,
      );

      _isLoading = false;
      return true;
    } catch (error) {
      _error = error.toString();
      _isLoading = false;
      return false;
    }
  }

  Future<bool> verifyOTP(String phone, String token) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await SupabaseConfig.client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );

      if (response.user != null) {
        _user = response.user;
        await _loadProfile(_user!.id);
        _isLoading = false;
        return true;
      }

      _isLoading = false;
      return false;
    } catch (error) {
      _error = error.toString();
      _isLoading = false;
      return false;
    }
  }

  Future<String> getUserRole(String userId) async {
    try {
      final response = await SupabaseConfig.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();
      
      return response['role'] ?? 'customer';
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user role: $e');
      }
      return 'customer'; // Default to customer if error
    }
  }

  // Get the appropriate home screen based on user role
  Widget getHomeScreen() {
    if (!isAuthenticated) {
      return const LoginScreen();
    }

    if (isAdmin) {
      return const AdminDashboardScreen();
    } else if (isStaff) {
      return const EnhancedStaffDashboard();
    } else {
      return const HomeScreen();
    }
  }
}
