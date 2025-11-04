import 'package:flutter/foundation.dart';

/// Provider to manage notification state and unread count
class NotificationProvider extends ChangeNotifier {
  final List<NotificationItem> _notifications = [];
  
  List<NotificationItem> get notifications => _notifications;
  
  /// Get count of unread notifications
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  
  /// Add a new notification
  void addNotification(NotificationItem notification) {
    _notifications.insert(0, notification); // Add to beginning
    notifyListeners();
  }
  
  /// Mark a notification as read
  void markAsRead(String id) {
    final notification = _notifications.firstWhere(
      (n) => n.id == id,
      orElse: () => _notifications.first,
    );
    notification.isRead = true;
    notifyListeners();
  }
  
  /// Mark all notifications as read
  void markAllAsRead() {
    for (var notification in _notifications) {
      notification.isRead = true;
    }
    notifyListeners();
  }
  
  /// Delete a notification
  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }
  
  /// Clear all notifications
  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }
  
  /// Add sample notifications for testing
  void addSampleNotifications() {
    final samples = [
      NotificationItem(
        id: '1',
        title: 'Token Status Update',
        body: 'Your token A-123 is now being processed',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isRead: false,
        type: NotificationType.statusUpdate,
      ),
      NotificationItem(
        id: '2',
        title: 'Almost Your Turn! ⏰',
        body: 'Token A-123 - 2 people ahead. Please be ready!',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        isRead: false,
        type: NotificationType.queueAlert,
      ),
      NotificationItem(
        id: '3',
        title: 'Service Completed ✅',
        body: 'Token A-122 has been completed successfully',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: true,
        type: NotificationType.completed,
      ),
    ];
    
    _notifications.addAll(samples);
    notifyListeners();
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
