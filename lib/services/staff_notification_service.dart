import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart';

/// Service to handle real-time staff notifications
/// Listens to staff_notifications table for real-time updates
class StaffNotificationService {
  static final StaffNotificationService _instance =
      StaffNotificationService._internal();
  factory StaffNotificationService() => _instance;
  StaffNotificationService._internal();

  late final SupabaseClient _supabase;
  RealtimeChannel? _notificationChannel;
  String? _currentStaffId;
  bool _isInitialized = false;

  // Streams for notifications
  final StreamController<TokenNotification> _notificationController =
      StreamController<TokenNotification>.broadcast();
  
  Stream<TokenNotification> get notificationStream =>
      _notificationController.stream;

  /// Initialize the service for a specific staff member
  Future<void> initialize(String staffId) async {
    if (_isInitialized && _currentStaffId == staffId) {
      debugPrint('StaffNotificationService: Already initialized for staff $staffId');
      return;
    }

    try {
      _supabase = Supabase.instance.client;
      _currentStaffId = staffId;
      
      debugPrint('StaffNotificationService: Initializing for staff $staffId...');
      
      // Subscribe to real-time notifications
      _subscribeToRealTimeNotifications(staffId);
      
      // Load initial notifications from database
      await _loadInitialNotifications(staffId);
      
      _isInitialized = true;
      debugPrint('StaffNotificationService: Initialized successfully');
    } catch (e) {
      debugPrint('StaffNotificationService: Error initializing: $e');
      rethrow;
    }
  }

  /// Subscribe to real-time notifications for a staff member
  void _subscribeToRealTimeNotifications(String staffId) {
    // Cancel existing subscription
    _notificationChannel?.unsubscribe();

    try {
      _notificationChannel = _supabase.channel('staff_notifications_$staffId');

      // Listen to new insertions in staff_notifications table
      _notificationChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'staff_notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'staff_id',
              value: staffId,
            ),
            callback: (payload) async {
              try {
                final newRecord = payload.newRecord;
                if (newRecord.isEmpty) return;

                debugPrint(
                  'StaffNotificationService: New notification received: ${newRecord['message']}',
                );

                // Create TokenNotification from the payload
                final notification = TokenNotification.fromJson(newRecord);
                
                // Emit through stream
                _notificationController.add(notification);
                
                debugPrint('StaffNotificationService: Notification emitted to stream');
              } catch (e) {
                debugPrint('StaffNotificationService: Error processing notification: $e');
              }
            },
          )
          .subscribe();

      debugPrint('StaffNotificationService: Subscribed to real-time notifications');
    } catch (e) {
      debugPrint('StaffNotificationService: Error subscribing to notifications: $e');
      rethrow;
    }
  }

  /// Load initial notifications from database
  Future<void> _loadInitialNotifications(String staffId) async {
    try {
      final data = await _supabase
          .from('staff_notifications')
          .select()
          .eq('staff_id', staffId)
          .order('created_at', ascending: false)
          .limit(50)
          .withConverter((response) => (response as List)
              .map((item) => TokenNotification.fromJson(item))
              .toList());

      debugPrint(
        'StaffNotificationService: Loaded ${data.length} initial notifications',
      );
    } catch (e) {
      debugPrint('StaffNotificationService: Error loading initial notifications: $e');
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('staff_notifications')
          .update({'is_read': true}).eq('id', notificationId);

      debugPrint('StaffNotificationService: Marked notification as read');
    } catch (e) {
      debugPrint('StaffNotificationService: Error marking as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (_currentStaffId == null) return;

    try {
      await _supabase
          .from('staff_notifications')
          .update({'is_read': true})
          .eq('staff_id', _currentStaffId);

      debugPrint('StaffNotificationService: Marked all notifications as read');
    } catch (e) {
      debugPrint('StaffNotificationService: Error marking all as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('staff_notifications')
          .delete()
          .eq('id', notificationId);

      debugPrint('StaffNotificationService: Deleted notification');
    } catch (e) {
      debugPrint('StaffNotificationService: Error deleting notification: $e');
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    if (_currentStaffId == null) return 0;

    try {
      final response = await _supabase
          .from('staff_notifications')
          .select('id')
          .eq('staff_id', _currentStaffId)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      debugPrint('StaffNotificationService: Error getting unread count: $e');
      return 0;
    }
  }

  /// Get notifications for a specific type
  Future<List<TokenNotification>> getNotificationsByType(
    NotificationType type,
  ) async {
    if (_currentStaffId == null) return [];

    try {
      final data = await _supabase
          .from('staff_notifications')
          .select()
          .eq('staff_id', _currentStaffId)
          .eq('type', type.name)
          .order('created_at', ascending: false)
          .withConverter((response) => (response as List)
              .map((item) => TokenNotification.fromJson(item))
              .toList());

      return data;
    } catch (e) {
      debugPrint('StaffNotificationService: Error getting notifications by type: $e');
      return [];
    }
  }

  /// Get recent notifications
  Future<List<TokenNotification>> getRecentNotifications({int limit = 20}) async {
    if (_currentStaffId == null) return [];

    try {
      final data = await _supabase
          .from('staff_notifications')
          .select()
          .eq('staff_id', _currentStaffId)
          .order('created_at', ascending: false)
          .limit(limit)
          .withConverter((response) => (response as List)
              .map((item) => TokenNotification.fromJson(item))
              .toList());

      return data;
    } catch (e) {
      debugPrint('StaffNotificationService: Error getting recent notifications: $e');
      return [];
    }
  }

  /// Get unread notifications
  Future<List<TokenNotification>> getUnreadNotifications() async {
    if (_currentStaffId == null) return [];

    try {
      final data = await _supabase
          .from('staff_notifications')
          .select()
          .eq('staff_id', _currentStaffId)
          .eq('is_read', false)
          .order('created_at', ascending: false)
          .withConverter((response) => (response as List)
              .map((item) => TokenNotification.fromJson(item))
              .toList());

      return data;
    } catch (e) {
      debugPrint('StaffNotificationService: Error getting unread notifications: $e');
      return [];
    }
  }

  /// Cleanup and dispose
  void dispose() {
    _notificationChannel?.unsubscribe();
    _notificationController.close();
    _isInitialized = false;
    _currentStaffId = null;
    debugPrint('StaffNotificationService: Disposed');
  }
}
