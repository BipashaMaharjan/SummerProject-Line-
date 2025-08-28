import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Check if user is logged in
  bool isLoggedIn() {
    return _supabase.auth.currentUser != null;
  }

  // Get current user from auth
  UserProfile? getCurrentUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    return UserProfile(
      id: user.id,
      fullName: user.userMetadata?['name'],
      phone: user.phone,
      role: UserRole.customer, // Default role
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Get user data from database
  Future<UserProfile?> getUserFromDatabase(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .single();

      return UserProfile(
        id: response['id'],
        fullName: response['full_name'],
        phone: response['phone'],
        role: UserRole.values.firstWhere(
          (e) => e.name == (response['role'] ?? 'customer'),
          orElse: () => UserRole.customer,
        ),
        isActive: response['is_active'] ?? true,
        createdAt: DateTime.parse(response['created_at']),
        updatedAt: DateTime.parse(response['updated_at'] ?? response['created_at']),
      );
    } catch (e) {
      print('Error fetching user from database: $e');
      return null;
    }
  }

  // Sign out user
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Sign in with email and password
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
}
