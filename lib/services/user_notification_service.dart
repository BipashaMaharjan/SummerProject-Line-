import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../providers/notification_provider.dart';

/// Service to handle user notifications from database
/// Listens to user_notifications table for real-time updates
class UserNotificationService {
  static final UserNotificationService _instance = UserNotificationService._internal();
  factory UserNotificationService() => _instance;
  UserNotificationService._internal();

  final _supabase = SupabaseConfig.client;
  
  RealtimeChannel? _notificationChannel;
  bool _isInitialized = false;
  String? _currentUserId;
  
  // Stream controller for notifications
  final _notificationController = StreamController<UserNotification>.broadcast();
  
  Stream<UserNotification> get notificationStream => _notificationController.stream;
  
  /// Initialize the service for a specific user
  Future<void> initialize(String userId) async {
    if (_isInitialized && _currentUserId == userId) {
      debugPrint('UserNotificationService: Already initialized for user $userId');
      return;
    }
    
    try {
      debugPrint('UserNotificationService: Initializing for user $userId...');
      _currentUserId = userId;
      
      // Subscribe to real-time notifications
      _subscribeToRealTimeNotifications(userId);
      
      // Load initial notifications from database
      await _loadInitialNotifications(userId);
      
      _isInitialized = true;
      debugPrint('UserNotificationService: Initialized successfully');
    } catch (e) {
      debugPrint('UserNotificationService: Error initializing: $e');
      rethrow;
    }
  }
  
  /// Subscribe to real-time notifications for a user
  void _subscribeToRealTimeNotifications(String userId) {
    try {
      // Remove existing subscription if any
      _notificationChannel?.unsubscribe();
      
      _notificationChannel = _supabase.channel('user_notifications_$userId');
      
      // Listen to new insertions in user_notifications table
      _notificationChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'user_notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              try {
                final newRecord = payload.newRecord;
                debugPrint(
                  'UserNotificationService: New notification received: ${newRecord['message']}',
                );
                
                // Parse and emit notification
                final notification = UserNotification.fromJson(newRecord);
                _notificationController.add(notification);
                
                debugPrint('UserNotificationService: Notification emitted to stream');
              } catch (e) {
                debugPrint('UserNotificationService: Error processing notification: $e');
              }
            },
          )
          .subscribe();
      
      debugPrint('UserNotificationService: Subscribed to real-time notifications');
    } catch (e) {
      debugPrint('UserNotificationService: Error subscribing to notifications: $e');
    }
  }
  
  /// Load initial notifications from database
  Future<void> _loadInitialNotifications(String userId) async {
    try {
      final response = await _supabase
          .from('user_notifications')
          .select('id, user_id, token_id, token_number, type, title, message, previous_room_id, previous_room_name, new_room_id, new_room_name, previous_status, new_status, is_read, created_at, updated_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      
      debugPrint('UserNotificationService: Loaded ${response.length} initial notifications');
    } catch (e) {
      debugPrint('UserNotificationService: Error loading initial notifications: $e');
    }
  }
  
  /// Get all notifications for the current user
  Future<List<UserNotification>> getNotifications() async {
    if (_currentUserId == null) {
      debugPrint('UserNotificationService: Not initialized');
      return [];
    }
    
    try {
      final response = await _supabase
          .from('user_notifications')
          .select('id, user_id, token_id, token_number, type, title, message, previous_room_id, previous_room_name, new_room_id, new_room_name, previous_status, new_status, is_read, created_at, updated_at')
          .eq('user_id', _currentUserId!)
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => UserNotification.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('UserNotificationService: Error getting notifications: $e');
      return [];
    }
  }
  
  /// Get unread notification count
  Future<int> getUnreadCount() async {
    if (_currentUserId == null) {
      return 0;
    }
    
    try {
      final response = await _supabase
          .from('user_notifications')
          .select('id, user_id, token_id, token_number, type, title, message, previous_room_id, previous_room_name, new_room_id, new_room_name, previous_status, new_status, is_read, created_at, updated_at')
          .eq('user_id', _currentUserId!)
          .eq('is_read', false);
      
      return (response as List).length;
    } catch (e) {
      debugPrint('UserNotificationService: Error getting unread count: $e');
      return 0;
    }
  }
  
  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('user_notifications')
          .update({'is_read': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);
      
      debugPrint('UserNotificationService: Marked notification $notificationId as read');
    } catch (e) {
      debugPrint('UserNotificationService: Error marking notification as read: $e');
    }
  }
  
  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (_currentUserId == null) {
      return;
    }
    
    try {
      await _supabase
          .from('user_notifications')
          .update({'is_read': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('user_id', _currentUserId!)
          .eq('is_read', false);
      
      debugPrint('UserNotificationService: Marked all notifications as read');
    } catch (e) {
      debugPrint('UserNotificationService: Error marking all as read: $e');
    }
  }
  
  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('user_notifications')
          .delete()
          .eq('id', notificationId);
      
      debugPrint('UserNotificationService: Deleted notification $notificationId');
    } catch (e) {
      debugPrint('UserNotificationService: Error deleting notification: $e');
    }
  }
  
  /// Clear all notifications for the current user
  Future<void> clearAll() async {
    if (_currentUserId == null) {
      return;
    }
    
    try {
      await _supabase
          .from('user_notifications')
          .delete()
          .eq('user_id', _currentUserId!);
      
      debugPrint('UserNotificationService: Cleared all notifications');
    } catch (e) {
      debugPrint('UserNotificationService: Error clearing all notifications: $e');
    }
  }
  
  /// Cleanup and dispose
  Future<void> dispose() async {
    debugPrint('UserNotificationService: Disposing...');
    
    await _notificationChannel?.unsubscribe();
    _notificationChannel = null;
    
    await _notificationController.close();
    
    _isInitialized = false;
    _currentUserId = null;
    
    debugPrint('UserNotificationService: Disposed');
  }
}

/// User notification model
class UserNotification {
  final String id;
  final String userId;
  final String tokenId;
  final String tokenNumber;
  final String type; // 'room_transfer', 'status_change', 'queue_alert'
  final String title;
  final String message;
  
  // Room transfer details
  final String? previousRoomId;
  final String? previousRoomName;
  final String? newRoomId;
  final String? newRoomName;
  
  // Status change details
  final String? previousStatus;
  final String? newStatus;
  
  final bool isRead;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  UserNotification({
    required this.id,
    required this.userId,
    required this.tokenId,
    required this.tokenNumber,
    required this.type,
    required this.title,
    required this.message,
    this.previousRoomId,
    this.previousRoomName,
    this.newRoomId,
    this.newRoomName,
    this.previousStatus,
    this.newStatus,
    required this.isRead,
    required this.createdAt,
    this.updatedAt,
  });
  
  /// Factory constructor from JSON (Supabase)
  factory UserNotification.fromJson(Map<String, dynamic> json) {
    return UserNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tokenId: json['token_id'] as String,
      tokenNumber: json['token_number'] as String? ?? 'N/A',
      type: json['type'] as String? ?? 'status_change',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      previousRoomId: json['previous_room_id'] as String?,
      previousRoomName: json['previous_room_name'] as String?,
      newRoomId: json['new_room_id'] as String?,
      newRoomName: json['new_room_name'] as String?,
      previousStatus: json['previous_status'] as String?,
      newStatus: json['new_status'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
  
  /// Convert to NotificationItem for UI
  NotificationItem toNotificationItem() {
    NotificationType notifType;
    
    switch (type) {
      case 'room_transfer':
        notifType = NotificationType.statusUpdate;
        break;
      case 'status_change':
        if (newStatus == 'completed') {
          notifType = NotificationType.completed;
        } else if (newStatus == 'rejected' || newStatus == 'no_show') {
          notifType = NotificationType.cancelled;
        } else {
          notifType = NotificationType.statusUpdate;
        }
        break;
      case 'queue_alert':
        notifType = NotificationType.queueAlert;
        break;
      default:
        notifType = NotificationType.statusUpdate;
    }
    
    return NotificationItem(
      id: id,
      title: title,
      body: message,
      timestamp: createdAt,
      isRead: isRead,
      type: notifType,
    );
  }
  
  @override
  String toString() {
    return 'UserNotification(id: $id, token: $tokenNumber, type: $type, message: $message)';
  }
}
