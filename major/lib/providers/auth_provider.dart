import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_profile.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  UserProfile? _profile;
  bool _profileLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  UserProfile? get profile => _profile;
  bool get isProfileLoading => _profileLoading;

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      // User will be updated via auth state listener
      return;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      rethrow;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    // Listen to auth state changes
    SupabaseConfig.client.auth.onAuthStateChange.listen((data) async {
      _user = data.session?.user;
      if (_user != null) {
        await _syncProfileForUser(_user!);
      } else {
        _profile = null;
      }
      notifyListeners();
    });

    // Check if user is already logged in
    _user = SupabaseConfig.client.auth.currentUser;
    if (_user != null) {
      _syncProfileForUser(_user!);
    }
  }

  Future<bool> signInWithOTP(String phone) async {
    try {
      _setLoading(true);
      _clearError();

      await SupabaseConfig.client.auth.signInWithOtp(
        phone: phone,
      );

      _setLoading(false);
      return true;
    } catch (error) {
      _setError(error.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> verifyOTP(String phone, String token) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await SupabaseConfig.client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );

      if (response.user != null) {
        _user = response.user;
        await _syncProfileForUser(_user!);
        _setLoading(false);
        return true;
      }

      _setLoading(false);
      return false;
    } catch (error) {
      _setError(error.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await SupabaseConfig.client.auth.signOut();
      _user = null;
      _profile = null;
      notifyListeners();
    } catch (error) {
      _setError(error.toString());
    }
  }

  Future<void> _syncProfileForUser(User user) async {
    try {
      _profileLoading = true;
      notifyListeners();

      final client = SupabaseConfig.client;
      final email = user.email;

      // Check if invited as staff
      Map<String, dynamic>? invite;
      if (email != null) {
        invite = await client
            .from('staff_invites')
            .select()
            .eq('email', email)
            .maybeSingle();
      }

      // Fetch profile
      final existing = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existing != null) {
        // Update updated_at
        await client.from('profiles').update({
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
        _profile = UserProfile.fromJson(existing);
      } else {
        final now = DateTime.now().toIso8601String();
        final payload = {
          'id': user.id,
          'full_name': invite?['name'],
          'role': invite != null ? 'staff' : 'customer',
          'is_active': true,
          'created_at': now,
          'updated_at': now,
        };
        final inserted = await client.from('profiles').insert(payload).select().single();
        _profile = UserProfile.fromJson(inserted);
      }

      // If invited, ensure role is staff and optionally remove invite
      if (invite != null && _profile?.role != UserRole.staff) {
        await client
            .from('profiles')
            .update({'role': 'staff', 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', user.id);
        final updated = await client.from('profiles').select().eq('id', user.id).single();
        _profile = UserProfile.fromJson(updated);
        if (email != null) {
          await client.from('staff_invites').delete().eq('email', email);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Profile sync error: $e');
      }
    } finally {
      _profileLoading = false;
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
