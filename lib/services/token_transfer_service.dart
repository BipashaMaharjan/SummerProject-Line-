import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/token.dart';
import '../models/notification.dart';

/// Service to handle token transfers between rooms
/// Automatically creates notifications when tokens are transferred
class TokenTransferService {
  static final TokenTransferService _instance =
      TokenTransferService._internal();
  factory TokenTransferService() => _instance;
  TokenTransferService._internal();

  late final SupabaseClient _supabase;
  bool _isInitialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('TokenTransferService: Already initialized');
      return;
    }

    try {
      _supabase = Supabase.instance.client;
      _isInitialized = true;
      debugPrint('TokenTransferService: Initialized');
    } catch (e) {
      debugPrint('TokenTransferService: Error initializing: $e');
      rethrow;
    }
  }

  /// Transfer a token to the next room
  /// This automatically handles notification creation
  Future<bool> transferTokenToRoom({
    required String tokenId,
    required String tokenNumber,
    required String newRoomId,
    required String newRoomName,
    String? previousRoomId,
    String? previousRoomName,
    String? currentStaffId,
  }) async {
    try {
      debugPrint(
        'TokenTransferService: Transferring token $tokenNumber to room $newRoomName',
      );

      // Get the token first
      final tokenData = await _supabase
          .from('tokens')
          .select()
          .eq('id', tokenId)
          .single();

      final currentToken = Token.fromJson(tokenData);
      final previousStatus = currentToken.status.name;

      // Update token in database
      final updatedToken = {
        'current_room_id': newRoomId,
        'status': 'waiting', // Reset to waiting when transferred
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('tokens')
          .update(updatedToken)
          .eq('id', tokenId);

      // Get the staff member assigned to the new room
      final staffData = await _getStaffForRoom(newRoomId);
      String? newStaffId = staffData?['id'];

      // Create notification for the new staff member
      if (newStaffId != null) {
        await _createNotification(
          staffId: newStaffId,
          tokenId: tokenId,
          tokenNumber: tokenNumber,
          type: NotificationType.tokenTransfer,
          message:
              'New token received — Token #$tokenNumber has been transferred to you from ${previousRoomName ?? 'previous room'}',
          previousRoomId: previousRoomId,
          previousRoomName: previousRoomName,
          newRoomId: newRoomId,
          newRoomName: newRoomName,
          previousStatus: previousStatus,
          newStatus: 'waiting',
        );
      }

      // Create notification for the previous staff member (if applicable)
      if (currentStaffId != null &&
          currentStaffId != newStaffId &&
          previousRoomId != null) {
        await _createNotification(
          staffId: currentStaffId,
          tokenId: tokenId,
          tokenNumber: tokenNumber,
          type: NotificationType.transferredOut,
          message:
              'Token transferred — Token #$tokenNumber has been transferred to $newRoomName',
          previousRoomId: previousRoomId,
          previousRoomName: previousRoomName,
          newRoomId: newRoomId,
          newRoomName: newRoomName,
          previousStatus: previousStatus,
          newStatus: 'waiting',
        );
      }

      // Create admin notification
      await _createAdminNotification(
        tokenNumber: tokenNumber,
        message:
            'Token #$tokenNumber transferred from ${previousRoomName ?? 'N/A'} to $newRoomName',
      );

      debugPrint('TokenTransferService: Token transferred successfully');
      return true;
    } catch (e) {
      debugPrint('TokenTransferService: Error transferring token: $e');
      return false;
    }
  }

  /// Change token status and create appropriate notifications
  Future<bool> updateTokenStatus({
    required String tokenId,
    required String tokenNumber,
    required TokenStatus newStatus,
    String? currentRoomName,
    String? currentStaffId,
  }) async {
    try {
      debugPrint(
        'TokenTransferService: Updating token $tokenNumber status to ${newStatus.name}',
      );

      // Get the token first to capture previous status
      final tokenData = await _supabase
          .from('tokens')
          .select()
          .eq('id', tokenId)
          .single();

      final currentToken = Token.fromJson(tokenData);
      final previousStatus = currentToken.status.name;

      // Prepare update
      final updateData = {
        'status': newStatus.name,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Add timing information based on status
      if (newStatus == TokenStatus.processing) {
        updateData['started_at'] = DateTime.now().toIso8601String();
      } else if (newStatus == TokenStatus.completed) {
        updateData['completed_at'] = DateTime.now().toIso8601String();
      }

      // Update token in database
      await _supabase.from('tokens').update(updateData).eq('id', tokenId);

      // Get staff assigned to this token
      final staffData = await _getStaffForToken(tokenId);
      String? staffId = staffData?['id'];

      if (staffId != null) {
        // Create notification for staff
        await _createNotification(
          staffId: staffId,
          tokenId: tokenId,
          tokenNumber: tokenNumber,
          type: NotificationType.statusChange,
          message:
              'Status update — Token #$tokenNumber status changed from $previousStatus to ${newStatus.name}',
          newRoomName: currentRoomName,
          previousStatus: previousStatus,
          newStatus: newStatus.name,
        );
      }

      // Create admin notification
      await _createAdminNotification(
        tokenNumber: tokenNumber,
        message:
            'Token #$tokenNumber status updated from $previousStatus to ${newStatus.name}',
      );

      debugPrint('TokenTransferService: Token status updated successfully');
      return true;
    } catch (e) {
      debugPrint('TokenTransferService: Error updating status: $e');
      return false;
    }
  }

  /// Create a notification record in the database
  Future<void> _createNotification({
    required String staffId,
    required String tokenId,
    required String tokenNumber,
    required NotificationType type,
    required String message,
    String? previousRoomId,
    String? previousRoomName,
    String? newRoomId,
    String? newRoomName,
    String? previousStatus,
    String? newStatus,
  }) async {
    try {
      await _supabase.from('staff_notifications').insert({
        'staff_id': staffId,
        'token_id': tokenId,
        'token_number': tokenNumber,
        'type': type.name,
        'message': message,
        'previous_room_id': previousRoomId,
        'previous_room_name': previousRoomName,
        'new_room_id': newRoomId,
        'new_room_name': newRoomName,
        'previous_status': previousStatus,
        'new_status': newStatus,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint(
        'TokenTransferService: Notification created for staff $staffId',
      );
    } catch (e) {
      debugPrint('TokenTransferService: Error creating notification: $e');
    }
  }

  /// Create admin notification
  Future<void> _createAdminNotification({
    required String tokenNumber,
    required String message,
  }) async {
    try {
      // Get admin users
      final adminUsers = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'admin')
          .limit(10);

      // Create notifications for all admin users
      for (final admin in adminUsers) {
        await _supabase.from('staff_notifications').insert({
          'staff_id': admin['id'],
          'token_number': tokenNumber,
          'type': NotificationType.admin.name,
          'message': message,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      debugPrint('TokenTransferService: Admin notifications created');
    } catch (e) {
      debugPrint('TokenTransferService: Error creating admin notification: $e');
    }
  }

  /// Get staff member assigned to a room
  Future<Map<String, dynamic>?> _getStaffForRoom(String roomId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('assigned_room_id', roomId)
          .eq('role', 'staff')
          .limit(1)
          .maybeSingle();

      return data;
    } catch (e) {
      debugPrint('TokenTransferService: Error getting staff for room: $e');
      return null;
    }
  }

  /// Get staff member assigned to a token
  Future<Map<String, dynamic>?> _getStaffForToken(String tokenId) async {
    try {
      final data = await _supabase
          .from('tokens')
          .select('assigned_staff_id')
          .eq('id', tokenId)
          .maybeSingle();

      if (data == null) return null;

      final staffId = data['assigned_staff_id'];
      if (staffId == null) return null;

      final staffData = await _supabase
          .from('profiles')
          .select()
          .eq('id', staffId)
          .maybeSingle();

      return staffData;
    } catch (e) {
      debugPrint('TokenTransferService: Error getting staff for token: $e');
      return null;
    }
  }

  /// Get next room in workflow
  Future<Map<String, dynamic>?> getNextRoom(String currentRoomId) async {
    try {
      final data = await _supabase
          .from('rooms')
          .select()
          .eq('id', currentRoomId)
          .maybeSingle();

      if (data == null) return null;

      final nextRoomId = data['next_room_id'];
      if (nextRoomId == null) return null;

      final nextRoom = await _supabase
          .from('rooms')
          .select()
          .eq('id', nextRoomId)
          .maybeSingle();

      return nextRoom;
    } catch (e) {
      debugPrint('TokenTransferService: Error getting next room: $e');
      return null;
    }
  }
}
