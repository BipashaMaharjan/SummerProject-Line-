import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Add a new staff member
  Future<Map<String, dynamic>> addStaff({
    required String email,
    required String fullName,
    required String password,
  }) async {
    AuthResponse? authResponse;
    
    try {
      // 1. Sign up the user with email and password
      authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': 'staff',
        },
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create user account');
      }

      // 2. Create profile in profiles table
      final profileResponse = await _supabase.from('profiles').insert({
        'id': authResponse.user!.id,
        'email': email,
        'full_name': fullName,
        'role': 'staff',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();

      return {
        'success': true,
        'message': 'Staff added successfully',
        'data': profileResponse,
      };
    } catch (e) {
      // Clean up auth user if profile creation failed
      if (authResponse?.user != null) {
        try {
          await _supabase.auth.admin.deleteUser(authResponse!.user!.id);
        } catch (deleteError) {
          debugPrint('Error cleaning up user account: $deleteError');
        }
      }
      rethrow;
    }
  }

  // Get list of all staff members
  Future<List<Map<String, dynamic>>> getStaffList() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .or('role.eq.staff,role.eq.admin')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching staff list: $e');
      rethrow;
    }
  }

  // Update staff member
  Future<void> updateStaff({
    required String userId,
    String? fullName,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (isActive != null) updates['is_active'] = isActive;
      updates['updated_at'] = DateTime.now().toIso8601String();

      if (updates.isNotEmpty) {
        await _supabase
            .from('profiles')
            .update(updates)
            .eq('id', userId);
      }
    } catch (e) {
      debugPrint('Error updating staff: $e');
      rethrow;
    }
  }

  // Delete staff member
  Future<void> deleteStaff(String userId) async {
    try {
      // First delete the profile
      await _supabase.from('profiles').delete().eq('id', userId);
      
      // Then delete the auth user
      await _supabase.auth.admin.deleteUser(userId);
    } catch (e) {
      debugPrint('Error deleting staff: $e');
      rethrow;
    }
  }

  // Reset password for staff
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      debugPrint('Error resetting password: $e');
      rethrow;
    }
  }
}
