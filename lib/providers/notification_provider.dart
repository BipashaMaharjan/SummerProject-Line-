import 'package:flutter/foundation.dart';
import '../services/user_notification_service.dart';
import 'dart:async';

/// Provider to manage notification state and unread count
class NotificationProvider extends ChangeNotifier {
  final UserNotificationService _notificationService = UserNotificationService();
  List<NotificationItem> _notifications = [];
  StreamSubscription? _notificationSubscription;
  bool _isInitialized = false;
  
  // Stream to broadcast new notifications to the UI (for showing snackbars)
  final StreamController<NotificationItem> _newNotificationController = StreamController<NotificationItem>.broadcast();
  Stream<NotificationItem> get onNewNotification => _newNotificationController.stream;
  
  List<NotificationItem> get notifications => _notifications;
  
  /// Get count of unread notifications
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  
  /// Initialize the provider for a specific user
  Future<void> initialize(String userId) async {
    if (_isInitialized) {
      debugPrint('NotificationProvider: Already initialized');
      return;
    }
    
    try {
      debugPrint('NotificationProvider: Initializing for user $userId...');
      
      // Initialize the notification service
      await _notificationService.initialize(userId);
      
      // Load initial notifications
      await loadNotifications();
      
      // Subscribe to real-time updates
      _notificationSubscription = _notificationService.notificationStream.listen((notification) {
        debugPrint('NotificationProvider: New notification received: ${notification.message}');
        
        // Add to the beginning of the list
        final item = notification.toNotificationItem();
        _notifications.insert(0, item);
        
        // Broadcast to listeners for UI popups
        _newNotificationController.add(item);
        
        notifyListeners();
      });
      
      _isInitialized = true;
      debugPrint('NotificationProvider: Initialized successfully with ${_notifications.length} notifications');
    } catch (e) {
      debugPrint('NotificationProvider: Error initializing (table may not exist): $e');
      // Don't rethrow - just log and continue with empty notifications
      _notifications = [];
      _isInitialized = false;
    }
  }
  
  /// Load notifications from database
  Future<void> loadNotifications() async {
    try {
      final userNotifications = await _notificationService.getNotifications();
      _notifications = userNotifications
          .map((n) => n.toNotificationItem())
          .toList();
      notifyListeners();
      
      debugPrint('NotificationProvider: Loaded ${_notifications.length} notifications');
    } catch (e) {
      debugPrint('NotificationProvider: Error loading notifications: $e');
    }
  }
  
  /// Refresh notifications (pull-to-refresh)
  Future<void> refresh() async {
    await loadNotifications();
  }
  
  /// Add a new notification (for backward compatibility, but not used with database)
  void addNotification(NotificationItem notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }
  
  /// Mark a notification as read
  Future<void> markAsRead(String id) async {
    try {
      // Update in database
      await _notificationService.markAsRead(id);
      
      // Update locally
      final notification = _notifications.firstWhere(
        (n) => n.id == id,
        orElse: () => _notifications.first,
      );
      notification.isRead = true;
      notifyListeners();
      
      debugPrint('NotificationProvider: Marked notification $id as read');
    } catch (e) {
      debugPrint('NotificationProvider: Error marking as read: $e');
    }
  }
  
  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      // Update in database
      await _notificationService.markAllAsRead();
      
      // Update locally
      for (var notification in _notifications) {
        notification.isRead = true;
      }
      notifyListeners();
      
      debugPrint('NotificationProvider: Marked all notifications as read');
    } catch (e) {
      debugPrint('NotificationProvider: Error marking all as read: $e');
    }
  }
  
  /// Delete a notification
  Future<void> deleteNotification(String id) async {
    try {
      // Delete from database
      await _notificationService.deleteNotification(id);
      
      // Remove locally
      _notifications.removeWhere((n) => n.id == id);
      notifyListeners();
      
      debugPrint('NotificationProvider: Deleted notification $id');
    } catch (e) {
      debugPrint('NotificationProvider: Error deleting notification: $e');
    }
  }
  
  /// Clear all notifications
  Future<void> clearAll() async {
    try {
      // Clear from database
      await _notificationService.clearAll();
      
      // Clear locally
      _notifications.clear();
      notifyListeners();
      
      debugPrint('NotificationProvider: Cleared all notifications');
    } catch (e) {
      debugPrint('NotificationProvider: Error clearing all: $e');
    }
  }
  
  /// Add sample notifications for testing (deprecated - using real database now)
  @Deprecated('Use real database notifications instead')
  void addSampleNotifications() {
    debugPrint('NotificationProvider: Sample notifications are deprecated. Using real database.');
  }
  
  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _newNotificationController.close();
    _notificationService.dispose();
    super.dispose();
  }
}

/// Notification item model
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;
  final NotificationType type;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.isRead,
    required this.type,
  });
}

/// Notification types
enum NotificationType {
  statusUpdate,
  queueAlert,
  completed,
  cancelled,
}

